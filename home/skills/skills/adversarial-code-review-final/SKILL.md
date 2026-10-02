---
name: adversarial-code-review-final
description: Run an explicitly requested scripted code review of a repository branch with a supplied list of Codex and Claude reviewers, returning all findings as a JSON array.
disable-model-invocation: true
---

Run the bundled script to execute the entire review workflow. Require a repository URL, a nonempty branch name, and a nonempty JSON array of reviewers. Each reviewer has an `agent` (`codex` or `claude`) and a nonempty `model` string. Ask for missing inputs; do not choose a branch or reviewer lineup implicitly.

Use Python 3.10+, Git, and the authenticated CLIs selected by the reviewer list. Resolve `scripts/review.py` relative to this skill directory, then run:

```sh
python3 /path/to/adversarial-code-review-final/scripts/review.py \
  --repo git@github.com:owner/repository.git \
  --branch feature/example \
  --reviewers '[{"agent":"codex","model":"gpt-6-astra"},{"agent":"codex","model":"gpt-6-astra"},{"agent":"claude","model":"claude-opus-5-5"}]'
```

The script owns the workflow:

1. Clone the specified branch into an OS temporary directory without installing dependencies.
2. Start every reviewer concurrently, using the same checkout root as their cwd, YOLO permissions, high effort, the same prompt, and the same JSON Schema.
3. Capture every child process's stdout and stderr. Codex's `--output-last-message` file contains its response; Claude's JSON response contains `structured_output`. Each response wraps its findings in `{ "findings": [...] }`.
4. Wait for all reviewers, with one attempt and a 20-minute timeout per reviewer. Override the timeout in seconds with `--timeout` when requested.
5. Collect responses, stop remaining child processes, and remove the temporary directory. On failure or interruption, exit nonzero with diagnostics on stderr and empty stdout.
6. Concatenate every finding in reviewer-array order, preserving each reviewer's finding order and duplicates. Print only the resulting JSON array to stdout, or `[]` when all reviewers return no findings.

`PROMPT` near the top of [scripts/review.py](scripts/review.py) reads [REVIEW-PROMPT.md](REVIEW-PROMPT.md) verbatim as UTF-8, relative to the script's location. Edit that Markdown file to change the instructions passed to every reviewer. The script selects the checkout; the prompt determines what to review. Treat the reviewers as review-only: do not change the checked-out code or install its dependencies.

The CLI schema defines these fields; the script does not additionally validate or rewrite findings:

```json
{
  "location": {"start_line": 1, "end_line": 1, "file_path": "src/example.py"},
  "summary": "Short description of the issue",
  "why_it_was_flagged": "Why the reviewer flagged this code",
  "blast_radius": "How the bug affects users",
  "severity": {"level": "high", "reason": "Impact if the bug occurs"},
  "occurrence_likelihood": {"level": "unknown", "reason": "Trigger frequency and reasoning"},
  "example": "How the bug can happen or be triggered"
}
```

Severity levels are `low`, `medium`, and `high`. `occurrence_likelihood` also allows `unknown` and rates how likely users are to encounter the trigger in expected usage. Locations use repository-relative paths and 1-based, inclusive line numbers. Preserve the script's stdout when returning the review; send any surrounding status messages to stderr.
