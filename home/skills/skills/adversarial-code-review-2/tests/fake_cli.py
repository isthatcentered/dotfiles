#!/usr/bin/env python3
"""Protocol fixture: no model calls, credentials, or network access."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def emit(value):
    print(json.dumps(value), flush=True)


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def make_finding(request, kind="modified"):
    base, head = request["scope"]["baseSha"], request["scope"]["headSha"]
    old_path, new_path = ("old.py", "new.py") if kind == "renamed" else ("app.py", "app.py")
    if kind == "added":
        new_path = "added.py"
    if kind == "deleted":
        old_path = "deleted.py"

    def location(sha, path):
        return {"revision": sha, "path": path, "startLine": 1, "endLine": 1}

    def side(sha, path):
        return {"kind": "present", "revision": sha, "path": path, "ranges": [{"label": "Cause", "startLine": 1, "endLine": 1,
                "excerpt": git("show", f"{sha}:{path}").splitlines()[0] + "\n"}]}

    finding = {"id": "finding-1", "title": 'A concrete trigger causes an observable failure <script>',
            "severity": {"value": "medium", "reasoning": "Meaningful disruption."},
            "likelihood": {"value": "low", "reasoning": "Requires the unusual input."},
            "problematicLocation": {"kind": "deletion" if kind == "deleted" else "head",
                                    "location": location(base if kind == "deleted" else head,
                                                         old_path if kind == "deleted" else new_path)},
            "whatGoesWrong": "The affected workflow fails for this input.",
            "codeViews": [{"id": "origin", "label": "Origin", "explanation": "The changed contract.",
                "before": {"kind": "absent", "reason": "added"} if kind == "added" else side(base, old_path),
                "after": {"kind": "absent", "reason": "deleted"} if kind == "deleted" else side(head, new_path)}],
            "assessment": {"status": "supported", "reasoning": "Code establishes the failure.", "assumptions": [], "verificationSteps": []},
            "whyItHappens": "The changed contract no longer handles this input.",
            "reproduction": {
                "prerequisites": [], "steps": ["Supply the triggering input."],
                "expected": "The input is handled.", "actual": "The workflow fails.", "basis": "predicted"},
            "evidence": [{"kind": "source", "label": "Source evidence", "explanation": "The changed branch omits the previous case.", "codeViewId": "origin"}], "limits": ["Not executed."]}
    if kind == "multi":
        before, after = side(base, "hooks.py"), side(head, "hooks.py")
        for value in (before, after):
            lines = git("show", value["revision"] + ":hooks.py").splitlines()
            value["ranges"] = [{"label": label, "startLine": n, "endLine": n, "excerpt": lines[n-1]+"\n"}
                               for n,label in [(2,"Query error hook"),(4,"Stream error hook")]]
        finding["codeViews"].append({"id": "hooks", "label": "Error hooks", "explanation": "Two independent hooks observe the interruption.", "before": before, "after": after})
        finding["assessment"] = {"status": "needs-verification", "reasoning": "Production scheduling must be confirmed.", "assumptions": ["The refresh window is one hour."], "verificationSteps": ["Confirm the operator's production schedule."]}
        finding["evidence"].extend([
            {"kind": "source", "label": "Hook evidence", "explanation": "Both hooks observe the interruption.", "codeViewId": "hooks"},
            {"kind": "external", "label": "Runtime documentation", "explanation": "Describes interruption.", "url": "https://example.com/reference", "quote": "Interruption propagates."},
            {"kind": "check", "label": "Reproduction check", "explanation": "Shows the emitted error.", "command": "fixture-check --timeout", "outcome": "failed", "output": "Expected 0 errors, observed 2."}])
        for doc in request.get("context", {}).get("documents", []):
            finding["evidence"].append({"kind": "document", "label": "Accepted requirement", "explanation": "Defines the permitted behavior.", "documentId": doc["id"]})
    return finding


def main():
    args = sys.argv[1:]
    is_codex = args[0] == "exec"
    prompt = sys.stdin.read()
    mode = os.environ.get("MOCK_REVIEW_MODE", "success")
    consolidating = "\nINPUT:\n" in prompt
    if not is_codex:
        if mode == "claude-auth":
            print("Authentication failed: not logged in", file=sys.stderr)
            return 1
        if mode == "claude-startup-timeout":
            time.sleep(10)
        if mode == "claude-retry":
            marker = Path(os.environ["MOCK_MARKER"])
            if not marker.exists():
                marker.write_text("attempted")
                print("503 temporarily unavailable", file=sys.stderr)
                return 1
    if mode == "all-fail":
        print("Invalid model", file=sys.stderr)
        return 1
    emit({"type": "thread.started", "thread_id": "fixture"} if is_codex else
         {"type": "system", "subtype": "init", "model": "claude-opus-fixture"})
    if mode == "interrupt":
        time.sleep(10)
    if mode == "claude-run-timeout" and not is_codex:
        time.sleep(10)
    if mode == "consolidation-fail" and consolidating:
        emit({"type": "turn.failed", "error": {"message": "Consolidation failed"}})
        return 1
    if consolidating:
        data = json.loads(prompt.split("\nINPUT:\n", 1)[1])
        sources = [{"reviewer": o["reviewer"], "findingId": f["id"]}
                   for o in data["reviewers"] if o["report"] for f in o["report"]["findings"]]
        first = next((o["report"]["findings"][0] for o in data["reviewers"]
                      if o["report"] and o["report"]["findings"]), None)
        result = {"schemaVersion": 2, "runId": data["request"]["runId"],
                  "whatChanged": ["Before → after: changed the input handling."],
                  "findings": [{"finding": first, "sources": sources, "disagreements": []}] if first else [],
                  "excluded": [], "limits": []}
        if mode == "multi":
            result["findings"] = []
            for index in range(2):
                selected = [o for o in data["reviewers"] if o["report"]]
                finding = selected[0]["report"]["findings"][index]
                result["findings"].append({"finding": finding, "sources": [{"reviewer": o["reviewer"], "findingId": o["report"]["findings"][index]["id"]} for o in selected], "disagreements": []})
        if mode == "consolidation-loses-finding":
            result["findings"] = []
    else:
        request = json.loads(prompt.split("\nREQUEST:\n", 1)[1])
        kind = mode if mode in ("added", "deleted", "renamed", "multi") else "modified"
        result = {"schemaVersion": 2, "runId": request["runId"],
                  "baseSha": request["scope"]["baseSha"], "headSha": request["scope"]["headSha"],
                  "completeness": "partial" if mode == "partial" else "complete",
                  "whatChanged": ["Before → after: changed input handling."],
                  "coverage": {"inspected": ["Input behavior"], "reviewedFiles": [{"revision": request["scope"]["headSha"], "path": "app.py"}], "checks": [],
                               "limits": ["One interaction could not be inspected."] if mode == "partial" else []},
                  "findings": [] if mode == "empty" else [make_finding(request, kind)]}
        if mode == "multi":
            second = make_finding(request, "renamed")
            second["id"] = "finding-2"
            second["title"] = "Second finding in a renamed file"
            result["findings"].append(second)
        if mode == "wrong-scope":
            result["headSha"] = "wrong"
        if mode == "wrong-excerpt":
            result["findings"][0]["codeViews"][0]["after"]["ranges"][0]["excerpt"] = "invented source"
    time.sleep(0.05)
    if is_codex:
        path = Path(args[args.index("-o") + 1])
        if mode != "missing-output":
            path.write_text(json.dumps(result))
        emit({"type": "turn.completed"})
    else:
        event = {"type": "result", "subtype": "success", "is_error": False}
        if mode != "missing-output":
            event["structured_output"] = result
        emit(event)
    return 0


if __name__ == "__main__":
    sys.exit(main())
