"""Render old reports without rerunning reviewers or reading changed live source."""
import copy


def upgrade_report(original):
    report = copy.deepcopy(original)
    if report.get("schemaVersion") not in (1, 2):
        raise ValueError("Unsupported report schemaVersion")
    report["request"].setdefault("context", {"intent": "", "acceptedExceptions": [], "documents": []})
    sources = {(f["revision"], f["path"]): f for f in report["sourceFiles"]}
    scope = report["request"]["scope"]

    def old_side(value):
        if value["kind"] == "absent":
            return value
        location = value["location"]
        return {"kind": "present", "revision": location["revision"], "path": location["path"],
                "ranges": [{"label": "Cited source", "startLine": location["startLine"],
                            "endLine": location["endLine"], "excerpt": value["excerpt"]}]}

    def captured(sha, path):
        if (sha, path) in sources:
            return {"kind": "present", "revision": sha, "path": path, "ranges": []}
        return {"kind": "unavailable", "path": path, "revision": sha,
                "reason": "This revision was not captured in the original report."}

    if report["schemaVersion"] == 1:
        for entry in report["findings"]:
            finding = entry["finding"]
            views = [{"id": "primary", "label": "Primary source", "explanation": finding["whyItHappens"],
                      "before": old_side(finding.pop("before")), "after": old_side(finding.pop("after"))}]
            for index, ref in enumerate(finding.pop("supportingLocations", []), 1):
                before, after = captured(scope["baseSha"], ref["path"]), captured(scope["headSha"], ref["path"])
                value = before if ref["revision"] == scope["baseSha"] else after
                if value["kind"] == "present":
                    lines = sources[(ref["revision"], ref["path"])]["content"].splitlines(keepends=True)
                    value["ranges"] = [{"label": "Supporting location", "startLine": ref["startLine"],
                                        "endLine": ref["endLine"], "excerpt": "".join(lines[ref["startLine"] - 1:ref["endLine"]])}]
                views.append({"id": f"supporting-{index}", "label": ref["path"],
                              "explanation": "Supporting evidence from the original report.", "before": before, "after": after})
            finding["codeViews"] = views
            finding["assessment"] = {"status": "needs-verification", "reasoning": "Legacy report: no explicit assessment was recorded. Read its evidence and limits.",
                                     "assumptions": [], "verificationSteps": []}
            finding["evidence"] = [{"kind": "note", "label": "Original evidence", "explanation": text} for text in finding["evidence"]]
        report["schemaVersion"] = 2
    if "fileViews" not in report:
        report["fileViews"] = [{"id": str(index), "label": path, "explanation": "Source captured in the original report.",
                                "before": captured(scope["baseSha"], path), "after": captured(scope["headSha"], path)}
                               for index, path in enumerate(dict.fromkeys(f["path"] for f in report["sourceFiles"]))]
    return report
