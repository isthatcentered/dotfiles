#!/usr/bin/env python3
"""Generate the bundled Feed report from an orchestrator's JSON handoff. No model calls."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True

from catalog import file_views
from contracts import CONSOLIDATION, REVIEW, STRING, STRINGS, VERSION, array, enum, obj, validate
from delivery import finish
from source import Source, git, revision

SLOTS = {"codex-astra": ("codex", "gpt-6-astra"),
         "codex-sol": ("codex", "gpt-5.6-sol"),
         "claude-opus": ("claude", "opus")}
COVERAGE = REVIEW["properties"]["coverage"]
HANDOFF = obj(
    schemaVersion=VERSION, runId=STRING,
    scope=obj(requested=STRING, baseSha=STRING, headSha=STRING),
    context=obj(intent=STRING, acceptedExceptions=STRINGS,
                documents=array(obj(id=STRING, title=STRING, path=STRING, content=STRING))),
    reviewers=array(obj(reviewer=enum(*SLOTS), model=STRING, effort=STRING,
                        status=enum("completed", "partial", "failed"), failure=STRING,
                        reportPath=STRING, findingIds=STRINGS, coverage=COVERAGE)),
    consolidation=obj(status=enum("completed", "failed", "skipped"), failure=STRING),
    whatChanged=STRINGS, findings=CONSOLIDATION["properties"]["findings"],
    excluded=CONSOLIDATION["properties"]["excluded"], limits=STRINGS)


def prepare(data, repo):
    validate(data, HANDOFF)
    data = copy.deepcopy(data)
    if not data["runId"].strip():
        raise ValueError("runId must be nonempty and stable for this review")
    scope = data["scope"]
    for key in ("baseSha", "headSha"):
        if revision(repo, scope[key]) != scope[key]:
            raise ValueError(f"{key} must be a full pinned commit SHA, not a moving ref")
    scope.update(changedPaths=[p for p in git(repo, "diff", "--name-only", "-z",
                                            scope["baseSha"], scope["headSha"], "--").split("\0") if p],
                 workingTreeChanges="excluded",
                 hadLocalChanges=bool(git(repo, "status", "--porcelain", "--untracked-files=normal").strip()))
    documents = data["context"]["documents"]
    document_ids = [d["id"] for d in documents]
    if any(not x.strip() for x in document_ids) or len(set(document_ids)) != len(document_ids):
        raise ValueError("Context document IDs must be nonempty and unique")
    for document in documents:
        document["sha256"] = hashlib.sha256(document["content"].encode()).hexdigest()
    source = Source(repo, scope)
    outcomes, reported, warnings = [], set(), []
    seen_reviewers = set()
    for reviewer in data["reviewers"]:
        name, status = reviewer["reviewer"], reviewer["status"]
        if name in seen_reviewers:
            raise ValueError("Each reviewer slot must occur at most once")
        seen_reviewers.add(name)
        ids, coverage = reviewer["findingIds"], reviewer["coverage"]
        if any(not value.strip() for value in ids) or len(ids) != len(set(ids)):
            raise ValueError("Reviewer finding IDs must be nonempty and unique")
        if status == "failed":
            if ids or not reviewer["failure"].strip():
                raise ValueError("A failed reviewer needs a failure reason and cannot contribute findings")
        elif not coverage["inspected"] or not reviewer["model"].strip():
            raise ValueError("Usable reviewers must identify their model and inspected behavior")
        if status == "completed" and reviewer["failure"]:
            raise ValueError("A completed reviewer cannot have a terminal failure")
        if status == "partial" and not coverage["limits"]:
            raise ValueError("A partial reviewer must explain its coverage limits")
        for ref in coverage["reviewedFiles"]:
            if ref["revision"] not in (scope["baseSha"], scope["headSha"]):
                raise ValueError("Reviewed files must use pinned revisions")
            path = Path(ref["path"])
            if not ref["path"] or path.is_absolute() or ".." in path.parts:
                raise ValueError("Reviewed files must have repository-relative paths")
            git(repo, "cat-file", "-e", f"{ref['revision']}:{ref['path']}")
        reported.update((name, value) for value in ids)
        outcomes.append({"reviewer": name, "provider": SLOTS[name][0],
                         "requestedModel": reviewer["model"], "effort": reviewer["effort"],
                         "status": status, "attempts": [], "reportPath": reviewer["reportPath"],
                         "failure": {"kind": "review-incomplete", "message": reviewer["failure"]} if reviewer["failure"] else None,
                         "report": {"coverage": coverage, "findings": [{"id": value} for value in ids]} if status != "failed" else None})
    for name, (provider, model) in SLOTS.items():
        if name not in seen_reviewers:
            outcomes.append({"reviewer": name, "provider": provider, "requestedModel": model,
                             "effort": "high", "status": "failed", "attempts": [], "report": None,
                             "failure": {"kind": "missing-outcome", "message": "No reviewer outcome was supplied; completion could not be established."}})
    usable = [r for r in outcomes if r["report"] is not None]
    state = data["consolidation"]
    if state["status"] == "completed" and (not usable or state["failure"]):
        raise ValueError("Completed consolidation requires a usable review and no failure")
    if state["status"] != "completed" and not state["failure"].strip():
        raise ValueError("Failed or skipped consolidation must explain why")
    references = []
    usable_names = {r["reviewer"] for r in usable}
    for entry in data["findings"]:
        references.extend((r["reviewer"], r["findingId"]) for r in entry["sources"])
        if any(d["reviewer"] not in usable_names for d in entry["disagreements"]):
            raise ValueError("Disagreement cites an unavailable reviewer")
        if state["status"] != "completed" and len(entry["sources"]) != 1:
            raise ValueError("Unconsolidated findings must retain one original source each")
    for entry in data["excluded"]:
        if not entry["reason"].strip() or state["status"] != "completed":
            raise ValueError("Exclusions require completed consolidation and an explicit reason")
        references.append((entry["source"]["reviewer"], entry["source"]["findingId"]))
    if set(references) != reported or len(references) != len(set(references)):
        raise ValueError("Every reported finding must appear exactly once in findings or excluded")
    source.findings([entry["finding"] for entry in data["findings"]], document_ids)
    for entry in data["findings"]:
        identity = sorted((r["reviewer"], r["findingId"]) for r in entry["sources"])
        entry["finding"]["id"] = hashlib.sha256(json.dumps(identity).encode()).hexdigest()[:20]
    if scope["hadLocalChanges"]:
        warnings.append("Uncommitted and untracked changes were excluded; only pinned commits were reviewed.")
    for outcome in outcomes:
        if outcome["failure"]:
            warnings.append(f"{outcome['reviewer']}: {outcome['failure']['message']}")
        elif outcome["status"] == "partial":
            warnings.append(f"{outcome['reviewer']} returned a partial review; see coverage limits.")
    if state["status"] != "completed":
        warnings.append(f"Consolidation {state['status']}: {state['failure']}")
    catalog, limits = file_views(source, outcomes, git)
    return {"schemaVersion": 2, "runId": data["runId"],
            "request": {"schemaVersion": 2, "runId": data["runId"], "scope": scope, "context": data["context"]},
            "reviewers": outcomes,
            "reviewStatus": "complete" if all(r["status"] == "completed" for r in outcomes) else "partial" if usable else "failed",
            "consolidationStatus": state["status"], "consolidation": state,
            "whatChanged": data["whatChanged"], "findings": data["findings"], "excluded": data["excluded"],
            "limits": data["limits"] + limits, "warnings": warnings, "fileViews": catalog,
            "sourceFiles": [{"revision": sha, "path": path, "language": Path(path).suffix.lstrip("."), "content": content}
                            for (sha, path), content in source.files.items()]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--input", help="Orchestrator handoff JSON")
    mode.add_argument("--render", help="Re-render a generated report.json using stored source")
    mode.add_argument("--schema", action="store_true", help="Print the exact handoff JSON schema")
    parser.add_argument("--repo", default=".", help="Reviewed Git repository")
    parser.add_argument("--output", help="Output directory (default: input file's directory)")
    parser.add_argument("--browser", default="auto", help="auto, browser executable, or disabled")
    parser.add_argument("--browser-timeout", type=int, default=60, help="Browser deadline in seconds")
    args = parser.parse_args()
    if args.schema:
        print(json.dumps(HANDOFF, indent=2))
        return 0
    if not 1 <= args.browser_timeout <= 86400:
        parser.error("--browser-timeout must be between 1 and 86400")
    path = Path(args.input or args.render).resolve()
    root = Path(args.output).resolve() if args.output else path.parent
    if path in {root / name for name in ("index.html", "verification.json", "result.json")} or (args.input and path == root / "report.json"):
        parser.error("Input handoff must not use a reserved generated filename")
    try:
        data = json.loads(path.read_text())
        report = prepare(data, Path(args.repo).resolve()) if args.input else data
        return finish(report, root, {"browserCommand": args.browser, "browserTimeoutSeconds": args.browser_timeout})
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(json.dumps({"status": "failed", "reportPath": None, "warnings": [str(error)]}), flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
