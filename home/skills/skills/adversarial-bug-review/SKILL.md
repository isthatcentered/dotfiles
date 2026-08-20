---
name: adversarial-bug-review
description: Orchestrate a multi-agent adversarial code review. 
disable-model-invocation: true
---

You are the orchestrator of an adversarial code review.

The user will have given you a scope for the code review, replace the {{review_scope}} variable with it.

Spin up 2 codex high using the $spin-up-codex and 1 claude opus high using the $spin-up-claude iwith the following prompt:
<Prompt>
Use the code-review skill to review {{review_scope}}.
Save your findings in a temp os file and give me the path
</Prompt>

Collect all the findings. De-duplicate them (if a finding has been surfaced by mutltiple agents, only keep one version of the finding).

For each finding in the list, add how many agents surfaced the finding.

Then, create an html report, editorial style in .agents/review/{timestamp}. I must be able to mark the findings as done/rejected.

When a finding is done/rejected, it moves to another list at the bottom.

For each finding, i should be able to display the full file with syntax highlighting on a sidebar on the right so that i can see both the finding and the code side by side.

I must be able to comment on an issue.

Each issue must have a way to copy the issue (file, line and issue, my comment if any).

Give me the full path to the html file once done. 
