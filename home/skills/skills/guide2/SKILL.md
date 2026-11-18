---
name: guide2
description: Use when creating or updating an existing guide
---
Guides live in .agents/guides.
Maintain the index at .agents/guides/README.md.

Do not modify a guide without the user's explicit approval or request.
If guidance conflicts, explain the conflict and ask the human.
Do not invent precedence.

## Writing principles

- Organize around principles, not lists of instructions.
- A principle must help choose between competing approaches.
  Avoid slogans that could justify any decision.
- Explain why it matters: the outcome protected and failure prevented.
- Derive concrete practices from the principle.
- Prefer minimal snippets, diagrams, and decision tables.
- Distinguish required constraints from preferred implementations.
- Keep rationale, practices, and exceptions together.
- Link to canonical guidance rather than duplicating it.
- $beconcise

## Guide template

<template>
# <Topic>

Use when: <scope>.
Goal: <desired outcome>.

## Principle: <a short, actionable statement>

Goal: <Why it is important to follow that principle, what this protects, what goes wrong without it,
and any relevant trade-off>.

### Apply it

| Situation | Practice | Reason |
|---|---|---|
| <recognizable context> | <concrete action> | <connection to principle> |

### Pattern

<snippet(s), diagram(s), or before → after.>
<Identify essential details versus illustrative choices.>

### Boundaries and exceptions

- Must preserve: <non-negotiable constraints>.
- May vary: <implementation choices>.
- Known exception: <condition → alternative → why it serves the goal>.
  Omit if none are known.

### When the example does not fit

<Explain which facts determine the choice.
Adapt the practice while preserving the principle and required constraints.
Ask when principles conflict without an established priority,
or a required constraint would need to change.>

### Check

<Observable evidence that the principle is satisfied,
not merely that the example was copied.>
</template>

## Before finishing

- Does each principle explain a meaningful choice?
- Do its practices visibly follow from its rationale?
- Can a consumer handle a new case without inventing policy?
- Can prose be replaced by a clearer snippet or diagram? If yes, fix it

The important shift:

Rule-first:       Do X → here is why → exceptions
Principle-first:  Protect Y → in this situation, do X → adapt within these limits

