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
        self.repo = self.root / "repo with spaces"
        self.repo.mkdir()
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Review Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
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
        command = [sys.executable, str(SCRIPT), "--repo", str(self.repo), "--branch", branch,
                   "--reviewers", json.dumps(reviewers), *extra]
        env = {**os.environ, "PATH": str(self.tools) + os.pathsep + os.environ["PATH"],
               "TMPDIR": str(self.scratch), "REVIEW_TEST_RECORDS": str(self.records),
               "REVIEW_TEST_COUNT": str(len(reviewers))}
        return command, env

    def run_review(self, reviewers, branch="feature/example", extra=()):
        command, env = self.invocation(reviewers, branch, extra)
        return subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)

    def read_records(self):
        return [json.loads(path.read_text()) for path in self.records.glob("*.json")]

    def assert_cleaned(self):
        self.assertEqual(list(self.scratch.iterdir()), [])
        for record in self.read_records():
            self.assertFalse(Path(record["cwd"]).exists())

    def assert_failed(self, result):
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("error:", result.stderr)
        self.assert_cleaned()

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
        findings = json.loads(result.stdout)
        self.assertEqual([f["summary"] for f in findings],
                         ["slow", "slow", "fast", "fast", "middle", "middle"])
        self.assertEqual(findings[0], findings[1])
        self.assertEqual(findings[0]["occurrence_likelihood"],
                         {"level": "unknown", "reason": "Usage is not known"})
        self.assertIn("—", result.stdout)
        records = self.read_records()
        self.assertEqual(len(records), 3)
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

    def test_main_is_a_valid_branch_and_a_single_reviewer_is_allowed(self):
        result = self.run_review([{"agent": "claude", "model": "one"}], branch="main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(json.loads(result.stdout)), 2)
        self.assertEqual(self.read_records()[0]["source"], "main branch\n")
        self.assert_cleaned()

    def test_repeated_models_are_independent_reviewers(self):
        result = self.run_review([{"agent": "codex", "model": "same"}] * 2)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.read_records()), 2)
        self.assertEqual(len(json.loads(result.stdout)), 4)
        self.assert_cleaned()

    def test_no_findings_prints_empty_array(self):
        result = self.run_review([{"agent": "codex", "model": "empty"},
                                  {"agent": "claude", "model": "empty"}])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "[]\n")
        self.assert_cleaned()

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
            self.assertEqual(len(json.loads(first_line + stdout)), 2)
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate()

    def test_findings_are_not_validated_or_rewritten(self):
        result = self.run_review([{"agent": "claude", "model": "no-validation"}])
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = {"location": {"start_line": -1, "end_line": 0, "file_path": "../missing"},
                    "unrecognized_field": "preserve this exactly"}
        self.assertEqual(json.loads(result.stdout), [expected, expected])
        self.assert_cleaned()

    def test_reviewer_failure_cancels_peers_without_partial_stdout_or_retry(self):
        result = self.run_review([{"agent": "codex", "model": "fail"},
                                  {"agent": "claude", "model": "hang"}])
        self.assert_failed(result)
        self.assertIn("fixture failure on stdout", result.stderr)
        self.assertIn("fixture failure on stderr", result.stderr)
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
        base = [sys.executable, str(SCRIPT)]
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


if __name__ == "__main__":
    unittest.main()
