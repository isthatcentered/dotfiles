import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

SKILL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SKILL / "scripts"))
from render import browser_command, verify_report
from review import load_config, request_for


class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="review-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo with spaces"
        self.repo.mkdir()
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Review Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        (self.repo / "app.py").write_text('value = "before"\nsecond = 2\n')
        (self.repo / "old.py").write_text('value = "rename me"\n')
        (self.repo / "deleted.py").write_text('value = "deleted"\n')
        self.git("add", ".")
        self.git("commit", "-qm", "base")
        self.base = self.git("rev-parse", "HEAD")
        self.git("checkout", "-qb", "feature")
        (self.repo / "app.py").write_text('value = "</script><script>window.injected=true</script>"\nsecond = 3\n')
        (self.repo / "old.py").rename(self.repo / "new.py")
        (self.repo / "deleted.py").unlink()
        (self.repo / "added.py").write_text('value = "added"\n')
        self.git("add", ".")
        self.git("commit", "-qm", "change")
        self.head = self.git("rev-parse", "HEAD")
        self.config = self.root / "config.json"
        self.config.write_text(json.dumps({
            "codexCommand": str(SKILL / "tests/fake_cli.py"),
            "claudeCommand": str(SKILL / "tests/fake_cli.py"),
            "browserCommand": "disabled", "startupTimeoutSeconds": 0.5,
            "runTimeoutSeconds": 2}))

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], text=True).strip()

    def run_review(self, mode="success", extra=None):
        result = subprocess.run([sys.executable, str(SKILL / "scripts/review.py"),
                                 "--repo", str(self.repo), "--scope", "branch", "--config", str(self.config),
                                 *(extra or [])], capture_output=True, text=True, timeout=25,
                                env={**os.environ, "MOCK_REVIEW_MODE": mode,
                                     "MOCK_MARKER": str(self.root / "marker")})
        try:
            final = json.loads(result.stdout.strip().splitlines()[-1])
        except (ValueError, IndexError):
            self.fail(result.stdout + result.stderr)
        self.assertTrue(final["reportPath"], final)
        run = Path(final["reportPath"]).parent
        report = json.loads((run / "report.json").read_text())
        return result, final, report, run

    def test_success_parallel_provenance_and_preservation(self):
        (self.repo / "app.py").write_text("uncommitted user change\n")
        (self.repo / "private.txt").write_text("untracked user change\n")
        result, final, report, run = self.run_review()
        self.assertEqual(result.returncode, 2)  # browser verification explicitly disabled
        self.assertEqual(report["reviewStatus"], "complete")
        self.assertEqual(report["consolidationStatus"], "completed")
        self.assertEqual(len(report["findings"]), 1)
        self.assertEqual(len(report["findings"][0]["sources"]), 3)
        self.assertTrue(report["request"]["scope"]["hadLocalChanges"])
        self.assertEqual(self.git("rev-parse", "HEAD"), self.head)
        self.assertEqual((self.repo / "app.py").read_text(), "uncommitted user change\n")
        self.assertEqual((self.repo / "private.txt").read_text(), "untracked user change\n")
        for reviewer in report["reviewers"]:
            self.assertEqual(reviewer["report"]["findings"][0]["id"], "finding-1")
        prompts = [(run / "reviewers" / r["reviewer"] / "attempt-1/prompt.md").read_text()
                   for r in report["reviewers"]]
        self.assertEqual(len(set(prompts)), 1)
        self.assertNotIn("{{review_scope}}", prompts[0])
        self.assertEqual(report["request"]["scope"]["baseSha"], self.base)
        self.assertNotIn('</script><script>window.injected', (run / "index.html").read_text())

    def test_auth_failure_does_not_cancel_other_reviews(self):
        _, final, report, _ = self.run_review("claude-auth")
        self.assertEqual(final["reviewersCompleted"], 2)
        claude = report["reviewers"][2]
        self.assertEqual(claude["failure"]["kind"], "authentication")
        self.assertIsNone(claude["report"])
        self.assertEqual(len(claude["attempts"]), 1)
        self.assertEqual(len(report["findings"][0]["sources"]), 2)

    def test_transient_retry_counted_once(self):
        _, _, report, _ = self.run_review("claude-retry")
        self.assertEqual(report["reviewers"][2]["status"], "completed")
        self.assertEqual(len(report["reviewers"][2]["attempts"]), 2)
        self.assertEqual(len(report["findings"][0]["sources"]), 3)

    def test_startup_timeout_retries_once(self):
        _, _, report, _ = self.run_review("claude-startup-timeout")
        self.assertEqual(report["reviewers"][2]["failure"]["kind"], "startup-timeout")
        self.assertEqual(len(report["reviewers"][2]["attempts"]), 2)

    def test_run_timeout_does_not_retry(self):
        _, _, report, _ = self.run_review("claude-run-timeout")
        self.assertEqual(report["reviewers"][2]["failure"]["kind"], "run-timeout")
        self.assertEqual(len(report["reviewers"][2]["attempts"]), 1)

    def test_missing_cli(self):
        config = json.loads(self.config.read_text())
        config["claudeCommand"] = str(self.root / "missing-cli")
        self.config.write_text(json.dumps(config))
        _, final, report, _ = self.run_review()
        self.assertEqual(final["reviewersCompleted"], 2)
        self.assertEqual(report["reviewers"][2]["failure"]["kind"], "launch-failed")

    def test_all_failed_is_not_clean(self):
        result, final, report, _ = self.run_review("all-fail")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(final["status"], "failed")
        self.assertEqual(report["consolidationStatus"], "skipped")
        self.assertFalse(report["findings"])

    def test_invalid_outputs_fail_review(self):
        for mode in ("wrong-scope", "wrong-excerpt", "missing-output"):
            with self.subTest(mode=mode):
                _, final, report, _ = self.run_review(mode)
                self.assertEqual(final["status"], "failed")
                self.assertTrue(all(r["failure"]["kind"] == "invalid-output" for r in report["reviewers"]))

    def test_consolidation_failure_preserves_raw_findings(self):
        for mode in ("consolidation-fail", "consolidation-loses-finding"):
            with self.subTest(mode=mode):
                _, final, report, _ = self.run_review(mode)
                self.assertEqual(final["status"], "partial")
                self.assertEqual(report["consolidationStatus"], "failed")
                self.assertEqual(len(report["findings"]), 3)
                self.assertEqual(len({e["finding"]["id"] for e in report["findings"]}), 3)

    def test_empty_and_partial_are_distinct(self):
        _, _, complete, _ = self.run_review("empty")
        self.assertEqual(complete["reviewStatus"], "complete")
        self.assertFalse(complete["findings"])
        _, _, partial, _ = self.run_review("partial")
        self.assertEqual(partial["reviewStatus"], "partial")
        self.assertEqual(partial["reviewers"][0]["status"], "partial")

    def test_scope_resolution(self):
        for scope in ("branch", "last-commit", "HEAD", self.base + ".." + self.head):
            request = request_for(self.repo, scope, "test")
            self.assertEqual(request["scope"]["baseSha"], self.base)
            self.assertEqual(request["scope"]["headSha"], self.head)
        with self.assertRaises(ValueError):
            request_for(self.repo, "--help..HEAD", "test")

    def test_interruption_writes_failure_report(self):
        process = subprocess.Popen([sys.executable, str(SKILL / "scripts/review.py"),
                                    "--repo", str(self.repo), "--scope", "branch",
                                    "--config", str(self.config)], stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True,
                                   env={**os.environ, "MOCK_REVIEW_MODE": "interrupt"})
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                events = list(self.repo.glob(".agents/review/*/reviewers/*/attempt-1/events.jsonl"))
                if len(events) == 3 and all(p.stat().st_size for p in events):
                    break
                time.sleep(0.05)
            else:
                self.fail("Fixture reviewers did not start")
            process.terminate()
            stdout, stderr = process.communicate(timeout=10)
            result = json.loads(stdout.strip().splitlines()[-1])
            self.assertEqual(result["status"], "failed", stderr)
            report = json.loads(Path(result["reportPath"]).with_name("report.json").read_text())
            self.assertTrue(all(r["failure"]["kind"] == "interrupted" for r in report["reviewers"]))
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate()

    def test_rerender_updates_verification_without_agents(self):
        config = load_config(None)
        if not browser_command(config):
            self.skipTest("Browser unavailable")
        _, _, report, run = self.run_review()
        config_path = self.root / "render-config.json"
        config_path.write_text(json.dumps({"codexCommand": "/missing", "claudeCommand": "/missing"}))
        process = subprocess.run([sys.executable, str(SKILL / "scripts/review.py"),
                                  "--render", str(run / "report.json"), "--config", str(config_path)],
                                 capture_output=True, text=True, timeout=60)
        result = json.loads(process.stdout.strip().splitlines()[-1])
        self.assertEqual(process.returncode, 0, result)
        self.assertEqual(result["status"], "complete")
        self.assertFalse(any('verification skipped' in w for w in result["warnings"]))

    def test_original_review_criteria_preserved(self):
        original = (SKILL.parent / "adversarial-code-review/REVIEW-PROMPT.md").read_text()
        current = (SKILL / "references/review-prompt.md").read_text()
        self.assertEqual(original.split("## Phase 3 — Report")[0], current.split("## Phase 3 — Report")[0])
        self.assertEqual(original.split("### Severity and likelihood")[1], current.split("### Severity and likelihood")[1])

    def test_browser_ui_contracts(self):
        config = load_config(None)
        if not browser_command(config):
            self.skipTest("Chrome/Chromium unavailable")
        for mode in ("success", "added", "deleted", "renamed", "empty", "all-fail"):
            with self.subTest(mode=mode):
                _, _, report, run = self.run_review(mode)
                verification = verify_report(run / "index.html", config)
                self.assertEqual(verification["status"], "passed", verification)


if __name__ == "__main__":
    unittest.main()
