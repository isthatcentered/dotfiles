import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest


SKILL = Path(__file__).resolve().parents[1]
SCRIPT = SKILL / "scripts" / "review.py"


class ReviewTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="review-final-tests-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        # Exercise the real script-relative log location without leaving test logs in the skill.
        self.script = self.root / "skill" / "scripts" / "review.py"
        self.script.parent.mkdir(parents=True)
        shutil.copy2(SCRIPT, self.script)
        shutil.copy2(SKILL / "REVIEW-PROMPT.md", self.script.parent.parent / "REVIEW-PROMPT.md")
        self.logs = self.script.parent / ".logs"
        self.repo = self.root / "repo with spaces"
        self.repo.mkdir()
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Review Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "uploadpack.allowFilter", "true")
        (self.repo / "app.py").write_text("main branch\n")
        self.git("add", ".")
        self.git("commit", "-qm", "base")
        self.git("checkout", "-qb", "feature/example")
        (self.repo / "app.py").write_text("feature branch\n")
        self.git("commit", "-qam", "feature")
        (self.repo / "app.py").write_text("uncommitted user change\n")
        (self.repo / "untracked.txt").write_text("untracked user change\n")
        self.scratch = self.root / "temporary dirs"
        self.scratch.mkdir()
        self.records = self.root / "records"
        self.records.mkdir()
        self.sessions = self.root / "saved sessions"
        self.sessions.mkdir()
        self.tools = self.root / "fake tools"
        self.tools.mkdir()
        for name in ("codex", "claude"):
            wrapper = self.tools / name
            wrapper.write_text(f"#!{sys.executable}\nimport runpy\n"
                               f"runpy.run_path({str(SKILL / 'tests/fake_cli.py')!r}, "
                               "run_name='__main__')\n")
            wrapper.chmod(0o755)

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], text=True).strip()

    def invocation(self, reviewers, branch="feature/example", extra=()):
        # file:// exercises Git transport and filtering instead of local hardlink cloning.
        command = [sys.executable, str(self.script), "--repo", self.repo.as_uri(), "--branch", branch,
                   "--reviewers", json.dumps(reviewers), *extra]
        env = {**os.environ, "PATH": str(self.tools) + os.pathsep + os.environ["PATH"],
               "TMPDIR": str(self.scratch), "REVIEW_TEST_RECORDS": str(self.records),
               "REVIEW_TEST_SESSIONS": str(self.sessions), "CLAUDE_CODE_SKIP_PROMPT_HISTORY": "1",
               "REVIEW_TEST_COUNT": str(len(reviewers))}
        return command, env

    def run_review(self, reviewers, branch="feature/example", extra=()):
        command, env = self.invocation(reviewers, branch, extra)
        return subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)

    def read_records(self):
        return [json.loads(path.read_text()) for path in self.records.glob("*.json")]

    def read_run_log(self):
        directory = sorted(self.logs.iterdir())[-1]
        events = [json.loads(line) for line in (directory / "run.jsonl").read_text().splitlines()]
        return directory, events

    def assert_cleaned(self):
        self.assertEqual(list(self.scratch.iterdir()), [])
        for record in self.read_records():
            self.assertFalse(Path(record["cwd"]).exists())

    def assert_failed(self, result):
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("error:", result.stderr)
        self.assert_cleaned()
        _, events = self.read_run_log()
        self.assertEqual(events[-1]["event"], "run.finished")
        self.assertEqual(events[-1]["status"], "failed")
        self.assertTrue(any(e["event"] == "step.finished" and e["step"] == "cleanup"
                            for e in events))

    def assert_stopped(self, pid):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                return
            # Orphaned children can remain zombies until the host reaps them.
            stat = Path(f"/proc/{pid}/stat")
            try:
                if stat.exists() and stat.read_text().split(") ", 1)[1].startswith("Z"):
                    return
            except FileNotFoundError:
                return
            time.sleep(0.05)
        self.fail(f"process {pid} is still running")

    def test_parallel_ordered_findings_and_shared_requested_checkout(self):
        reviewers = [{"agent": "codex", "model": "slow"},
                     {"agent": "codex", "model": "fast"},
                     {"agent": "claude", "model": "middle"}]
        result = self.run_review(reviewers)
        self.assertEqual(result.returncode, 0, result.stderr)
        groups = json.loads(result.stdout)
        self.assertEqual([group["agent"] for group in groups], ["codex", "codex", "claude"])
        self.assertTrue(all(set(group) == {"agent", "sessionId", "findings"} for group in groups))
        findings = [finding for group in groups for finding in group["findings"]]
        self.assertEqual([f["summary"] for f in findings],
                         ["slow", "slow", "fast", "fast", "middle", "middle"])
        self.assertEqual(findings[0], findings[1])
        self.assertEqual(findings[0]["occurrence_likelihood"],
                         {"level": "unknown", "reason": "Usage is not known"})
        self.assertIn("—", result.stdout)
        records = self.read_records()
        self.assertEqual(len(records), 3)
        sessions = {r["model"]: r["session_id"] for r in records}
        self.assertEqual([group["sessionId"] for group in groups],
                         [sessions["slow"], sessions["fast"], sessions["middle"]])
        self.assertEqual(len({r["cwd"] for r in records}), 1)
        self.assertTrue(all(r["source"] == "feature branch\n" for r in records))
        prompt = (SKILL / "REVIEW-PROMPT.md").read_text(encoding="utf-8")
        self.assertTrue(all(r["prompt"] == prompt for r in records))
        self.assertTrue(all(r["schema"] == records[0]["schema"] for r in records))
        schema = records[0]["schema"]["properties"]["findings"]["items"]
        self.assertIn("occurrence_likelihood", schema["required"])
        self.assertNotIn("likelihood", schema["properties"])
        self.assertLess(max(r["started"] for r in records), min(r["finished"] for r in records))
        finished = sorted(records, key=lambda r: r["finished"])
        self.assertEqual([r["model"] for r in finished], ["fast", "middle", "slow"])
        for record in records:
            bypass = ("--dangerously-bypass-approvals-and-sandbox" if record["agent"] == "codex"
                      else "--dangerously-skip-permissions")
            self.assertIn(bypass, record["args"])
        self.assertEqual((self.repo / "app.py").read_text(), "uncommitted user change\n")
        self.assertEqual((self.repo / "untracked.txt").read_text(), "untracked user change\n")
        self.assertEqual(self.git("branch", "--show-current"), "feature/example")
        self.assert_cleaned()
        directory, events = self.read_run_log()
        self.assertEqual(directory.parent, self.logs)
        self.assertIn("-feature-example-", directory.name)
        self.assertIn(str(directory), result.stderr)
        self.assertEqual(events[0]["event"], "run.started")
        self.assertEqual(events[0]["branch"], "feature/example")
        self.assertEqual(events[0]["reviewers"], reviewers)
        self.assertEqual(events[-1]["event"], "run.finished")
        self.assertEqual(events[-1]["status"], "succeeded")
        self.assertTrue(all(event["timestamp"].endswith("+00:00") for event in events))
        elapsed = [event["elapsed_seconds"] for event in events]
        self.assertEqual(elapsed, sorted(elapsed))
        processes = [e for e in events if e["event"] == "process.finished"]
        self.assertEqual([e["process"] for e in processes],
                         ["clone", "reviewer 2 (codex, fast)", "reviewer 3 (claude, middle)",
                          "reviewer 1 (codex, slow)"])
        self.assertTrue(all(e["duration_seconds"] > 0 and e["exit_code"] == 0
                            for e in processes))
        self.assertGreaterEqual(processes[-1]["duration_seconds"], 0.6)
        self.assertLess(processes[1]["duration_seconds"], processes[-1]["duration_seconds"])
        started = [e for e in events if e["event"] == "process.started"]
        self.assertEqual(len(started), 4)
        self.assertEqual({e["pid"] for e in started}, {e["pid"] for e in processes})
        self.assertEqual({e["sessionId"] for e in events if e["event"] == "review.collected"},
                         {group["sessionId"] for group in groups})
        completed_steps = [e["step"] for e in events if e["event"] == "step.finished"]
        self.assertIn("read_review", completed_steps)
        self.assertIn("cleanup", completed_steps)
        self.assertIn("write_output", completed_steps)
        self.assertEqual((directory / "clone" / "stdout.log").read_text(), "")
        self.assertIn("captured Codex stdout", (directory / "reviewers/0/stdout.log").read_text())
        self.assertIn("captured Codex stderr", (directory / "reviewers/0/stderr.log").read_text())
        self.assertEqual(json.loads((directory / "reviewers/0/findings.json").read_text()),
                         {"findings": groups[0]["findings"]})
        self.assertIn("session_id", json.loads((directory / "reviewers/2/stdout.log").read_text()))

    def test_clone_duration_includes_time_spent_in_git(self):
        real_git = shutil.which("git")
        wrapper = self.tools / "git"
        wrapper.write_text(f"#!{sys.executable}\nimport os, sys, time\ntime.sleep(0.25)\n"
                           f"os.execv({real_git!r}, [{real_git!r}, *sys.argv[1:]])\n")
        wrapper.chmod(0o755)
        result = self.run_review([{"agent": "codex", "model": "one"}])
        self.assertEqual(result.returncode, 0, result.stderr)
        _, events = self.read_run_log()
        clone = next(e for e in events if e["event"] == "process.finished" and e["process"] == "clone")
        self.assertGreaterEqual(clone["duration_seconds"], 0.25)
        first_agent = next(e for e in events if e["event"] == "process.started" and e["agent"])
        self.assertGreater(first_agent["elapsed_seconds"], clone["elapsed_seconds"])
        self.assert_cleaned()

    def test_partial_clone_retains_commit_messages_files_and_historical_diffs(self):
        historical_commit = self.git("rev-parse", "HEAD")
        historical_blob = self.git("rev-parse", "HEAD:app.py")
        (self.repo / "app.py").write_text("final feature branch\n")
        self.git("commit", "-qam", "Final feature title\n\nDetailed feature description")
        self.git("checkout", "-q", "main")
        (self.repo / "base.txt").write_text("base change\n")
        self.git("add", "base.txt")
        self.git("commit", "-qm", "Base update\n\nBase description")
        self.git("checkout", "-qb", "unrelated")
        (self.repo / "unrelated.txt").write_text("unrelated change\n")
        self.git("add", "unrelated.txt")
        self.git("commit", "-qm", "Unrelated commit")
        self.git("tag", "unrelated-tag")
        self.git("checkout", "-q", "feature/example")
        self.git("merge", "-q", "--no-ff", "main", "-m", "Merge main\n\nMerge description")
        self.git("tag", "feature-tag")
        expected_history = self.git("log", "--format=%H%n%B", "--name-status", "--no-renames",
                                    "--diff-merges=first-parent", "HEAD")
        expected_patch = self.git("show", "--format=%B", "--no-renames", historical_commit)
        command, env = self.invocation([{"agent": "codex", "model": "history"},
                                        {"agent": "claude", "model": "one"}])
        env["REVIEW_TEST_COMMIT"] = historical_commit
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        records = self.read_records()
        self.assertEqual(len(records), 2)
        self.assertTrue(all(record["source"] == "final feature branch\n" for record in records))
        for record in records:
            if record["model"] != "history":
                continue
            self.assertEqual(record["is_shallow"], "false")
            self.assertEqual(record["filter"], "blob:none")
            self.assertIn("origin/feature/example", record["remote_branches"])
            self.assertNotIn("origin/unrelated", record["remote_branches"])
            self.assertEqual(record["tags"], [])
            self.assertIn(f"?{historical_blob}", record["missing_before"].splitlines())
            self.assertEqual(record["history"], expected_history)
            self.assertEqual(record["historical_patch"], expected_patch)
            self.assertEqual(record["source"], "final feature branch\n")
        self.assertEqual(len(json.loads(result.stdout)), 2)
        self.assert_cleaned()

    def test_simultaneous_runs_have_distinct_persistent_logs(self):
        command, env = self.invocation([{"agent": "codex", "model": "one"}])
        processes = []
        try:
            for _ in range(2):
                processes.append(subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                                                   stderr=subprocess.PIPE, text=True))
            for process in processes:
                stdout, stderr = process.communicate(timeout=10)
                self.assertEqual(process.returncode, 0, stderr)
                self.assertEqual(len(json.loads(stdout)), 1)
            directories = list(self.logs.iterdir())
            self.assertEqual(len(directories), 2)
            for directory in directories:
                events = [json.loads(line) for line in (directory / "run.jsonl").read_text().splitlines()]
                self.assertEqual(events[0]["run_id"], directory.name)
                self.assertEqual(events[-1]["status"], "succeeded")
                self.assertTrue((directory / "reviewers/0/stdout.log").exists())
            self.assert_cleaned()
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill()
                process.communicate()

    def test_main_is_a_valid_branch_and_a_single_reviewer_is_allowed(self):
        result = self.run_review([{"agent": "claude", "model": "one"}], branch="main")
        self.assertEqual(result.returncode, 0, result.stderr)
        groups = json.loads(result.stdout)
        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0]["agent"], "claude")
        self.assertEqual(len(groups[0]["findings"]), 2)
        self.assertEqual(self.read_records()[0]["source"], "main branch\n")
        self.assert_cleaned()

    def test_repeated_models_are_independent_reviewers(self):
        result = self.run_review([{"agent": "codex", "model": "same"}] * 2)
        self.assertEqual(result.returncode, 0, result.stderr)
        records = self.read_records()
        groups = json.loads(result.stdout)
        self.assertEqual(len(records), 2)
        self.assertEqual(len(groups), 2)
        self.assertEqual({group["sessionId"] for group in groups},
                         {record["session_id"] for record in records})
        self.assertEqual(len({group["sessionId"] for group in groups}), 2)
        self.assertTrue(all(group["agent"] == "codex" for group in groups))
        self.assertEqual(sum(len(group["findings"]) for group in groups), 4)
        self.assert_cleaned()

    def test_empty_findings_keep_reviewer_sessions(self):
        result = self.run_review([{"agent": "codex", "model": "empty"},
                                  {"agent": "claude", "model": "empty"}])
        self.assertEqual(result.returncode, 0, result.stderr)
        groups = json.loads(result.stdout)
        self.assertEqual([group["agent"] for group in groups], ["codex", "claude"])
        self.assertEqual([group["findings"] for group in groups], [[], []])
        self.assertEqual({group["sessionId"] for group in groups},
                         {record["session_id"] for record in self.read_records()})
        self.assert_cleaned()

    def test_sessions_persist_outside_temporary_checkout(self):
        result = self.run_review([{"agent": "codex", "model": "one"},
                                  {"agent": "claude", "model": "one"}])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_cleaned()
        for group in json.loads(result.stdout):
            transcript = self.sessions / f"{group['sessionId']}.json"
            saved = json.loads(transcript.read_text())
            self.assertEqual(saved["session_id"], group["sessionId"])
            self.assertEqual(saved["agent"], group["agent"])
            self.assertFalse(Path(saved["cwd"]).exists())
            if saved["agent"] == "claude":
                self.assertIsNone(saved["skip_prompt_history"])

    def test_cleanup_happens_before_stdout_is_written(self):
        command, env = self.invocation([{"agent": "codex", "model": "one"}])
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        try:
            first_line = process.stdout.readline()
            self.assertEqual(first_line, "[\n")
            self.assert_cleaned()
            stdout = process.stdout.read()
            _, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
            groups = json.loads(first_line + stdout)
            self.assertEqual(len(groups), 1)
            self.assertEqual(groups[0]["sessionId"], self.read_records()[0]["session_id"])
            self.assertEqual(len(groups[0]["findings"]), 2)
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate()

    def test_findings_are_not_validated_or_rewritten(self):
        result = self.run_review([{"agent": "claude", "model": "no-validation"}])
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = {"location": {"start_line": -1, "end_line": 0, "file_path": "../missing"},
                    "unrecognized_field": "preserve this exactly"}
        groups = json.loads(result.stdout)
        self.assertEqual(groups[0]["findings"], [expected, expected])
        self.assert_cleaned()

    def test_reviewer_failure_cancels_peers_without_partial_stdout_or_retry(self):
        result = self.run_review([{"agent": "codex", "model": "fail"},
                                  {"agent": "claude", "model": "hang"}])
        self.assert_failed(result)
        self.assertIn("fixture failure on stdout", result.stderr)
        self.assertIn("fixture failure on stderr", result.stderr)
        directory, events = self.read_run_log()
        finished = [e for e in events if e["event"] == "process.finished" and e["agent"]]
        self.assertEqual([e["status"] for e in finished], ["failed", "cancelled"])
        self.assertTrue(any(e.get("signal") == "SIGKILL" for e in events))
        self.assertIn("fixture failure on stdout", (directory / "reviewers/0/stdout.log").read_text())
        records = self.read_records()
        self.assertEqual(len(records), 2)
        for record in records:
            self.assert_stopped(record["pid"])
            if "child_pid" in record:
                self.assert_stopped(record["child_pid"])

    def test_timeout_stops_cli_and_its_child(self):
        result = self.run_review([{"agent": "codex", "model": "hang"}], extra=("--timeout", "0.25"))
        self.assert_failed(result)
        self.assertIn("timed out", result.stderr)
        _, events = self.read_run_log()
        self.assertTrue(any(e["event"] == "process.timeout" for e in events))
        finished = next(e for e in events if e["event"] == "process.finished" and e["agent"])
        self.assertEqual(finished["status"], "timed_out")
        self.assertGreaterEqual(finished["duration_seconds"], 0.25)
        record = self.read_records()[0]
        self.assert_stopped(record["pid"])
        self.assert_stopped(record["child_pid"])

    def test_interrupts_stop_children_and_clean_checkout(self):
        for signum in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=signum):
                for path in self.records.glob("*.json"):
                    path.unlink()
                command, env = self.invocation([{"agent": "claude", "model": "hang"}])
                process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                                           stderr=subprocess.PIPE, text=True)
                try:
                    deadline = time.monotonic() + 5
                    while not list(self.records.glob("*.json")) and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertEqual(len(self.read_records()), 1)
                    process.send_signal(signum)
                    stdout, stderr = process.communicate(timeout=10)
                    self.assertEqual(process.returncode, 128 + signum, stderr)
                    self.assertEqual(stdout, "")
                    self.assertIn("interrupted", stderr)
                    _, events = self.read_run_log()
                    self.assertEqual(events[-1]["status"], "interrupted")
                    self.assertEqual(events[-1]["signal"], signal.Signals(signum).name)
                    self.assert_cleaned()
                    record = self.read_records()[0]
                    self.assert_stopped(record["pid"])
                    self.assert_stopped(record["child_pid"])
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.communicate()

    def test_unreadable_responses_and_cli_error_status_fail(self):
        cases = [(agent, model) for agent in ("codex", "claude")
                 for model in ("malformed", "missing")]
        cases.append(("claude", "cli-error"))
        for agent, model in cases:
            with self.subTest(agent=agent, model=model):
                self.assert_failed(self.run_review([{"agent": agent, "model": model}]))

    def test_missing_or_empty_session_ids_fail_without_partial_stdout(self):
        for agent in ("codex", "claude"):
            for model in ("missing-session", "empty-session"):
                with self.subTest(agent=agent, model=model):
                    self.assert_failed(self.run_review([{"agent": agent, "model": model}]))

    def test_missing_cli_and_missing_branch_fail_with_cleanup(self):
        (self.tools / "claude").unlink()
        # An isolated PATH avoids accidentally launching the installed real CLI.
        (self.tools / "git").symlink_to(shutil.which("git"))
        command, env = self.invocation([{"agent": "claude", "model": "one"}])
        env["PATH"] = str(self.tools)
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=10)
        self.assert_failed(result)
        self.assertIn("claude", result.stderr)
        result = self.run_review([{"agent": "codex", "model": "one"}], branch="missing/branch")
        self.assert_failed(result)
        self.assertEqual(self.read_records(), [])

    def test_required_inputs_are_nonempty_and_reviewers_are_well_formed(self):
        base = [sys.executable, str(self.script)]
        valid = '[{"agent":"codex","model":"one"}]'
        cases = [[], ["--repo", "repo", "--reviewers", valid],
                 ["--repo", "repo", "--branch", "main"],
                 ["--repo", "repo", "--branch", " ", "--reviewers", valid],
                 ["--repo", "", "--branch", "main", "--reviewers", valid]]
        for value in ("[]", "{}", "invalid JSON", '[{"agent":"other","model":"one"}]',
                      '[{"agent":"codex","model":""}]', '[{"agent":"codex"}]'):
            cases.append(["--repo", "repo", "--branch", "main", "--reviewers", value])
        for timeout in ("0", "-1", "nan", "inf"):
            cases.append(["--repo", "repo", "--branch", "main", "--reviewers", valid,
                          "--timeout", timeout])
        for args in cases:
            with self.subTest(args=args):
                result = subprocess.run(base + args, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")
        self.assertEqual(self.read_records(), [])
        self.assertFalse(self.logs.exists())


if __name__ == "__main__":
    unittest.main()
