Review {{review_scope}} using the instructions below.

# Code Review

## Scope

Use the exact base and HEAD SHAs supplied in the review scope. If either is missing or unavailable, report the blocker to the orchestrator.

## Phase 1 — Understand

Before looking for bugs, establish:

1. **Before** — what did the system do?
2. **After** — what does it do now?
3. **Intent** — what was the author trying to do?
4. **Drift** — what changed outside the stated intent?

Start with the aggregate diff from the review base to the final state.
Consult commit messages and individual diffs as needed to clarify intent
or explain how the change evolved. Verify intent against the code.
Read surrounding code when needed to explain the behavior.

Before and After describe the review base and final state.

## Phase 2 — Find issues

Find every issue introduced by the changes that remains in the
final state:

- **Logic gaps** — incorrect behavior, missing cases, broken assumptions.
- **Security issues** — exploitable weaknesses, unauthorized access,
  data exposure.
- **Regressions** — previously working behavior that now fails.
- **Concurrency issues** — race conditions, unsafe shared state,
  ordering failures, deadlocks.

Use Before, After, Intent, and Drift to guide the review.
For each issue, identify a concrete trigger and consequence.

Cover all changed behavior and its interactions with existing code.
One change can introduce multiple independent issues: correcting a
logic gap may still leave a race condition. Report each separately.

Finding one issue is not a stopping point. Report every supported
finding; do not invent issues to fill the report.

## Phase 3 — Report

Return all findings as a JSON object matching the supplied output schema.
The CLI saves this final response; do not return a Markdown report or a file path.
Always include coverage and limits, even when there are no findings.
If none are supported, return an empty findings array.

Concise. Fragments fine. No preamble, no closing summary.

- Scope: copy runId, baseSha, and headSha from the request; schemaVersion is 2.
- whatChanged: 3–8 items, before → after, intent terms — not a diff readout.
- coverage.inspected: behavior and interactions inspected.
- coverage.reviewedFiles: each inspected repository file with its pinned revision
  and path, even if there are no findings.
- coverage.checks: checks executed and outcomes, or an empty array if none.
- coverage.limits: material areas left unreviewed, missing context, or blocked
  verification; an empty array if none.
- completeness: complete or partial. Use partial when material behavior could
  not be reviewed, and explain why in coverage.limits. Failed tests alone do
  not imply a partial review if the behavior could still be established.

Each finding has a unique local id and these fields:

- title: trigger causes observable failure.
- severity: low, medium, or high, with reasoning about impact if the bug occurs.
- likelihood: low, medium, high, or unknown, with reasoning about how likely
  users are to encounter the trigger.
- problematicLocation: path, revision, startLine, endLine; kind head or deletion.
- whatGoesWrong: trigger, affected users, and observable consequence.
- codeViews: one or more named source views explaining the defect. Each has a
  unique id, a meaningful label (such as “Failure swallowed”), and an explanation
  of its role. Include the origin and every contributing caller, implementation,
  configuration, test, or unchanged context needed to understand the issue.
  Each view has its own before and after side: kind present with revision, path,
  and one or more labeled ranges (startLine, endLine, exact excerpt), or kind
  absent with reason added (before) or deleted (after). Multiple disjoint ranges
  in one file belong in one view. Renames or moved code use different side paths.
  At least one range must include the finding's problematicLocation.
- whyItHappens: explain the causal chain from the changed code to the failure.
  State the violated contract or invariant and cite its supporting
  documentation, test, caller, or other evidence with revision and line range.
- assessment: supported or needs-verification, with reasoning. When the defect
  depends on an unresolved external fact or ambiguous intent, prominently record
  that assumption and concrete verificationSteps. This is separate from severity,
  likelihood, reviewer agreement, and whether a reproduction was executed.
  Do not invent conditional findings; retain only supported code evidence and
  state exactly what remains uncertain.
- reproduction.prerequisites: required state, configuration, environment, or
  an empty array if none.
- reproduction.steps: concrete inputs, commands, requests, or actions against
  the reviewed code. Specify ordering if relevant.
- reproduction.expected: specific correct result.
- reproduction.actual: observed result if executed; predicted result otherwise.
- reproduction.basis: observed or predicted, matching the actual field.
- evidence: structured source references (codeViewId), supplied context document
  references (documentId), external HTTP(S) documentation references (url and a
  short quote), or checks (command, passed/failed/not-run outcome, exact relevant
  output). Each has a label and explanation of what it establishes. Only cite
  supplied document IDs; other repository documents can be shown as code views.
  External citations must be inspected, not invented. A check is passed or failed
  only if executed; otherwise use not-run. Preserve relevant contradictory
  evidence as well as support.
- limits: assumptions, untested consequences, and remaining uncertainty.
  Distinguish observations from predictions.

### Locations and code excerpts

- Use repository-relative paths and resolved commit SHAs. Line numbers are 1-based and inclusive. Always provide both start and end, even for a single line.
- Anchor the problematic location to the smallest range that identifies the cause at the reviewed `HEAD`. Provide separate labeled code views when the explanation spans files.
- **Before** is the state at the review base; **After** is the state at the reviewed `HEAD`. Not intermediate commits. Each side has its own path and range to account for renames and shifted lines.
- Copy exact excerpts with enough surrounding code to explain the failure. Do not rewrite or invent code for either side.
- For added code, use an absent before side with reason added. For deleted code, use an absent after side with reason deleted and anchor the problematic location to the deleted range at the base SHA, explicitly marking it as a deletion. Never invent a range for an absent side.

### Severity and likelihood

- **Severity:** impact when the bug occurs.
  High: severe harm or core workflow failure.
  Medium: meaningful disruption. Low: minor consequences.
- **Likelihood:** frequency of the trigger in expected usage.
  High: common. Medium: occasional. Low: rare. Unknown: insufficient context.
  Explain the rating; do not invent percentages.

Likelihood measures occurrence, not confidence that the finding is correct.

## Style

- Use backticks for identifiers, paths, and values.
- Do not include suggested fixes.

## Don't flag

Report behavioral defects, not style preferences, naming, commit wording,
diff summaries, or generic requests for tests.
