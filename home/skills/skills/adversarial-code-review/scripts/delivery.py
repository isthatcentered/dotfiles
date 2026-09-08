"""Render and verify a report without launching any review agents."""
import json
from pathlib import Path
from migrate import upgrade_report
from render import render_report, verify_report

def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(path)


def finish(report, root, config):
    report = upgrade_report(report)
    report["warnings"] = [warning for warning in report["warnings"]
                          if not warning.startswith("Report browser verification ")]
    write_json(root / "report.json", report)
    html_path = root / "index.html"
    render_report(report, html_path)
    verification = verify_report(html_path, config)
    write_json(root / "verification.json", verification)
    report["verification"] = verification
    warnings = list(report["warnings"])
    if verification["status"] != "passed":
        warnings.append("Report browser verification " + verification["status"] + ": " + verification["details"])
    report["warnings"] = warnings
    write_json(root / "report.json", report)
    render_report(report, html_path)
    status = report["reviewStatus"]
    if status == "complete" and (report["consolidationStatus"] != "completed" or verification["status"] != "passed"):
        status = "partial"
    result = {"status": status, "reportPath": str(html_path.resolve()),
              "reviewersCompleted": sum(o["status"] == "completed" for o in report["reviewers"]),
              "reviewersExpected": len(report["reviewers"]), "warnings": warnings}
    write_json(root / "result.json", result)
    print(json.dumps(result), flush=True)
    return {"complete": 0, "partial": 2, "failed": 1}[status]


