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
</template>


## Goal
What this PR as a whole achieves (bullet points)

## Change stack
Group commits by logical change; for each group, explain the overall purpose and resulting behavior, then present the changes using the $show-me skill.

## Techincal approach
$show-me the changes

## User impact
Explain what users experience differently using the $bro skill. Where behavior changes, give an example before and after the PR. 
Present the changes as a list of bullet points in a diff where each bullet point is a behavior. the diff shows the behavior before/after when there is a difference for a behavior.
Explicitly state when there is no user-visible change.

## Guidelines
Keep simple PRs brief; expand only where the explanation helps review.

Be precise but concise.

Do not add information about the validation checks run.
