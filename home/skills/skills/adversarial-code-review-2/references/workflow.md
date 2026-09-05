# Workflow and contracts

Requires Python 3.10+, Git, and authenticated `codex`/`claude` CLIs. Python uses
only its standard library. Browser verification prefers the installed
`chrome-devtools` CLI, with standalone headless Chrome/Chromium as a fallback.

## Invocation

Run `scripts/review.py --scope branch` from the repository, or supply `--repo`.
`last-commit`/`HEAD` compares HEAD's parent to HEAD. `branch` uses the merge base
with main (local, then origin), falling back to master. `BASE..HEAD` resolves two
explicit revisions. Invalid scopes fail before agents launch. Uncommitted source
is excluded; existing local changes are preserved.

Scope is the only required argument. The runner automatically reads
`.agents/review-config.json` when present. `--config /absolute/config.json` selects
another profile; top-level fields shallowly override `scripts/config.json`.
Models default to Astra high, Sol high, Opus high, and Sol medium consolidation.
No model is silently substituted. A reusable template renders the UI each run.

## Intent, exceptions, and documents

A profile's `context` field supplies persistent context. `--context file.json`
overrides its selected fields for one run. Example context JSON:

```json
{
  "intent": "Preserve scheduling order while simplifying the scheduler.",
  "acceptedExceptions": ["Forced extracts may coexist with one ordinary extract."],
  "documents": [
    {"id": "scheduling-contract", "title": "Scheduling contract", "path": ".scratch/scheduling/PRD.md"}
  ]
}
```

Document paths are relative to the reviewed repository or absolute. Documents
are read once, copied into the request with content hashes, and embedded in the
HTML. All reviewers and the consolidator receive the same captured context.
A later document edit does not change the review evidence. Context documents do
not change the pinned source snapshot and are not executable instructions.

The original review criteria remain in `references/review-prompt.md`. Phase 3
requests structured JSON. Reviewers distinguish source evidence from unresolved
assumptions and evaluate accepted exceptions without inventing requirements.

## Reproducing the test environment

Each attempt uses an independent temporary Git clone with pinned HEAD and no
remote. Its Git objects are shared with the original repository; metadata, source
working files, and dependency copies are separate. These clones isolate normal
worker/test writes but are not an OS security boundary. Codex uses workspace-write
with approvals disabled; Claude uses its noninteractive permission bypass.

The environment plan is resolved once and recorded in `request.json`. Each worker
writes its preparation result to its attempt's `environment.json` and to
`worker-environment.json` in its clone. The reviewer reads that result before
running checks. Preparation limits appear in the final report independently of
agent-written coverage claims.

Default preparation:

- Read Node requirements from pinned `.nvmrc`, `.node-version`, Rush's
  `nodeSupportedVersionRange`, or `package.json` engines, in that order. Select a
  compatible installed NVM runtime when possible; otherwise inspect the inherited
  runtime and disclose mismatches. Exact/major/minor pins and whitespace-separated
  comparator ranges are supported. Other semver syntax is disclosed as unverified.
- Reuse ignored `node_modules` trees and Rush `common/temp` when local dependency
  manifests match reviewed HEAD. Copy regular files, preserving independent writes.
  Rebase internal symlinks to the clone; omit external links with an explicit
  limitation. Do not symlink workers back to writable original dependency trees.
- Run configured setup commands in each clone, with a preparation deadline. Setup
  output and exit status are retained. Restore pinned tracked source if setup
  modified it, and disclose the restoration. Failed setup does not masquerade as
  a successful check; source analysis can continue with the recorded limits.

A profile can override `environment` (supply the whole object):

```json
{
  "environment": {
    "reuseDependencies": true,
    "copyPaths": [],
    "pathPrefixes": [],
    "setupCommands": [["node", "common/scripts/install-run-rush.js", "install"]],
    "timeoutSeconds": 600
  }
}
```

`copyPaths` adds repository-relative untracked dependency directories. Tracked
paths are rejected. `pathPrefixes` selects runtime/tool binary directories.
`setupCommands` contains argument arrays, not shell strings; only explicitly
configured commands run. The default performs no package installation. Copying
large dependency trees costs disk/time; disable reuse and configure installation
when appropriate. Installed-package correctness and live service availability are
still established by actual checks, not by copying files successfully.

## Execution and failures

Three direct CLI subprocesses run concurrently; they cannot see one another's
reports through their prompts or clones. All use the same completed review prompt.
After every reviewer settles, Sol medium consolidates usable reports.

Startup deadline: 120 seconds. Overall attempt deadline: 30 minutes. Startup
requires a recognized CLI event, not merely a PID or stderr output. Quiet work
remains valid until the overall deadline. A successful terminal event, zero exit,
schema-valid final object, matching scope, and valid source evidence are required.

