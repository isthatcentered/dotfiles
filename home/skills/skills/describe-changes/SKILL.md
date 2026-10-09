---
name: describe-changes
description: Use when writing a PR body
---
 Write the PR description for a reviewer who has not followed the work.
Connect the goal, implementation, and resulting behavior.

Use this template for the PR body:
<template>
## Goal

## Change stack

## Techincal approach

## User impact

## Merge danger
**Door:** <one-way or two-way>

<optional: description>

**Blast Radius:** <one-word description>

<optional: potential ramifications of merge>
</template>


## Goal
What this PR as a whole achieves (bullet points)

## Change stack
Group commits by logical change; for each group, explain the overall purpose and resulting behavior, then present the changes using the $show-me skill.

## Techincal approach
Explain how the solution works and why the key
   changes address the problem. Describe the relevant components and their
   interactions rather than listing changed files. Include mermaid diagrams when
   they clarify changes to the architecture/data flow/interactions. Use the $bro skill for that.

## User impact
Explain what users experience differently using the $bro skill. Where behavior
   changes, give an example before and after the PR.
   Explicitly state when there is no user-visible change.

## Merge danger
Describe whether it's a one-way or two-way door. You can walk back through two-way doors, but not one-way doors. A PR that is cheap to roll back is lower risk. Changes that involve destructive actions or hard-to-reverse decisions are one-way doors.

The blast radius is the potential impact or scope of the changes introduced by this PR. Consider all possibilities. Examples are layout shift, breakages for consumers, mobile responsiveness, etc.

## Guidelines
Keep simple PRs brief; expand only where the explanation helps review.

Be precise but concise.

Do not add information about the validation checks run.
