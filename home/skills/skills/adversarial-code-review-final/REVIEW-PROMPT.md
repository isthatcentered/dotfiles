Review the current branch using the instructions below.

# Code Review


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
Findings do not need to be proven or reproduced. Ground them in the code
and state assumptions and uncertainty; the user will validate them.

Cover all changed behavior and its interactions with existing code.
One change can introduce multiple independent issues: correcting a
logic gap may still leave a race condition. Report each separately.

Finding one issue is not a stopping point. Report every supported
finding; do not invent issues to fill the report.

The automated checks (tests/typecheck/lint/...) have already been run, you do not need to run them. You are allowed to write some temporary tests/scripts/whatever if you want to verify a finding.

## Phase 3 — Report

Return all supported findings as a JSON object matching the structure below. If no findings are supported, return `{"findings": []}`. Output only JSON.

```
{
  "findings": [
    {
      "location": {
        "start_line": 1, // First line of the problematic code; 1-based, inclusive.
        "end_line": 1,   // Last line of the problematic code; 1-based, inclusive.
        "file_path": "src/example.py" // Path relative to the repository root.
      },
      "summary": "...", // Short description of the issue.
      "why_it_was_flagged": "...", // Explain how the code causes the failure, including assumptions and uncertainty.
      "blast_radius": "...", // Describe affected users, workflows, or data and the consequences.
      "severity": {
        "level": "medium", // One of: low, medium, high. Rate impact if the bug occurs.
        "reason": "..." // Explain the impact supporting this rating.
      },
      "occurrence_likelihood": {
        "level": "unknown", // One of: low, medium, high, unknown. Rate how likely users are to encounter the trigger in expected usage.
        "reason": "..." // Explain the expected trigger frequency, or why it is unknown.
      },
      "example": "..." // Concrete prerequisites, inputs, or actions that trigger the bug, with expected and actual behavior.
    }
  ]
}
```

## Don't flag

Report behavioral defects, not style preferences, naming, commit wording,
diff summaries, or generic requests for tests.
