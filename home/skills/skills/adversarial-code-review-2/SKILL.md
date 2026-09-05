---
name: adversarial-code-review-2
description: Run a scripted adversarial code review with three independent CLI reviewers, consolidation, and a standalone HTML report. Use when the user requests this review workflow.
---

# Adversarial Code Review 2

Run the bundled script from the repository being reviewed. Resolve this skill's
directory to an absolute path first; the command must not depend on the caller's
working directory containing the skill.

```sh
python3 /absolute/path/to/adversarial-code-review-2/scripts/review.py --scope branch
```

Scope is the only required parameter:

- `last-commit` (also `HEAD` or `last commit`): HEAD's parent to HEAD.
- `branch` (default for “my changes” or an unspecified scope): merge base with
  main, falling back to master, to HEAD.
- `BASE..HEAD`: the two explicit Git revisions, resolved once.

These scopes cover committed revisions. The report discloses excluded local
changes. Do not silently interpret a request to review uncommitted changes as
`branch`; explain that this version needs committed revisions.

Scope remains the only required parameter. If the user supplied intent,
accepted exceptions, or relevant local documents, pass them through a temporary
context JSON file using `--context /absolute/context.json`; preserve the user's
wording and do not invent exceptions. Its fields are `intent` (text),
`acceptedExceptions` (text array), and `documents` (objects with unique `id`,
`title`, and `path`, relative to the reviewed repository or absolute). The script
snapshots documents for all workers and the report. The repository may provide
`.agents/review-config.json` for persistent context and environment settings.

The script launches Codex Astra high, Codex Sol high, and Claude Opus high in
separate temporary clones, then Codex Sol medium for consolidation. It owns
timeouts, one bounded retry for transient failures, validation, source capture,
rendering, environment preparation, and verification. Do not orchestrate additional reviewers yourself.
The UI is a reusable bundled template; no UI agent is needed on each run.
Findings have one primary location and multiple labeled source views with their
own Before/After paths and ranges. The report preserves evidence, explicit
verification needs, and source browsing even with no findings. Existing
version-1 reports can still be rendered with `--render`.

Allow the command to finish, polling a running tool session as needed. Progress
goes to stderr; the final stdout line is JSON. Read its `status`, `reportPath`,
and `warnings`. Return the clickable absolute HTML path and disclose partial
reviews, failed stages, and verification limits. Exit 2 means a report exists
but the run is incomplete; exit 1 means the review failed. Neither means “no
findings.” Do not retry the whole workflow merely because it exits nonzero.

The existing `adversarial-code-review` skill remains an independent alternative.
For configuration, artifact contracts, or troubleshooting, read
[references/workflow.md](references/workflow.md). The script's `--help` lists
optional repository, configuration, and existing-report rendering arguments.
