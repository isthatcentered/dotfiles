#!/usr/bin/env python3
"""Clone a branch, run agent CLIs, and print findings grouped by agent session.

Each run retains timestamped events and process output in scripts/.logs/.
"""

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time


PROMPT = (Path(__file__).resolve().parents[1] / "REVIEW-PROMPT.md").read_text(encoding="utf-8")
DEFAULT_TIMEOUT_SECONDS = 20 * 60
EFFORT = "high"
LOGS_DIRECTORY = Path(__file__).resolve().parent / ".logs"


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
    "occurrence_likelihood": rating_schema(
        ["low", "medium", "high", "unknown"],
        "How likely users are to encounter the trigger in expected usage, with reasoning."),
    "example": {"type": "string", "description": "How the bug can happen or be triggered."},
})
OUTPUT_SCHEMA = object_schema({"findings": {"type": "array", "items": FINDING_SCHEMA}})


class ReviewError(Exception):
    pass


class Interrupted(Exception):
    def __init__(self, signum):
        self.signum = signum
        super().__init__(f"interrupted by {signal.Signals(signum).name}")


class RunLog:
    def __init__(self, branch):
        self.started = time.monotonic()
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
        branch_label = re.sub(r"[^A-Za-z0-9._-]+", "-", branch).strip(".-")[:64] or "branch"
        LOGS_DIRECTORY.mkdir(parents=True, exist_ok=True)
        # mkdtemp creates the directory exclusively, including for simultaneous runs.
        self.directory = Path(tempfile.mkdtemp(
            prefix=f"{timestamp}-{branch_label}-", dir=LOGS_DIRECTORY))
        self.stream = (self.directory / "run.jsonl").open("w", encoding="utf-8")

    def write(self, event, message, **fields):
        timestamp = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
        elapsed = round(time.monotonic() - self.started, 6)
        record = {"timestamp": timestamp, "elapsed_seconds": elapsed,
                  "event": event, "message": message, **fields}
        self.stream.write(json.dumps(record, ensure_ascii=False) + "\n")
        self.stream.flush()
        log(f"{timestamp} [+{elapsed:.3f}s] {message}")

    @contextmanager
    def step(self, name, **fields):
        started = time.monotonic()
        self.write("step.started", f"Started {name}", step=name, **fields)
        try:
            yield
        except Exception as error:
            duration = time.monotonic() - started
            self.write("step.failed", f"Failed {name} after {duration:.3f}s", step=name,
                       duration_seconds=round(duration, 6), error=str(error), **fields)
            raise
        else:
            duration = time.monotonic() - started
            self.write("step.finished", f"Finished {name} in {duration:.3f}s", step=name,
                       duration_seconds=round(duration, 6), **fields)

    def close(self):
        self.stream.close()


@dataclass
class Worker:
    name: str
    process: subprocess.Popen
    started: float
    stdout_path: Path
    stderr_path: Path
    agent: str = ""
    output_path: Path | None = None
    model: str = ""
    end_logged: bool = False
    stop_status: str = "cancelled"


def log(message):
    print(message, file=sys.stderr, flush=True)


def start_worker(command, cwd, directory, name, workers, logger, agent="", output_path=None,
                 model=""):
    directory.mkdir(parents=True, exist_ok=True)
    stdout_path, stderr_path = directory / "stdout.log", directory / "stderr.log"
    started = time.monotonic()
    environment = os.environ.copy()
    if agent == "claude":
        environment.pop("CLAUDE_CODE_SKIP_PROMPT_HISTORY", None)
    logger.write("process.starting", f"Starting {name}", process=name, agent=agent, model=model,
                 cwd=str(cwd), executable=command[0], stdout_path=str(stdout_path),
                 stderr_path=str(stderr_path))
    try:
        with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
            process = subprocess.Popen(command, cwd=cwd, stdin=subprocess.DEVNULL,
                                       stdout=stdout, stderr=stderr, env=environment,
                                       start_new_session=True)
    except OSError as error:
        logger.write("process.start_failed", f"Could not start {name}", process=name,
                     agent=agent, model=model, error=str(error),
                     duration_seconds=round(time.monotonic() - started, 6))
        raise
    worker = Worker(name, process, started, stdout_path, stderr_path, agent, output_path, model)
    workers.append(worker)
    logger.write("process.started", f"Started {name}", process=name, agent=agent,
                 model=model, pid=process.pid)
    return worker


def log_worker_end(worker, logger, status):
    duration = time.monotonic() - worker.started
    worker.end_logged = True
    logger.write("process.finished", f"Finished {worker.name} ({status}) in {duration:.3f}s",
                 process=worker.name, agent=worker.agent, model=worker.model,
                 pid=worker.process.pid, exit_code=worker.process.returncode,
                 status=status, duration_seconds=round(duration, 6))


def failure(worker, message):
    # Both streams are captured: some CLIs report errors on stdout.
    details = "\n".join(path.read_text(errors="replace")[-4000:].strip()
                        for path in (worker.stderr_path, worker.stdout_path)).strip()
    return ReviewError(f"{worker.name}: {message}" + (f"\n{details}" if details else ""))


def codex_session_id(worker):
    with worker.stdout_path.open() as events:
        for line in events:
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if isinstance(event, dict) and event.get("type") == "thread.started":
                return event["thread_id"]
    raise failure(worker, "CLI output did not include a session ID")


def read_review(worker):
    try:
        if worker.agent == "codex":
            result = json.loads(worker.output_path.read_text())
            session_id = codex_session_id(worker)
        else:
            response = json.loads(worker.stdout_path.read_text())
            if response.get("is_error") or response.get("subtype", "success") != "success":
                raise failure(worker, "review failed")
            result = response["structured_output"]
            session_id = response["session_id"]
        if not isinstance(session_id, str) or not session_id:
            raise failure(worker, "CLI output did not include a session ID")
        # Decode the CLI envelope; deliberately do not validate findings.
        return {"agent": worker.agent, "sessionId": session_id, "findings": result["findings"]}
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise failure(worker, f"could not read findings: {error}") from error


