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
        return {"kind": "present", "location": location(sha, path),
                "excerpt": git("show", f"{sha}:{path}").splitlines()[0] + "\n"}

    return {"id": "finding-1", "title": 'A concrete trigger causes an observable failure <script>',
            "severity": {"value": "medium", "reasoning": "Meaningful disruption."},
            "likelihood": {"value": "low", "reasoning": "Requires the unusual input."},
            "problematicLocation": {"kind": "deletion" if kind == "deleted" else "head",
                                    "location": location(base if kind == "deleted" else head,
                                                         old_path if kind == "deleted" else new_path)},
            "whatGoesWrong": "The affected workflow fails for this input.",
            "before": {"kind": "absent", "reason": "added"} if kind == "added" else side(base, old_path),
            "after": {"kind": "absent", "reason": "deleted"} if kind == "deleted" else side(head, new_path),
            "whyItHappens": "The changed contract no longer handles this input.",
            "supportingLocations": [], "reproduction": {
                "prerequisites": [], "steps": ["Supply the triggering input."],
                "expected": "The input is handled.", "actual": "The workflow fails.", "basis": "predicted"},
            "evidence": ["The changed branch omits the previous case."], "limits": ["Not executed."]}


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
        result = {"schemaVersion": 1, "runId": data["request"]["runId"],
                  "whatChanged": ["Before → after: changed the input handling."],
                  "findings": [{"finding": first, "sources": sources, "disagreements": []}] if first else [],
                  "excluded": [], "limits": []}
        if mode == "consolidation-loses-finding":
            result["findings"] = []
    else:
        request = json.loads(prompt.split("\nREQUEST:\n", 1)[1])
        kind = mode if mode in ("added", "deleted", "renamed") else "modified"
        result = {"schemaVersion": 1, "runId": request["runId"],
                  "baseSha": request["scope"]["baseSha"], "headSha": request["scope"]["headSha"],
                  "completeness": "partial" if mode == "partial" else "complete",
                  "whatChanged": ["Before → after: changed input handling."],
                  "coverage": {"inspected": ["Input behavior"], "checks": [],
                               "limits": ["One interaction could not be inspected."] if mode == "partial" else []},
                  "findings": [] if mode == "empty" else [make_finding(request, kind)]}
        if mode == "wrong-scope":
            result["headSha"] = "wrong"
        if mode == "wrong-excerpt":
            result["findings"][0]["after"]["excerpt"] = "invented source"
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
