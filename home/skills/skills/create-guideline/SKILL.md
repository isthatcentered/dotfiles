---
name: create-guideline
description: "Turn a code example into a reusable pattern document — a 'lean standard' that codifies how to use a library or how to write something a specific way, saved to the .agents/patterns directory. Do not use unless specifically asked by the user"
disable-model-invocation: true
---

# Create Guideline

Turn a single seed code example into a reusable pattern document — a lean standard saved to
`.agents/patterns/<topic>.md`. The skill is stack-agnostic: the seed example sets the
language, idioms, and conventions.

## Input

Requires **one seed code example** from the user. If none was provided, ask for it before
doing anything else.

## Workflow

Run these stages in order. Two gates are mandatory and must not be skipped: the **outline
must be explicitly accepted** before any examples are produced, and **each synthesized
example must be approved** before moving to the next principle.

### 1. Interview — question-first

Read the seed example closely, then interview the user about what matters. Lead with open
questions; do **not** open with a proposed outline.

- "What about this code do you want everyone to copy?"
- "What would you reject in review if someone did it differently?"
- "Why does this matter — what goes wrong otherwise?"

As the user answers, react with suggestions grounded in what you actually see in the seed:
"I also notice you trim the input / order by date / avoid helper methods here — is that a
rule too?" Surface candidate principles the user didn't name, but never invent rules they
don't endorse.

For each principle that emerges, also draw out two things: the **common mistake** people
make against it (if any), and any **exceptions** where it doesn't apply.

### 2. Outline — iterate to acceptance

Assemble an outline from the answers: an ordered list of principles, each a short title plus
a one-line statement of intent. Show it, take feedback, revise. Continue only once the user
**explicitly accepts** it.

### 3. Per-principle example loop

After the outline is accepted, work through the principles one at a time. For each:

1. **Search** the whole repo (grep/glob) for real instances of the principle, seeded by the
   shape of the example.
2. **Show** the matches you found and confirm with the user that they're representative of
   the pattern. If they're off, search again.
3. **Synthesize** a fresh, clean example that demonstrates the principle. Invent it — see
   *Example rules* below.
4. **Approve** — get the user's sign-off on the synthesized example, then move to the next
   principle.

### 4. Assemble & write

Compose the document (see *Document structure*) and write it to `.agents/patterns/<topic>.md`,
slugifying `<topic>` from the subject (e.g. `backend-testing.md`). Confirm the path with the
user before writing.

## Example rules

- **Synthesized, never lifted.** Real matches are reference material to understand the
  pattern's shape — not content to copy. Always write a fresh example. Never paste or lightly
  edit code from the repo.
- **Generalized.** Strip all business specifics. Use minimal, illustrative, domain-neutral
  names and keep only the fields and steps needed to show the pattern.
- **Positive always.** Show the right way for every principle.
- **Counter-example only when it earns its place.** Add a "don't do this" only where there's
  a real, common mistake worth warning against — not by default.
- **Exceptions where they exist.** Document genuine carve-outs (e.g. "Exception: boundary
  cases may repeat the assert when the repetition is the point").
- **Match the seed's language and idioms.** The input sets the conventions.

## Document structure

Lead each section with the rule and its rationale in prose, then let the example carry the
weight.

```
# <Topic>

<Optional one-line statement of what this guideline governs.>

## <Principle>

<The rule, and why it matters — short prose.>

<positive code example>

<optional counter-example, framed as the wrong way>

<optional documented exception>

## <Next principle>
...
```
