---
name: describe-changes
description: Use when writing a PR body
---
## PR description
 Write the PR description for a reviewer who has not followed the work.
Connect the goal, implementation, and resulting behavior.

Use this template for the PR body:
<template>
## Goal

## Change stack

## Techincal approach

## User impact

## Merge danger

</template>

1. **Goal:** What this PR as a whole achieves (bullet points)
2. **Change stacks**: Group commits by logical change; for each group, explain the overall purpose and resulting behavior, then present the changes using the $show-me skill.
3. **Technical approach:** Explain how the solution works and why the key
   changes address the problem. Describe the relevant components and their
   interactions rather than listing changed files. Include mermaid diagrams when
   they clarify changes to the architecture/data flow/interactions. Use the $bro skill for that.
4. **User impact:** Explain what users experience differently using the $bro skill. Where behavior
   changes, give an example before and after the PR.
   Explicitly state when there is no user-visible change.
5. **Merge danger:**

Keep simple PRs brief; expand only where the explanation helps review.

Be precise but concise.

Do not add information about the validation checks run.


