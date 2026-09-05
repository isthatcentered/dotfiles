---
name: adversarial-code-review
description: Orchestrate a multi-agent adversarial code review.
disable-model-invocation: true
---

You are the orchestrator of an adversarial code review.

## 1. Resolve scope

Read [REVIEW-PROMPT.md](./REVIEW-PROMPT.md). Resolve the user's scope once using its scope rules; clarify ambiguity before launching reviewers. Replace `{{review_scope}}` with the resolved scope, including the exact base and HEAD SHAs. All reviewers must inspect the same revisions.

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

## 4. Build report

Create `.agents/review/{timestamp}/index.html`, using a filesystem-safe timestamp. Follow [REPORT-UI.md](./REPORT-UI.md) for layout and interactions. Include the resolved scope, what changed, reviewer completion status, and coverage limits, even when there are no findings.

## 5. Verify and deliver

Open the report and verify finding selection, revision-specific code views, status changes, reopening, comments, persistence after reload, and copying a full finding. Check that added/deleted code and an empty findings list render correctly when present. Disclose any verification limits.

Return the HTML file's absolute path.
