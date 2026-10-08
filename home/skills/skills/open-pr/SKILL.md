---
name: open-pr
description: Use when writing a PR body
---

## PR description

Write the PR description for a reviewer who has not followed the work.
Connect the goal, implementation, and resulting behavior.

Use these five headings, in this order. Replace the bracketed guidance with
details supported by the actual changes; do not leave placeholders in the PR.

```markdown
## Goal
- [Problem or need, and the outcome this PR achieves.]

## Change stack
1. **[Logical change]:** [Purpose and resulting behavior.]
   [Focused visual showing this change.]

## Technical approach
[How the solution works, why this approach fits, and any meaningful tradeoff.]

## User impact
[Who is affected and a concrete before/after example, or no user-visible change.]

## Merge danger
[Specific failure mode, affected scope, and mitigation or recovery.]
```

### What belongs in each section

1. **Goal — Why does this PR exist?**
   Use bullet points to describe the problem and the outcome of the PR as a
   whole. Explain what becomes possible or what stops going wrong. Keep the
   implementation details in the sections below.

2. **Change stack — What are the logical pieces, and how do they fit together?**
   Group commits by logical change, in dependency order when relevant. For each
   group, explain its purpose and resulting behavior, then use the $show-me skill
   for a focused diff, call tree, pseudocode, or diagram. One group is enough for
   a small PR. Mention dependencies between groups when they affect review or
   merge order. Use actual commit references only when available; do not invent
   commits or turn this into a list of changed files.

3. **Technical approach — How does it work, and why this solution?**
   Describe the relevant components, how they interact, and the mechanism that
   addresses the problem. Explain meaningful design choices and tradeoffs, such
   as compatibility, state ownership, or performance, when they apply. Use the
   $bro skill to make the explanation plain and concise. Include Mermaid when
   it clarifies architecture, data flow, or interactions. Avoid repeating the
   change stack or narrating abandoned approaches.

4. **User impact — What will people experience differently?**
   Identify the affected users or workflows and use the $bro skill for plain
   language. For behavior changes, give a concrete trigger and before/after
   example. Mention required user action or compatibility changes when relevant.
   Explicitly state when there is no user-visible change.

5. **Merge danger — What could go wrong when this lands?**
   Describe concrete risks supported by the diff: the failure mode, who or what
   it affects, and how the implementation limits the risk or enables recovery.
   Mention deployment order, migrations, configuration, or rollback limits when
   they matter. For a low-risk change, explain briefly why the affected scope is
   small. Avoid unsupported claims such as "no risk"; state relevant unknowns
   instead of inventing mitigations or rollout guarantees. Do not add a generic
   safety checklist.

Keep simple PRs brief; expand only where the explanation helps review.
Be precise but concise.
Do not add information about the validation checks run.

### Examples

These are fictional PR bodies showing the expected level of detail. Adapt the
structure to the actual diff; do not copy their claims without evidence.

#### Example 1: Bug fix — Preserve a draft when saving fails

````markdown
## Goal
- Prevent a failed save from erasing the user's draft.

## Change stack
1. **Save handling:** Clear the draft after the server confirms the save, so a
   failed request leaves the text available for another attempt.

   ```diff
   on(save)
   -  clearDraft()
      await persistDraft()
   +  clearDraft()
   ```

## Technical approach
The editor keeps its local text while the save request is pending. A successful
response clears it; a rejected request follows the existing error path and
preserves the text. This ties clearing the draft to a completed save.

## User impact
When a save fails because the connection drops, the draft remains in the editor.
Before: the text disappeared and had to be retyped. After: users can retry with
the same text.

## Merge danger
Clearing now happens later. If the editor accepts new text while a save is
pending, that text could be cleared when the request completes; pending-save
editing behavior needs particular review. The request format and stored data
do not change, so reverting requires only an application rollback.
````

#### Example 2: Feature — Export filtered orders as CSV

````markdown
## Goal
- Let users download the orders matching their current filters.

## Change stack
1. **Export endpoint:** Generate a CSV using the same filters and account access
   rules as the orders list. This supplies all matching rows across pages.
2. **Export action:** Add a download button that passes the active filters to
   the new endpoint. This depends on the endpoint being available.

   ```text
   clickExport(activeFilters)
     requestCsv(activeFilters)
       authorizeAccount()
       queryMatchingOrders()
       streamCsv()
   ```

## Technical approach
The list and export share filter parsing and account scoping so the download
matches the selected view. The endpoint streams rows instead of building the
whole file in memory. This limits memory use, but large exports still occupy a
database connection for longer.

## User impact
An account owner filters orders to September and clicks Export. Before: they
copied rows from each page. After: they download one CSV containing all matching
orders, including those beyond the current page.

## Merge danger
Large exports can increase database load. Streaming limits application memory
use, but it does not reduce query cost. Deploy the endpoint before the button;
an older server cannot serve the download. Removing the button stops new exports
without changing stored orders.
````

#### Example 3: Refactor — Centralize retry decisions

````markdown
## Goal
- Give HTTP and queue workers one place to maintain retry decisions while
  preserving their current behavior.

## Change stack
1. **Shared retry policy:** Extract the existing attempt limit and delay rules
   into one helper, then make both workers call it.

   ```text
   HTTP worker  -> retryPolicy(attempt, error) -> retry or stop
   Queue worker -> retryPolicy(attempt, error) -> retry or stop
   ```

## Technical approach
The helper returns whether to retry and how long to wait. Each worker still
performs its own scheduling. Keeping scheduling with the caller allows both
workers to share decisions without coupling their execution loops.

## User impact
No user-visible change. Failed operations keep the same retry limit, delays,
and final error behavior.

## Merge danger
A mistake in the shared helper would affect both workers, expanding the scope
of future policy changes. This extraction preserves each existing decision rule
and introduces no stored data or configuration changes. Reverting restores the
separate implementations without a migration.
````

#### Example 4: Migration — Store account time zones

````markdown
## Goal
- Show scheduled report times in each account's chosen time zone.

## Change stack
1. **Schema support:** Add a nullable account time-zone field. Existing accounts
   continue using UTC until they choose a value.
2. **Settings and display:** Save the selected zone and use it when formatting
   report times. This depends on the schema change landing first.

   ```text
   Account settings -> accounts.time_zone
   Report timestamp + accounts.time_zone (or UTC) -> displayed local time
   ```

## Technical approach
Report timestamps remain stored in UTC. The settings API accepts supported
time-zone names, and the display layer uses the account's zone when formatting
them. Keeping UTC storage preserves scheduling behavior while allowing local
display, including daylight-saving changes.

## User impact
An account selects Europe/Paris. Before: a January report scheduled for 09:00 UTC
appeared as 09:00. After: it appears as 10:00 in the account's local time. Accounts
that have not selected a zone continue seeing UTC.

## Merge danger
Deploy the added column before application code that reads it; reversing that
order makes account queries fail. A missing value falls back to UTC. Application
rollback can leave the nullable column in place, but it restores UTC display.
Dropping the column would lose saved preferences, so leave it during rollback.
````
