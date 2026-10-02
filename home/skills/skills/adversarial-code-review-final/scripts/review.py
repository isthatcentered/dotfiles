#!/usr/bin/env python3
"""Clone a branch, run agent CLIs, and print their concatenated findings."""

import argparse
from dataclasses import dataclass
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


PROMPT = "review this prompt"
DEFAULT_TIMEOUT_SECONDS = 20 * 60
EFFORT = "high"


def object_schema(properties):
    return {"type": "object", "properties": properties,
            "required": list(properties), "additionalProperties": False}


def rating_schema(levels, description):
    return object_schema({
        "level": {"type": "string", "enum": levels},
        "reason": {"type": "string", "description": description},
    })


FINDING_SCHEMA = object_schema({
    "location": object_schema({
        "start_line": {"type": "integer", "description": "1-based inclusive start line."},
        "end_line": {"type": "integer", "description": "1-based inclusive end line."},
        "file_path": {"type": "string", "description": "Path relative to the repository root."},
    }),
    "summary": {"type": "string", "description": "Short description of the issue."},
    "why_it_was_flagged": {"type": "string", "description": "Why this code was flagged."},
    "blast_radius": {"type": "string", "description": "How the bug impacts users."},
    "severity": rating_schema(["low", "medium", "high"], "Impact if the bug occurs."),
    "likelihood": rating_schema(["low", "medium", "high", "unknown"],
                                "How likely users are to encounter the trigger, with reasoning."),
    "example": {"type": "string", "description": "How the bug can happen or be triggered."},
})
OUTPUT_SCHEMA = object_schema({"findings": {"type": "array", "items": FINDING_SCHEMA}})


class ReviewError(Exception):
    pass


class Interrupted(Exception):
    def __init__(self, signum):
        self.signum = signum
        super().__init__(f"interrupted by {signal.Signals(signum).name}")


@dataclass
class Worker:
    name: str
    process: subprocess.Popen
    started: float
    stdout_path: Path
    stderr_path: Path
    agent: str = ""
    output_path: Path | None = None


def log(message):
    print(message, file=sys.stderr, flush=True)


def start_worker(command, cwd, directory, name, workers, agent="", output_path=None):
    directory.mkdir(parents=True, exist_ok=True)
    stdout_path, stderr_path = directory / "stdout.log", directory / "stderr.log"
    started = time.monotonic()
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        process = subprocess.Popen(command, cwd=cwd, stdin=subprocess.DEVNULL,
                                   stdout=stdout, stderr=stderr, start_new_session=True)
    worker = Worker(name, process, started, stdout_path, stderr_path, agent, output_path)
    workers.append(worker)
    log(f"Started {name}")
    return worker


def failure(worker, message):
    # Both streams are captured: some CLIs report errors on stdout.
    details = "\n".join(path.read_text(errors="replace")[-4000:].strip()
                        for path in (worker.stderr_path, worker.stdout_path)).strip()
    return ReviewError(f"{worker.name}: {message}" + (f"\n{details}" if details else ""))


