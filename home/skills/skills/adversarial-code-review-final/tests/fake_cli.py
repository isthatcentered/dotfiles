#!/usr/bin/env python3
"""CLI fixture: records the invocation and simulates reviewer responses."""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def main():
    args = sys.argv[1:]
    agent = "codex" if args[0] == "exec" else "claude"
    model = args[args.index("--model") + 1]
    prompt = args[-1] if agent == "codex" else args[args.index("-p") + 1]
    schema = (json.loads(Path(args[args.index("--output-schema") + 1]).read_text())
              if agent == "codex" else json.loads(args[args.index("--json-schema") + 1]))
    records = Path(os.environ["REVIEW_TEST_RECORDS"])
    record_path = records / f"{os.getpid()}.json"
    record = {"agent": agent, "model": model, "args": args, "prompt": prompt,
              "schema": schema, "cwd": os.getcwd(), "pid": os.getpid(),
              "started": time.monotonic(), "source": Path("app.py").read_text()}

    if model == "hang":
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        child = subprocess.Popen([sys.executable, "-c",
                                  "import signal,time; signal.signal(signal.SIGTERM, "
                                  "signal.SIG_IGN); time.sleep(60)"])
        record["child_pid"] = child.pid

    def save_record():
        temporary = record_path.with_suffix(".tmp")
        temporary.write_text(json.dumps(record))
        temporary.replace(record_path)

    save_record()
    deadline = time.monotonic() + 5
    while len(list(records.glob("*.json"))) < int(os.environ["REVIEW_TEST_COUNT"]):
        if time.monotonic() >= deadline:
            print("reviewers were not started concurrently", file=sys.stderr)
            return 1
        time.sleep(0.01)

    if model == "hang":
        time.sleep(60)
    time.sleep({"slow": 0.6, "middle": 0.3, "fast": 0.05}.get(model, 0.01))
    if model == "fail":
        print("fixture failure on stdout")
        print("fixture failure on stderr", file=sys.stderr)
        return 1

    finding = {"location": {"start_line": 1, "end_line": 1, "file_path": "app.py"},
               "summary": model, "why_it_was_flagged": "An illustrative issue",
               "blast_radius": "Users cannot finish their operation",
               "severity": {"level": "high", "reason": "Core workflow fails"},
               "likelihood": {"level": "unknown", "reason": "Usage is not known"},
               "example": "Pass the triggering input — Unicode is preserved"}
    if model == "no-validation":
        finding = {"location": {"start_line": -1, "end_line": 0, "file_path": "../missing"},
                   "unrecognized_field": "preserve this exactly"}
    result = {"findings": [] if model == "empty" else [finding, finding]}
    if agent == "codex":
        print("captured Codex stdout " + "x" * 100000)
        print("captured Codex stderr " + "x" * 100000, file=sys.stderr)
        if model != "missing":
            Path(args[args.index("--output-last-message") + 1]).write_text(
                "invalid JSON" if model == "malformed" else json.dumps(result))
    else:
        print("captured Claude stderr", file=sys.stderr)
        envelope = {"subtype": "success", "is_error": False}
        if model != "missing":
            envelope["structured_output"] = result
        if model == "cli-error":
            envelope.update(subtype="error_during_execution", is_error=True)
        print("invalid JSON" if model == "malformed" else json.dumps(envelope))
    record["finished"] = time.monotonic()
    save_record()
    return 0


if __name__ == "__main__":
    sys.exit(main())
