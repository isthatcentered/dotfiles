---
name: adversarial-code-review
description: Orchestrate a multi-agent adversarial code review.
disable-model-invocation: true
---

You are the orchestrator of an adversarial code review.

## 1. Resolve scope

Resolve the user's scope once:

- "last commit" / "HEAD": review `HEAD` against its parent.
- "branch" / "my changes" / "PR" / unspecified: review the branch against its merge base with `main` (fallback `master`).

Clarify ambiguity before launching reviewers. Read [REVIEW-PROMPT.md](./REVIEW-PROMPT.md) and replace `{{review_scope}}` with the resolved scope, including the exact base and HEAD SHAs. All reviewers must inspect the same revisions.

## 2. Run reviewers

Pass the same completed prompt to three independent reviewers:

- Codex Astra, high reasoning, using $spin-up-codex.
- Codex Sol, high reasoning, using $spin-up-codex.
- Claude Opus, high reasoning, using $spin-up-claude.

Collect their report files. Record each reviewer's identity, completion status, coverage, and limits. Distinguish a completed review with no findings from a failed or incomplete review; disclose missing coverage in the final report.

## 3. Consolidate findings

Merge findings describing the same underlying defect, trigger, and consequence. Keep independent defects separate, even when they affect the same code.

Preserve the clearest explanation and complementary evidence, reproduction details, and evidence limits. Resolve conflicting severity or likelihood ratings against the evidence; retain uncertainty when disagreement remains unresolved.

For each finding, record the distinct reviewers who independently reported it and their count. Count each reviewer once. Agreement is separate from likelihood and must not increase its rating.

Preserve every finding field required by REVIEW-PROMPT.md, including revision-specific locations and exact excerpts. Do not add suggested fixes.

Keep the original reviewer report files. After consolidation, encode the results as
`handoff.json` using [references/report-generator.md](./references/report-generator.md).
Translate the reviewers' Markdown without changing their prompts, inventing
evidence, or treating an unexecuted reproduction as observed. Preserve complementary
files and ranges, reviewer coverage, disagreements, and exclusions.

## 4. Build report

Use this skill's bundled Feed template generator. Do not build or redesign the UI
or launch a UI agent. Resolve this skill's directory to an absolute path; its
template and generator are independent of `adversarial-code-review-2`.

Save the handoff in `.agents/review/{timestamp}/handoff.json`, using a filesystem-safe
timestamp and a stable run ID. Run:

```sh
python3 /absolute/path/to/adversarial-code-review/scripts/generate-report.py \
  --repo /absolute/path/to/reviewed/repository \
  --input /absolute/path/to/.agents/review/{timestamp}/handoff.json
```

The generator validates the handoff and source citations, captures full files from
the pinned Git revisions, writes `report.json`, and renders `index.html`. Feed opens
with the full-width “What changed” recap, followed by continuous findings and a
sticky source pane. It includes scope, reviewer failures, and coverage limits even
with no findings. [REPORT-UI.md](./REPORT-UI.md) describes the bundled design.

## 5. Verify and deliver

The generator runs browser checks in an isolated context and saves their actual
outcome in `verification.json`. Read the final stdout JSON and `result.json`:

- Exit 0: complete review and verified delivery.
- Exit 2: report exists, but review, consolidation, or browser verification is incomplete.
- Exit 1: failed review (a failure report when possible) or invalid handoff (`reportPath: null`).

Fix malformed handoff data using the original evidence and rerun the generator.
Never mark a failed reviewer as completed to make validation pass. Disclose browser
verification failures or limits. Do not rerun reviewers solely because rendering
or browser verification failed.

Return the clickable absolute `reportPath`, disclosing partial reviews, failed
stages, and verification limits. A failed review is never “no findings.”
