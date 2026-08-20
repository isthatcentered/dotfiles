---
name: adversarial-refactor-audit
description: Orchestrate a multi-agent change audit following a refactor
disable-model-invocation: true
---

You are the orchestrator of an adversarial code audit. 

Spin up 2 codex high using the $spin-up-codex and 1 claude opus high using the $spin-up-claude iwith the following prompt:

The user might have given you an exception (a change in behavior done during the behavior), if that's the case, add it to the prompt in {{exceptions}} otherwise, replace it with "None".

Do not use the code-review skill, this is not a code review, this is an audit to verify that each piece of code changed maintains the previous behavior.

<Prompt>
Audit each commit made on this branch, this is a refactor only, the behavior before and after the changes on this branch shoudld be the exact same.

The known exceptions are: {{exceptions}}

Your goal is to verify this is actually the case.

For every change in behavior that you find, present it the following way:
<Template>
## Scope
<commit(s), base>


## What changed
<3–8 bullets, before → after, intent terms — not a diff readout>


## Findings

### 1. <title> — [severity: <low|medium|high, the impact on the users if this was to happen>, likeliness: <low|medium|high, the likeliness this issue actually happens> 


**Where:** `path:LINE` (at `HEAD`)

**Before:**
```<lang>
<minimal snippet of the code before the change>
```

**After:**
```<lang>
<minimal snippet of the code after the change>
```

**Issue:** <triggering condition. concrete.>
</Template>

Write your findings to a temporary os file and give me the path.
</Prompt>

Collect all the findings. De-duplicate them (if a finding has been surfaced by mutltiple agents, only keep one version of the finding).

For each finding in the list, add how many agents surfaced the finding.

Then, create an html report, editorial style in .agents/audit/{timestamp}. I must be able to mark the findings as done/rejected.

When a finding is done/rejected, it moves to another list at the bottom.

For each finding, i should be able to display the full file with syntax highlighting on a sidebar on the right so that i can see both the finding and the code side by side.

I must be able to comment on an issue.

Each issue must have a way to copy the issue (file, line and issue, my comment if any).

Give me the full os path (not path from repo root) to the html file once done so that i can just click on it to open it from the terminal.
