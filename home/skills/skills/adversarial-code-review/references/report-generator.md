# Report generator handoff

- [Workflow](#workflow)
- [Reviewer outcomes](#reviewer-outcomes)
- [Findings and evidence](#findings-and-evidence)
- [Generate and deliver](#generate-and-deliver)

## Workflow

Keep the three original reviewer prompts unchanged. Read their Markdown reports,
consolidate the evidence, then translate it into `handoff.json`. The generator
performs no model calls and does not run reproduction commands. It validates the
handoff, captures pinned Git blobs, renders Feed, and checks the UI.

Requires Python 3.10+ and Git; no Python packages. Verification uses the installed
`chrome-devtools` CLI or Chrome/Chromium. Get the exact input schema:

```sh
python3 /absolute/path/to/adversarial-code-review/scripts/generate-report.py --schema
```

The schema lives in `scripts/generate-report.py` and `scripts/contracts.py`.
All fields are required; use empty strings/arrays for absent information.
Start with this envelope, replacing placeholder SHAs and filling actual outcomes:

```json
{
  "schemaVersion": 2,
  "runId": "20260906-120000",
  "scope": {"requested": "last commit", "baseSha": "FULL_BASE_SHA", "headSha": "FULL_HEAD_SHA"},
  "context": {"intent": "", "acceptedExceptions": [], "documents": []},
  "reviewers": [],
  "consolidation": {"status": "skipped", "failure": "No usable reviewer reports."},
  "whatChanged": [],
  "findings": [],
  "excluded": [],
  "limits": ["No reviewer completed; no review conclusion is available."]
}
```

This skeleton represents a failed review, not a successful empty result.
Populate `whatChanged` with 3–8 behavioral before → after bullets from the reviews.
If all reviewers failed, the orchestrator may supply a factual diff recap while
explicitly stating that no review conclusion is available.

## Reviewer outcomes

Include one outcome for each of `codex-astra`, `codex-sol`, `claude-opus`:

```json
{
  "reviewer": "codex-astra",
  "model": "gpt-6-astra",
  "effort": "high",
  "status": "completed",
  "failure": "",
  "reportPath": "/absolute/path/to/original-review.md",
  "findingIds": ["finding-1"],
  "coverage": {
    "inspected": ["Cache reads and invalidation across tenants"],
    "reviewedFiles": [{"revision": "FULL_HEAD_SHA", "path": "src/cache.ts"}],
    "checks": [{"description": "Reproduction", "outcome": "not-run", "details": "Source inspection only."}],
    "limits": []
  }
}
```

Use the actual requested model identity, not a guessed observed model. Assign
stable `findingIds` to the original findings before merging; unique per reviewer.
Keep original report files for auditing. The generator does not parse Markdown or
independently assess semantic completeness of consolidation.

- `completed`: finished usable review, including a valid zero-finding report.
- `partial`: usable findings/coverage with explicit `coverage.limits`.
- `failed`: no usable report; require the actual `failure` reason and empty
  `findingIds`. Use empty coverage if nothing was inspected. A CLI that did not
  launch is failed, not a completed review with no findings.

Missing outcomes are automatically filled as failed; the expected count always
remains three. Failed reviewers cannot contribute findings or agreement. Retries
never become additional reviewer identities.

## Findings and evidence

Each `findings` entry contains `finding` (the complete FINDING object from the
schema), `sources` (one or more `{reviewer, findingId}` references), and
`disagreements` (zero or more `{reviewer, explanation}` objects).

| Finding field | Contents |
| --- | --- |
| `id`, `title` | Unique consolidated ID and trigger/consequence title |
| `severity`, `likelihood` | `{value, reasoning}`; low/medium/high; likelihood also permits unknown |
| `problematicLocation` | `{kind: "head" or "deletion", location: {revision, path, startLine, endLine}}` |
| `whatGoesWrong`, `whyItHappens` | Consequence and causal explanation |
| `codeViews` | Labeled origin and complementary supporting views |
| `assessment` | `{status, reasoning, assumptions, verificationSteps}`; supported or needs-verification |
| `reproduction` | `{prerequisites, steps, expected, actual, basis}`; observed or predicted |
| `evidence`, `limits` | Structured evidence and remaining uncertainty |

Preserve unresolved assumptions as `needs-verification`, with concrete verification
steps. Do not infer support from agreement or turn predictions into observations.
Preserve all original report fields; empty arrays are not permission to omit evidence.

Each code view has `id`, `label`, `explanation`, `before`, `after`. A present side:

```json
{
  "kind": "present",
  "revision": "FULL_PINNED_SHA",
  "path": "src/cache.ts",
  "ranges": [{"label": "Cache key", "startLine": 6, "endLine": 9, "excerpt": "EXACT_SOURCE_LINES"}]
}
```

Before uses base; After uses HEAD. Ranges are 1-based and inclusive; each side
keeps its own path and multiple ranges. At least one view must cover the primary
location. Absent sides are exactly `{"kind":"absent","reason":"added"}` for
Before or `{"kind":"absent","reason":"deleted"}` for After. Never invent an
absent side's location. The generator captures full files; do not embed full files
in the handoff. Supplied excerpts are checked against Git, not rewritten.

Evidence variants (all include `kind`, `label`, `explanation`):

- `source`: `codeViewId` referencing a view in this finding.
- `document`: `documentId` referencing a context document.
- `external`: HTTP/S `url`, `quote`.
- `check`: `command`, `outcome` (passed/failed/not-run), `output`.

Context documents have `id`, `title`, `path`, `content`: preserve the text captured
during review, not a later live version. The generator hashes/embeds it. Preserve
supplied intent and accepted exceptions without inventing requirements.

Every original `(reviewer, findingId)` must occur exactly once across `sources`
and `excluded`. Exclusions have `{source: {reviewer, findingId}, reason}`. Count
each distinct reviewer once, even if they reported duplicate issues. Preserve
complementary ranges, documents, checks, and explanations while merging. Absence
of a finding is not dissent.

If consolidation fails, set its status to `failed` with the reason. Keep original
usable findings separately, each with one source and a unique display ID; leave
`excluded` empty. With no usable reviews, use `skipped` and empty findings.

## Generate and deliver

```sh
python3 /absolute/path/to/adversarial-code-review/scripts/generate-report.py \
  --repo /absolute/repository --input /absolute/run/handoff.json
```

Outputs beside the handoff (or under `--output /absolute/directory`):
`report.json` with captured source, `index.html`, `verification.json`, `result.json`.
The handoff is preserved. Do not name it `report.json`, a reserved output name.
Local changes are excluded/disclosed; moving HEAD does not change pinned evidence.

Verification checks all source views, revisions/ranges, full files, empty states,
evidence, copying, triage, notes, and persistence after reload in a temporary
isolated context. Clipboard transport is simulated and disclosed. The delivered
HTML contains no verification code. `--browser disabled` records a verification
limit, not a pass; normal delivery uses automatic checks.

Final stdout JSON contains `status`, absolute `reportPath`, counts, and `warnings`.
Exit 0 means complete; 2 means partial delivery; 1 means failed review or invalid
input. Invalid input gives `reportPath: null`; do not deliver an older output file
left in that directory. Report actual review and verification failures to the user.

Re-render a generated report with stored source, without Git or agents:

```sh
python3 /absolute/path/to/adversarial-code-review/scripts/generate-report.py \
  --render /absolute/run/report.json
```

Keep the run ID and original finding IDs stable to preserve saved browser decisions.
