# Workflow and contracts

The runner requires Python 3.10+, Git, and authenticated `codex` and `claude`
executables. It uses the standard library only. The installed `chrome-devtools`
CLI is preferred for report verification, with standalone headless Chrome or
Chromium as a fallback. Browser verification is optional; its absence is
disclosed and makes delivery partial.

## Invocation and configuration

Run `scripts/review.py --scope branch` from the repository, or supply `--repo`.
`last-commit`/`HEAD` reviews the parent to HEAD. `branch` uses the merge base with
main (local, then origin), falling back to master. `BASE..HEAD` compares the two
explicit revisions. Root commits need an explicit available base; ambiguous or
unresolvable scopes fail before any agents launch. No uncommitted source is
included. Local changes are preserved and their exclusion is disclosed.

`scripts/config.json` defines the three reviewer slots, consolidator, CLI paths,
and deadlines. `--config /absolute/overrides.json` shallowly replaces selected
top-level fields; supply the full reviewers array when changing it. The default
models are Astra high, Sol high, Opus high, and Sol medium for consolidation.
`browserCommand` accepts `auto`, a `chrome-devtools` or Chrome/Chromium executable,
or `disabled`.
No provider/model is silently substituted.

The runner starts direct subprocesses and works inside or outside tmux. Each
attempt gets a separate temporary Git clone with independent metadata, pinned
HEAD, and no remote. The clone shares the original Git object database to avoid
copying history. These clones isolate work and test outputs; they are not an OS
security boundary. Codex uses workspace-write with approvals disabled; Claude
uses its noninteractive permission bypass, matching the existing spin-up skill.
Only use this workflow on trusted repositories. Project dependencies are not
copied or automatically installed; reviewers disclose unavailable checks.

The original reviewer criteria are preserved in `review-prompt.md`. Phase 3 uses
JSON instead of Markdown; the accompanying schema specifies the equivalent
finding fields. A worker boundary forbids changing source/revisions, committing,
pushing, or launching more agents. The same completed prompt goes to all three
reviewers. Sol medium gets the validated reports after all reviewers settle.

## Failures and stopping

The default startup deadline is 120 seconds; the overall attempt deadline is
30 minutes, including startup. A startup event means a recognized CLI event,
not simply a live PID or arbitrary stderr. Quiet work after startup remains
valid until the overall deadline. A successful terminal event, zero process
exit, a schema-valid final object, matching scope, and valid source references
are all required for a usable report.

Startup timeouts and recognized transient service failures get one fresh retry.
Missing executables, authentication errors, permanent process failures, invalid
output, and overall timeouts do not retry. Attempts and logs are retained; each
reviewer counts only once. Timeouts terminate the process group. SIGINT/SIGTERM
stop active workers and preserve collected reports; final rendering still runs.

One failed reviewer produces a partial report. No usable reports skips
consolidation and produces a failure page. If consolidation fails validation or
execution, validated raw findings appear separately with an unconsolidated label.
Never interpret an unavailable report as a reviewer reporting zero findings.

Review completeness and delivery completeness are separate. A fully completed
three-reviewer review can still have partial delivery if consolidation or browser
verification fails. The HTML banner reports reviewer completeness; warnings and
the final result disclose downstream failures.

## Data handoffs

All JSON artifacts use schemaVersion 1 where applicable. `scripts/contracts.py`
is the single definition of reviewer/consolidator schemas, with strict local
validation of the supported JSON Schema subset. Each attempt saves the schema
passed to its CLI. Runtime-owned metadata cannot be rewritten by an agent.

| Artifact | Producer | Contents |
| --- | --- | --- |
| request.json | Script | Run ID, prompt version, requested scope, base/HEAD SHAs, changed paths, excluded-local-change indicator |
| reviewers/{id}/attempt-N/ | CLI adapter | Exact prompt, schema, command arguments, event stream, stderr, final JSON, timestamps/exit/failure record |
| reviewers/{id}/outcome.json | Script | Requested/observed model, effort, attempts, completed/partial/failed, validated report or null |
| reviewers.json | Script | Request and all three reviewer outcomes |
| consolidation/ | Sol medium adapter | Consolidator attempts and outcome using the same execution protocol |
| consolidation.json | Script | Consolidator outcome when invoked |
| report.json | Script | Findings, provenance, execution/coverage limits, excluded findings, exact source files, warnings, verification |
| verification.json | Script | Browser check status and limits |
| index.html | Template renderer | Standalone interactive report with embedded JSON and source |
| result.json | Script | complete/partial/failed, absolute reportPath, reviewer counts, warnings |

Reviewer reports carry `whatChanged`, `coverage` (inspected behavior, checks and
outcomes, limits), completeness, and findings. Each finding carries title,
severity/likelihood and reasoning, revision-specific problematic location,
Before/After source sides, consequence, causal explanation, supporting locations,
reproduction with observed/predicted basis, evidence, and limits. A source side
is present with location and exact excerpt, or absent with added/deleted reason.

Consolidation records sources as `{reviewer, findingId}` pairs and preserves
explicit disagreements. Every raw finding must occur exactly once in a merged
finding's sources or in excluded with a reason. The script validates all source
ranges and excerpts against Git, including deleted code and renamed paths. It
derives UI IDs from sorted provenance; comments and decisions persist across
re-rendering the same report, keyed by run ID and UI finding ID. These IDs do not
attempt to track defects across different reviews.

Exit 0: complete delivery. Exit 2: partial delivery with a report. Exit 1: failed
review (a failure page when scope resolved; null reportPath for early/setup or
unrecoverable artifact errors). Progress is stderr; stdout ends with result JSON.

## Template and verification

The reusable template preserves the examples' paper/serif findings area and dark
source sidebar. It renders status/coverage separately from findings, Before/After
and full files with highlighted ranges, comments, Open/Done/Rejected/reopen, and
copying the complete finding. Code and agent text are escaped; generated HTML
has no external assets, runtime fetches, or server requirement.

`--render /absolute/path/report.json` reuses collected evidence and rebuilds the
HTML without any agent calls. It overwrites generated report/verification/result
files in that report directory; browser comments remain local to the report key.

Browser verification uses a temporary HTML copy and a separate browser context
with `chrome-devtools`, or an isolated profile with standalone headless Chrome.
It closes its verification tab afterward. It checks completion status, selection, source revisions/ranges/full
files, status transitions, actual reload persistence, and copy content when a
finding exists. Empty reports check the empty/failure state and disabled source
controls. Clipboard transport is simulated; OS clipboard access is not proven.
Added, deleted, renamed, empty, failed, and normal fixtures exercise the template
in the integration tests. The delivered HTML does not contain verification code.

Run tests without spending model tokens:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s /absolute/path/to/adversarial-code-review-2/tests -v
```

The fake CLIs cover launch/auth/service failures, startup/overall deadlines,
bounded retry, malformed/missing results, scope and excerpt validation,
consolidation loss/failure, provenance, and preserving local changes. They do
not establish current account/model availability. The initial skill has no
runtime dependency on the original skill; the prompt parity test compares
their review criteria while both live in this repository.
