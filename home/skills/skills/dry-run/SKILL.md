---
name: dry-run
description: Stress-test an implementation plan before writing any code. Use this skill whenever you have a plan, design, or set of steps for a code change and want to validate it first — catch missing edge cases, ambiguous requirements, undiscovered dependencies, or steps that will break at implementation time. Trigger this skill when the user says things like "dry run this plan", "sanity check before I implement", "simulate the implementation", "what could go wrong with this approach", "poke holes in this plan", "validate this design", or any time someone has laid out how they intend to change code and wants confidence the plan is solid before committing to it. Also trigger when the user has just finished planning with you and asks you to verify or review the plan before moving forward.
disable-model-invocation: true
---

# Dry Run

Surface implementation problems before they happen.

## Why this exists

Writing code from a flawed plan is expensive — you discover issues mid-implementation, have to backtrack, re-think dependencies, and sometimes throw away real work. A dry run catches these problems while the cost of fixing them is just *editing a plan*, not *rewriting code*.

The goal is simple: mentally walk through every step of the plan as if you were actually implementing it, and report back anything that doesn't hold up.

## When to use this

Any time there's an implementation plan that's about to be executed. The plan might be:

- A set of steps you and the user just worked out together
- A design doc or technical spec
- A task breakdown from an issue tracker
- A refactoring strategy
- A migration plan

The plan doesn't need to be formal — even a rough outline of "here's what I'm going to do" qualifies.

## How it works

Pass the full implementation plan to a subagent. The subagent's job is to simulate carrying out the plan step by step — reading the relevant files, tracing through the logic, checking types and interfaces — and surface anything that would cause trouble during real implementation.

### What to hand the subagent

Give the subagent:

1. **The complete plan** — every step, in order, with as much context as the user provided.
2. **The goal** — what the plan is trying to achieve, so the subagent can judge whether the steps actually get there.
3. **Access to the codebase** — the subagent needs to read the actual files involved, not work from memory. Real file contents reveal real problems.

### What the subagent should look for

The subagent should walk through the plan as if implementing it, and flag:

- **Missing steps** — things the plan assumes will "just work" but actually require explicit handling.
- **Wrong assumptions** — the plan references a function signature, data shape, config option, or API that doesn't match what's actually in the code.
- **Ordering problems** — steps that depend on something that hasn't happened yet, or that would break an intermediate state.
- **Unhandled edge cases** — error paths, empty states, concurrent access, null values, type mismatches — anything the plan doesn't account for.
- **Unclear or ambiguous steps** — places where the plan says "update the handler" but there are three handlers and it's not obvious which one, or where a step could be interpreted multiple ways.
- **Dependency issues** — imports, packages, services, or infrastructure the plan relies on but doesn't mention setting up.
- **Scope creep risks** — steps that sound simple but, once you look at the actual code, involve touching many more files or systems than expected.
- **Things that will break** — existing tests, downstream consumers, type contracts, or integrations that the plan's changes would violate.

### What makes a finding valuable

The whole point of this skill is to catch things a human would miss by just reading the plan. That means the subagent's value comes from actually engaging with the codebase — tracing the real code paths the plan touches, checking what functions actually accept and return, reading the tests that exist today.

A finding like "you should handle errors in this step" is worthless. Everyone knows they should handle errors. A finding like "step 3 calls `processOrder()` which throws `InsufficientInventoryError`, but the plan doesn't account for that — and the caller in `checkout.ts:47` has no try/catch around it" changes someone's plan.

The bar for every finding: **would this cause the implementer to stop and rethink?** If the answer is no, it's not worth including. A short report with three grounded findings beats a long one with ten vague observations. The subagent should prefer silence over noise — if a section of the plan checks out, move on. Don't pad the report with "this looks fine" commentary.

### What the subagent should produce

A clear report organized by severity:

- **Blockers** — things that will definitely prevent the plan from working as written. These need to be resolved before implementation.
- **Risks** — things that might cause problems depending on context the subagent couldn't fully verify. Worth investigating.
- **Questions** — ambiguities or missing details where the subagent couldn't determine the right path without more information from the user.
- **Suggestions** — optional improvements the subagent noticed while walking through the plan. Not blockers, just ideas.

For each item, the subagent should explain *what* the problem is, *where* in the plan it occurs, and *why* it matters. Reference specific files and line numbers when possible.

If the plan looks solid and the subagent finds no issues, it should say so — a clean bill of health is a useful result too.

## After the dry run

Present the subagent's findings to the user.

If the report is clean — no blockers, no open questions — you're done. The plan is validated and ready for implementation.

If the report surfaces blockers, risks, or open questions, don't just dump them on the user and wait. Use the `$grill-me` skill to systematically work through each issue. The dry run identified *what* needs answering; grill-me is how you actually get those answers resolved before anyone writes a line of code.

Once all issues from the dry run have been addressed through grill-me, update the plan to reflect the resolutions and confirm the revised plan with the user before moving to implementation.