def wait_for(workers, timeout, logger):
    pending = list(enumerate(workers))
    results = [None] * len(workers)
    while pending:
        for index, worker in pending[:]:
            code = worker.process.poll()
            if code is not None:
                log_worker_end(worker, logger, "failed" if code else "succeeded")
                if code:
                    raise failure(worker, f"exited with code {code}")
                if worker.agent:
                    with logger.step("read_review", process=worker.name):
                        results[index] = read_review(worker)
                    logger.write("review.collected", f"Collected findings from {worker.name}",
                                 process=worker.name, sessionId=results[index]["sessionId"],
                                 findings_count=(len(results[index]["findings"])
                                                 if isinstance(results[index]["findings"], list)
                                                 else None))
                pending.remove((index, worker))
            elif time.monotonic() - worker.started >= timeout:
                worker.stop_status = "timed_out"
                logger.write("process.timeout", f"Timed out {worker.name} after {timeout:g}s",
                             process=worker.name, timeout_seconds=timeout,
                             duration_seconds=round(time.monotonic() - worker.started, 6))
                raise failure(worker, f"timed out after {timeout:g} seconds")
        if pending:
            time.sleep(0.05)
    return results


def stop_workers(workers, logger):
    # Signal whole process groups, including descendants of exited CLI parents.
    for worker in workers:
        try:
            os.killpg(worker.process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        else:
            logger.write("process.signal", f"Sent SIGTERM to {worker.name}'s process group",
                         process=worker.name, pid=worker.process.pid, signal="SIGTERM")
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
        else:
            logger.write("process.signal", f"Sent SIGKILL to {worker.name}'s process group",
                         process=worker.name, pid=worker.process.pid, signal="SIGKILL")
        worker.process.wait()
        if not worker.end_logged:
            log_worker_end(worker, logger, worker.stop_status)


def reviewer_command(reviewer, schema_path, output_path):
    if reviewer["agent"] == "codex":
        return ["codex", "exec", "--json", "--color", "never",
                "--dangerously-bypass-approvals-and-sandbox", "--model", reviewer["model"],
                "-c", f'model_reasoning_effort="{EFFORT}"',
                "--output-schema", str(schema_path), "--output-last-message", str(output_path),
                PROMPT]
    return ["claude", "-p", PROMPT, "--output-format", "json", "--model", reviewer["model"],
            "--effort", EFFORT, "--dangerously-skip-permissions",
            "--json-schema", schema_path.read_text()]


def review(repo, branch, reviewers, timeout, logger):
    workers = []
    with logger.step("prepare_checkout"):
        temporary = tempfile.TemporaryDirectory(prefix="adversarial-review-")
    try:
        root = Path(temporary.name)
        checkout = root / "repo"
        clone = start_worker(["git", "clone", "--quiet", "--single-branch", "--no-tags",
                              "--filter=blob:none", "--branch", branch,
                              "--", repo, str(checkout)], root, logger.directory / "clone",
                             "clone", workers, logger)
        wait_for([clone], DEFAULT_TIMEOUT_SECONDS, logger)
        with logger.step("write_schema"):
            schema_path = root / "schema.json"
            schema_path.write_text(json.dumps(OUTPUT_SCHEMA))
        with logger.step("reviewers", reviewer_count=len(reviewers)):
            reviewers_running = []
            for index, reviewer in enumerate(reviewers):
                directory = logger.directory / "reviewers" / str(index)
                output_path = directory / "findings.json"
                command = reviewer_command(reviewer, schema_path, output_path)
                reviewers_running.append(start_worker(
                    command, checkout, directory,
                    f"reviewer {index + 1} ({reviewer['agent']}, {reviewer['model']})",
                    workers, logger, reviewer["agent"], output_path, reviewer["model"]))
            results = wait_for(reviewers_running, timeout, logger)
    finally:
        with logger.step("cleanup", temporary_directory=temporary.name):
            try:
                stop_workers(workers, logger)
            finally:
                temporary.cleanup()
    # Cleanup completes before writing anything to stdout.
    return results


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
    logger = None
    try:
        logger = RunLog(args.branch)
        logger.write("run.started", f"Review logs: {logger.directory}",
                     run_id=logger.directory.name, branch=args.branch, repo=args.repo,
                     reviewers=args.reviewers, timeout_seconds=args.timeout)
        results = review(args.repo, args.branch, args.reviewers, args.timeout, logger)
        with logger.step("write_output", reviewer_count=len(results)):
            print(json.dumps(results, ensure_ascii=False, indent=2), flush=True)
        logger.write("run.finished", "Review succeeded", status="succeeded",
                     duration_seconds=round(time.monotonic() - logger.started, 6))
        return 0
    except Interrupted as error:
        if logger:
            logger.write("run.finished", f"error: {error}", status="interrupted",
                         signal=signal.Signals(error.signum).name,
                         duration_seconds=round(time.monotonic() - logger.started, 6))
        else:
            log(f"error: {error}")
        return 128 + error.signum
    except (ReviewError, OSError, ValueError, KeyError, TypeError) as error:
        if logger:
            logger.write("run.finished", f"error: {error}", status="failed", error=str(error),
                         duration_seconds=round(time.monotonic() - logger.started, 6))
        else:
            log(f"error: {error}")
        return 1
    finally:
        if logger:
            logger.close()


if __name__ == "__main__":
    sys.exit(main())