Startup timeouts and recognized transient service failures get one fresh retry.
Missing CLIs, authentication failures, permanent process failures, invalid output,
and overall timeouts do not retry. Attempts/logs are retained; retries never count
as additional reviewers. Timeouts terminate process groups. SIGINT/SIGTERM stop
workers and preserve collected reports, then render a report of the actual outcome.

A missing reviewer produces partial coverage. No usable reports skips
consolidation and renders a failure page. Consolidation failure renders validated
raw findings separately, labeled unconsolidated. Reviewer completeness and delivery
completeness are separate: completed reviews can have incomplete consolidation or
browser verification. An unavailable report is never “zero findings.”

## Version 2 data contracts

`scripts/contracts.py` defines strict reviewer and consolidator JSON schemas.
The schema passed to each CLI is retained with that attempt. Script-owned execution
metadata cannot be changed by an agent. Findings contain:

- One `problematicLocation`: the defect's origin at HEAD, or base for deletion.
- `codeViews[]`: unique IDs, meaningful labels, explanations, and independent
  Before/After sides. Present sides contain a path, pinned revision, and multiple
  labeled inclusive ranges with exact excerpts. Absent sides identify added or
  deleted code. Views cover changed code, unchanged context, renames, and moves.
- `assessment`: supported/needs-verification, reasoning, assumptions, and concrete
  verification steps. This is separate from severity, likelihood, agreement, and
  user triage status. It never implies a reproduction was executed.
- `evidence[]`: source-view references, captured context-document references,
  HTTP(S) references with short quotes, or executed/not-run checks with commands
  and relevant output. Every item has a label and explanation.
- Consequence, causal explanation, reproduction with observed/predicted basis,
  severity/likelihood reasoning, and evidence limits, as in the original prompt.

Reviewer coverage also lists `reviewedFiles` by revision and path. Changed files
and explicitly reviewed files populate `fileViews` independently of findings.
Renames preserve separate before/after paths. Binary, missing, or files above the
2 MB browser capture limit remain listed as unavailable with a reason; valid
finding excerpts are checked independently against Git.

Consolidation sources use `{reviewer, findingId}`. Every input finding must appear
exactly once in a merged finding or in excluded with a reason. Complementary
source ranges, document references, external references, and checks cannot silently
vanish during merging. Ratings, unresolved assumptions, and disagreements remain
evidence-based; absence of a finding is not inferred dissent.

| Artifact | Contents |
| --- | --- |
| request.json | Run ID, pinned scope, prompt version, captured context, environment plan |
| config.json | Effective configuration |
| reviewers/{id}/attempt-N/ | Prompt, schema, command, events, stderr, final JSON, attempt record, environment result/setup logs |
| reviewers/{id}/outcome.json | Model, effort, attempts, completed/partial/failed, validated report or null |
| reviewers.json | Request and all reviewer outcomes |
| consolidation/ and consolidation.json | Consolidator attempts and outcome when invoked |
| report.json | Version 2 findings, provenance, context, source/file views, execution status, warnings and limits |
| verification.json | Browser check status and limits |
| index.html | Self-contained review UI with embedded code, evidence, and documents |
| result.json | complete/partial/failed, absolute reportPath, counts, warnings |

## UI, migration, and verification

The source viewer lets readers choose a named code view, switch its revision,
select one or all labeled ranges, and open the full file. Switching revision
preserves the selected view. Source browsing also works with zero findings.
Structured evidence opens the associated source, captured document, external
reference, or check output. Conditional findings display their unresolved
assessment prominently. Open/Done/Rejected, reopening, comments, and complete
copying remain independent of that assessment.

Report/finding IDs preserve browser decisions across re-rendering the same report.
`--render /absolute/report.json` performs no model calls. Version-1 reports from
this skill migrate using their stored data only: unavailable historical source is
labeled, original evidence is preserved, and missing assessments are not invented.
Other historical report formats are not silently interpreted as version 1.

Browser verification uses a temporary copy and separate browser context/profile;
it closes its own tab afterward. It checks every finding and code view, both
revisions, every range and all ranges together, exact rendered source, full files,
source browsing without findings, evidence/assessment rendering, switching between
findings, independent comments/statuses through a reload, and complete copy content.
OS clipboard transport is simulated. Verification code is absent from the delivered
HTML. External URLs are not fetched by rendering or verification.

Exit 0 means complete delivery; exit 2 means partial delivery with a report; exit 1
means failed review (a failure page when possible, null reportPath for an early or
unrecoverable error). Progress goes to stderr; stdout ends with result JSON.

Run fixture tests without model calls:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s /absolute/path/to/adversarial-code-review-2/tests -v
```