def read_findings(worker):
    try:
        if worker.agent == "codex":
            result = json.loads(worker.output_path.read_text())
        else:
            response = json.loads(worker.stdout_path.read_text())
            if response.get("is_error") or response.get("subtype", "success") != "success":
                raise failure(worker, "review failed")
            result = response["structured_output"]
        # Decode the CLI envelope; deliberately do not validate findings.
        return result["findings"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise failure(worker, f"could not read findings: {error}") from error


def wait_for(workers, timeout):
    pending = list(enumerate(workers))
    results = [None] * len(workers)
    while pending:
        for index, worker in pending[:]:
            code = worker.process.poll()
            if code is not None:
                if code:
                    raise failure(worker, f"exited with code {code}")
                if worker.agent:
                    results[index] = read_findings(worker)
                pending.remove((index, worker))
                log(f"Finished {worker.name}")
            elif time.monotonic() - worker.started >= timeout:
                raise failure(worker, f"timed out after {timeout:g} seconds")
        if pending:
            time.sleep(0.05)
    return results


def stop_workers(workers):
    # Signal whole process groups, including descendants of exited CLI parents.
    for worker in workers:
        try:
            os.killpg(worker.process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 2
    for worker in workers:
        try:
            worker.process.wait(timeout=max(0, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            pass
    for worker in workers:
        try:
            os.killpg(worker.process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        worker.process.wait()


def reviewer_command(reviewer, schema_path, output_path):
    if reviewer["agent"] == "codex":
        return ["codex", "exec", "--color", "never", "--ephemeral",
                "--dangerously-bypass-approvals-and-sandbox", "--model", reviewer["model"],
                "-c", f'model_reasoning_effort="{EFFORT}"',
                "--output-schema", str(schema_path), "--output-last-message", str(output_path),
                PROMPT]
    return ["claude", "-p", PROMPT, "--output-format", "json", "--model", reviewer["model"],
            "--effort", EFFORT, "--dangerously-skip-permissions", "--no-session-persistence",
            "--json-schema", schema_path.read_text()]


def review(repo, branch, reviewers, timeout):
    with tempfile.TemporaryDirectory(prefix="adversarial-review-") as temporary:
        root = Path(temporary)
        checkout = root / "repo"
        workers = []
        try:
            clone = start_worker(["git", "clone", "--quiet", "--branch", branch,
                                  "--", repo, str(checkout)], root, root / "clone", "clone", workers)
            wait_for([clone], DEFAULT_TIMEOUT_SECONDS)
            schema_path = root / "schema.json"
            schema_path.write_text(json.dumps(OUTPUT_SCHEMA))
            reviewers_running = []
            for index, reviewer in enumerate(reviewers):
                directory = root / "reviewers" / str(index)
                output_path = directory / "findings.json"
                command = reviewer_command(reviewer, schema_path, output_path)
                reviewers_running.append(start_worker(
                    command, checkout, directory,
                    f"reviewer {index + 1} ({reviewer['agent']}, {reviewer['model']})",
                    workers, reviewer["agent"], output_path))
            results = wait_for(reviewers_running, timeout)
        finally:
            stop_workers(workers)
    # Cleanup completes before concatenating or writing anything to stdout.
    return [finding for findings in results for finding in findings]


def nonempty(value):
    if not value.strip():
        raise argparse.ArgumentTypeError("must not be empty")
    return value


def reviewer_list(value):
    try:
        reviewers = json.loads(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError(f"invalid JSON: {error}") from error
    if not isinstance(reviewers, list) or not reviewers:
        raise argparse.ArgumentTypeError("must be a nonempty JSON array")
    for reviewer in reviewers:
        if (not isinstance(reviewer, dict) or set(reviewer) != {"agent", "model"}
                or reviewer["agent"] not in ("codex", "claude")
                or not isinstance(reviewer["model"], str) or not reviewer["model"].strip()):
            raise argparse.ArgumentTypeError(
                'each reviewer must be {"agent": "codex" | "claude", "model": "nonempty string"}')
    return reviewers


def positive_seconds(value):
    try:
        seconds = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("must be a positive number of seconds") from error
    if not math.isfinite(seconds) or seconds <= 0:
        raise argparse.ArgumentTypeError("must be a positive number of seconds")
    return seconds


def interrupt(signum, _frame):
    raise Interrupted(signum)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, type=nonempty, help="Repository URL to clone")
    parser.add_argument("--branch", required=True, type=nonempty, help="Branch to check out")
    parser.add_argument("--reviewers", required=True, type=reviewer_list,
                        help="JSON array of {agent: codex|claude, model: string}")
    parser.add_argument("--timeout", type=positive_seconds, default=DEFAULT_TIMEOUT_SECONDS,
                        help="Timeout per reviewer in seconds (default: 1200)")
    args = parser.parse_args(argv)
    signal.signal(signal.SIGINT, interrupt)
    signal.signal(signal.SIGTERM, interrupt)
    try:
        findings = review(args.repo, args.branch, args.reviewers, args.timeout)
        print(json.dumps(findings, ensure_ascii=False, indent=2))
        return 0
    except Interrupted as error:
        log(f"error: {error}")
        return 128 + error.signum
    except (ReviewError, OSError, ValueError, KeyError, TypeError) as error:
        log(f"error: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
