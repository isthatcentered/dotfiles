import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import copy
import threading

SKILL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SKILL / "scripts"))
from render import browser_command, verify_report, render_report
from review import load_config, request_for, snapshot, git as read_git, Source, validate_consolidation
from environment import resolve_environment, prepare_environment, capture_context
from migrate import upgrade_report


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
        (self.repo / "hooks.py").write_text("header = 1\nquery = 2\ngap = 3\nstream = 4\nend = 5\n")
        (self.repo / "old.py").write_text('value = "rename me"\n')
        (self.repo / "deleted.py").write_text('value = "deleted"\n')
        self.git("add", ".")
        self.git("commit", "-qm", "base")
        self.base = self.git("rev-parse", "HEAD")
        self.git("checkout", "-qb", "feature")
        (self.repo / "app.py").write_text('value = "</script><script>window.injected=true</script>"\nsecond = 3\n')
        (self.repo / "hooks.py").write_text("header = 1\nquery = 20\ngap = 3\nstream = 40\nend = 5\n")
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

    def test_context_snapshot_and_project_profile(self):
        (self.repo / "design.md").write_text("Forced jobs may coexist with one ordinary job.")
        profile = self.repo / ".agents/review-config.json"
        profile.parent.mkdir()
        data = json.loads(self.config.read_text())
        data["context"] = {"intent": "Preserve ordering", "acceptedExceptions": ["Forced jobs may coexist"],
                           "documents": [{"id": "design", "title": "Design decision", "path": "design.md"}]}
        profile.write_text(json.dumps(data))
        result = subprocess.run([sys.executable, str(SKILL / "scripts/review.py"), "--repo", str(self.repo),
                                 "--scope", "branch"], capture_output=True, text=True, timeout=25,
                                env={**os.environ, "MOCK_REVIEW_MODE": "multi"})
        final = json.loads(result.stdout.strip().splitlines()[-1])
        report = json.loads(Path(final["reportPath"]).with_name("report.json").read_text())
        self.assertEqual(report["request"]["context"]["intent"], "Preserve ordering")
        self.assertEqual(len(report["findings"]), 2)
        self.assertTrue(any(e["kind"] == "document" for e in report["findings"][0]["finding"]["evidence"]))
        (self.repo / "design.md").write_text("Changed later")
        self.assertEqual(report["request"]["context"]["documents"][0]["content"], "Forced jobs may coexist with one ordinary job.")
        config = load_config(None)
        if browser_command(config):
            checked = verify_report(Path(final["reportPath"]), config)
            self.assertEqual(checked["status"], "passed", checked)

    def test_dependency_copy_and_symlink_isolation(self):
        (self.repo / ".gitignore").write_text("node_modules/\ncommon/temp/\n")
        self.git("add", ".gitignore"); self.git("commit", "-qm", "dependency paths")
        self.head = self.git("rev-parse", "HEAD")
        package = self.repo / "common/temp/store/pkg"; package.mkdir(parents=True)
        (package / "index.js").write_text("original package")
        modules = self.repo / "node_modules"; modules.mkdir()
        (modules / "pkg").symlink_to(package)
        external = self.root / "external"; external.mkdir(); (external / "file").write_text("external")
        (modules / "external").symlink_to(external)
        clone = self.root / "clone"; snapshot(self.repo, clone, self.head)
        plan = resolve_environment(self.repo, self.head, {}, read_git)
        record, _ = prepare_environment(self.repo, clone, plan, self.root / "logs", threading.Event())
        self.assertIn("node_modules", record["copied"])
        self.assertIn("common/temp", record["copied"])
        self.assertTrue((clone / "node_modules/pkg").resolve().is_relative_to(clone.resolve()))
        (clone / "node_modules/pkg/index.js").write_text("worker writes")
        self.assertEqual((package / "index.js").read_text(), "original package")
        self.assertFalse((clone / "node_modules/external").exists())
        self.assertTrue(any("External dependency symlink omitted" in limit for limit in record["limits"]))

    def test_incompatible_dependencies_are_not_reused(self):
        (self.repo / "package.json").write_text('{"name":"fixture"}\n')
        (self.repo / ".gitignore").write_text("node_modules/\n")
        self.git("add", "."); self.git("commit", "-qm", "manifest")
        self.head = self.git("rev-parse", "HEAD")
        (self.repo / "node_modules").mkdir()
        (self.repo / "node_modules/file").write_text("installed")
        (self.repo / "package.json").write_text('{"name":"changed"}\n')
        plan = resolve_environment(self.repo, self.head, {}, read_git)
        self.assertFalse(plan["copyPaths"])
        self.assertTrue(any("manifests differ" in limit for limit in plan["limits"]))

    def test_rush_runtime_selection_and_setup(self):
        (self.repo / "rush.json").write_text('{"nodeSupportedVersionRange":">=24.18.0 <25.0.0"}\n')
        self.git("add", "rush.json"); self.git("commit", "-qm", "runtime")
        self.head = self.git("rev-parse", "HEAD")
        nvm = self.root / "nvm"
        for version in ("24.14.0", "24.18.0", "25.0.0"):
            binary = nvm / "versions/node" / ("v" + version) / "bin/node"
            binary.parent.mkdir(parents=True); binary.write_text("#!/usr/bin/env python3\nprint('v" + version + "')\n"); binary.chmod(0o755)
        with patch.dict(os.environ, {"NVM_DIR": str(nvm)}):
            plan = resolve_environment(self.repo, self.head, {"setupCommands": [[sys.executable, "-c", "from pathlib import Path; Path('prepared.txt').write_text('ready')"]]}, read_git)
        self.assertEqual(plan["nodeVersion"], "v24.18.0")
        clone = self.root / "clone"; snapshot(self.repo, clone, self.head)
        record, env = prepare_environment(self.repo, clone, plan, self.root / "logs", threading.Event())
        self.assertEqual(record["commands"][0]["exitCode"], 0)
        self.assertEqual((clone / "prepared.txt").read_text(), "ready")
        self.assertFalse((self.repo / "prepared.txt").exists())
        self.assertTrue(env["PATH"].startswith(str(nvm / "versions/node/v24.18.0/bin")))

    def test_bad_views_and_evidence_are_rejected(self):
        _, _, report, _ = self.run_review("multi")
        raw = report["reviewers"][0]["report"]
        for mutation in ("range", "document", "external", "source", "assessment"):
            value = copy.deepcopy(raw)
            finding = value["findings"][0]
            if mutation == "range": finding["codeViews"][1]["after"]["ranges"][1]["endLine"] = 999
            if mutation == "document": finding["evidence"].append({"kind":"document", "label":"Missing", "explanation":"Unknown document", "documentId":"missing"})
            if mutation == "external": next(e for e in finding["evidence"] if e["kind"] == "external")["url"] = "javascript:alert(1)"
            if mutation == "source": finding["evidence"][0]["codeViewId"] = "missing"
            if mutation == "assessment": finding["assessment"]["verificationSteps"] = []
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                Source(self.repo, report["request"]["scope"]).report(value, report["request"])

    def test_legacy_report_migration(self):
        _, _, report, run = self.run_review()
        legacy = copy.deepcopy(report); legacy["schemaVersion"] = 1; legacy.pop("fileViews")
        finding = legacy["findings"][0]["finding"]
        view = finding.pop("codeViews")[0]
        for name in ("before", "after"):
            value = view[name]; span = value["ranges"][0]
            finding[name] = {"kind":"present", "location":{"revision":value["revision"], "path":value["path"], "startLine":span["startLine"], "endLine":span["endLine"]}, "excerpt":span["excerpt"]}
        finding["supportingLocations"] = [finding["after"]["location"]]
        finding.pop("assessment"); finding["evidence"] = ["Original evidence"]
        upgraded = upgrade_report(legacy)
        self.assertEqual(upgraded["findings"][0]["finding"]["id"], finding["id"])
        self.assertEqual(len(upgraded["findings"][0]["finding"]["codeViews"]), 2)
        render_report(legacy, run / "legacy.html")
        config = load_config(None)
        if browser_command(config):
            checked = verify_report(run / "legacy.html", config)
            self.assertEqual(checked["status"], "passed", checked)

    def test_consolidation_preserves_complementary_views(self):
        _, _, report, _ = self.run_review("multi")
        data = copy.deepcopy(report["consolidation"]["report"])
        finding = data["findings"][0]["finding"]
        finding["codeViews"] = [view for view in finding["codeViews"] if view["id"] != "hooks"]
        finding["evidence"] = [e for e in finding["evidence"] if e.get("codeViewId") != "hooks"]
        with self.assertRaisesRegex(ValueError, "dropped complementary"):
            validate_consolidation(data, report["request"], report["reviewers"], Source(self.repo, report["request"]["scope"]))

    def test_setup_failure_does_not_hide_completed_source_reviews(self):
        config = json.loads(self.config.read_text())
        config["environment"] = {"reuseDependencies": False, "setupCommands": [[sys.executable, "-c", "raise SystemExit(7)"]], "timeoutSeconds": 5}
        self.config.write_text(json.dumps(config))
        _, _, report, _ = self.run_review()
        self.assertEqual(report["reviewStatus"], "complete")
        self.assertTrue(all(r["attempts"][0]["environment"]["commands"][0]["exitCode"] == 7 for r in report["reviewers"]))
        self.assertTrue(any("Setup command 1 failed" in warning for warning in report["warnings"]))

    def test_browser_ui_contracts(self):
        config = load_config(None)
        if not browser_command(config):
            self.skipTest("Chrome/Chromium unavailable")
        for mode in ("success", "added", "deleted", "renamed", "multi", "empty", "all-fail"):
            with self.subTest(mode=mode):
                _, _, report, run = self.run_review(mode)
                verification = verify_report(run / "index.html", config)
                self.assertEqual(verification["status"], "passed", verification)


if __name__ == "__main__":
    unittest.main()
