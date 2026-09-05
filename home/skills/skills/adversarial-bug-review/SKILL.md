---
name: adversarial-bug-review
description: Orchestrate a multi-agent adversarial code review. 
disable-model-invocation: true
---

You are the orchestrator of an adversarial code review.

The user will have given you a scope for the code review, replace the {{review_scope}} variable with it.

Spin up 2 codex high using the $spin-up-codex and 1 claude opus high using the $spin-up-claude with the prompt in [REVIEW-PROMPT.md](./REVIEW-PROMPT.md). Read that file, replace {{review_scope}} with the user's scope, and pass the resulting prompt to each agent.

Collect all the findings. De-duplicate them (if a finding has been surfaced by mutltiple agents, only keep one version of the finding).

For each finding in the list, add how many agents surfaced the finding.

Preserve the finding fields from [REVIEW-PROMPT.md](./REVIEW-PROMPT.md), including severity, likelihood, code locations and excerpts, explanation, reproduction, and evidence limits. Agent agreement is separate from likelihood; do not upgrade likelihood based on how many agents reported the issue. Do not add suggested fixes.

Then, create an html report, editorial style in .agents/review/{timestamp}. I must be able to mark the findings as done/rejected.

When a finding is done/rejected, it moves to another list at the bottom.

Keep each finding's title, problematic location, severity, likelihood, and "What goes wrong" visible in the findings list. Selecting a finding reveals its full explanation, reproduction, and evidence limits.

For each finding, display the before and after code with syntax highlighting in a sidebar on the right, with the ability to open the full file at each recorded revision and highlight the recorded line range. I should be able to see both the finding and the code side by side. Clearly label added or deleted code where one side is absent.

I must be able to comment on an issue.

Each issue must have a way to copy the full finding, including its revision-specific file paths and start/end lines, ratings, before/after code, explanation, reproduction, evidence limits, agent count, and my comment if any.

Give me the full path to the html file once done. 
