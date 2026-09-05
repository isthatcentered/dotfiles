Review {{review_scope}} using the instructions below.

# Code Review

## Scope

- "last commit" / "HEAD" → `HEAD` only
- "branch" / "my changes" / "PR" / unspecified → branch vs `main` (fallback `master`)

If ambiguous, ask once. Otherwise pick and state in one line.

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

Write all findings to an OS temporary file using the report template below.
Return the file’s absolute path.
Always include coverage and limits, even when there are no findings.
If none are supported, write `No supported findings identified` under Findings.

Markdown. Concise. Fragments fine. No preamble, no closing summary.
See [REPORT-EXAMPLE.md](./REPORT-EXAMPLE.md) for a completed finding.

````
## Scope
<commit(s), resolved base SHA, reviewed HEAD SHA>


## What changed
<3–8 bullets, before → after, intent terms — not a diff readout>


## Coverage and limits

- Reviewed: <behavior and interactions inspected>
- Checks: <checks executed and outcomes, or none>
- Limits: <material areas left unreviewed, missing context, or blocked verification; none if applicable>


## Findings

### 1. <Trigger causes observable failure>

Severity: <low | medium | high> — <impact if the bug occurs>
Likelihood: <low | medium | high | unknown> — <how likely users are to encounter the trigger, with reasoning>
Verification: <reproduced | not executed — inferred from code | inconclusive>

**Problematic location**
File: `<path>` @ `<head SHA>`
Start line: <N>
End line: <M>

**What goes wrong**
<Trigger, affected users, and observable consequence.>

**Before**
`<before path>` @ `<base SHA>`, lines <N–M>
```<lang>
<exact original code>
```

**After**
`<after path>` @ `<head SHA>`, lines <N–M>
```<lang>
<exact current code>
```

**Why it happens**
<Explain the causal chain from the changed code to the failure.
State the violated contract or invariant and cite its supporting
documentation, test, caller, or other evidence with revision and line range.>

**How to reproduce**
Prerequisites: <required state, configuration, environment, or none>

1. <Concrete input, command, request, or action against the reviewed code>
2. <Action that exposes the failure; specify ordering if relevant>

Expected: <specific correct result>
Actual / Predicted actual: <observed result if executed; predicted result otherwise>

**Evidence and limits**
<What was executed and observed, or what was inferred without execution.
Identify untested consequences, assumptions, and remaining uncertainty.>
````

### Locations and code excerpts

- Use repository-relative paths and resolved commit SHAs. Line numbers are 1-based and inclusive. Always provide both start and end, even for a single line.
- Anchor the problematic location to the smallest range that identifies the cause at the reviewed `HEAD`. List supporting locations separately when the explanation spans files.
- **Before** is the state at the review base; **After** is the state at the reviewed `HEAD`. Not intermediate commits. Each side has its own path and range to account for renames and shifted lines.
- Copy exact excerpts with enough surrounding code to explain the failure. Do not rewrite or invent code for either side.
- For added code, write `New code — no before location or excerpt`. For deleted code, write `Deleted — no after location or excerpt` and anchor the problematic location to the deleted range at the base SHA, explicitly marking it as a deletion. Never invent a range for an absent side.

### Severity, likelihood, and verification

- **Severity:** impact when the bug occurs.
  High: severe harm or core workflow failure.
  Medium: meaningful disruption. Low: minor consequences.
- **Likelihood:** frequency of the trigger in expected usage.
  High: common. Medium: occasional. Low: rare. Unknown: insufficient context.
  Explain the rating; do not invent percentages.
- **Verification:** reproduced, not executed, or inconclusive.
  Distinguish observed results from predictions and state evidence limits.

Likelihood measures occurrence, not confidence that the finding is correct.

## Style

- Use backticks for identifiers, paths, and values.
- Do not include suggested fixes.

## Don't flag

Report behavioral defects, not style preferences, naming, commit wording,
diff summaries, or generic requests for tests.
