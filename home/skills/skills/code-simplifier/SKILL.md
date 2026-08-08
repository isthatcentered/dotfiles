---
name: code-simplifier
description: Simplify code by removing low-value abstractions, inlining needless helpers, and reducing indirection while preserving behavior. Do not use unless specifically asked by the user.
disable-model-invocation: true
---

# Code Simplifier

Simplify the code in front of you. Prefer direct, type-safe, local code over abstractions that force readers to jump around without gaining behavior, policy, or domain meaning.

## Core rule

An abstraction earns its place only if it does at least one of these:

- Encodes business meaning or a domain scenario.
- Enforces an invariant or validation not already enforced by a called constructor/API.
- Hides a real decision, branch, policy, side effect, error translation, or resource boundary.
- Is reused enough that changing one real concept in one place is valuable.
- Provides a necessary seam with multiple implementations or an explicit boundary.

If none apply, inline it.

## Workflow

1. **Read the target code and its direct dependencies**
   - Follow imports for constructors, entity factories, test helpers, and framework APIs used by the target.
   - Check call sites with `rg` before removing helpers.
   - Preserve behavior; simplification is not a feature change.

2. **Find abstraction burden**
   Flag helpers/wrappers that make the reader jump away only to discover type-safe scaffolding:
   - Single-use helpers whose body is obvious at the call site.
   - Wrappers around exposed entity constructors/factories, e.g. `newEvent()` that only calls `NewEvent.random(...)` with generic defaults.
   - Test harness interfaces or objects with one implementation and no interchangeable behavior.
   - Framework plumbing helpers that have no decision or domain meaning, e.g. wrapping a stream/effect collection pipeline just to hide the API call.
   - Builders/fixtures whose name does not encode a business scenario and whose defaults are not meaningful to the test.
   - Constants, options objects, or type aliases used once where the literal/API call is clearer.

3. **Inline safely**
   - Replace the helper call with the underlying constructor/API call at each call site.
   - Use constructors/factories exposed by entities directly; they are already the type-safe boundary.
   - Remove now-unused helpers, interfaces, imports, and types.
   - Keep named scenario fixtures only when the name communicates behavior the raw constructor call would not.

4. **Validate**
   - Run the smallest relevant test/typecheck/formatter available.
   - If working in the watchtower repo, run `gate run --configuration iteration.gate.json` after changes.

## Do not simplify

Do not remove an abstraction if it:

- Adds validation, normalization, error mapping, logging, metrics, tracing, retries, transactions, locking, or cleanup.
- Names a domain scenario in a test, e.g. `expiredSubscription()` or `accountAtCreditLimit()`.
- Is a public API, adapter boundary, dependency injection seam, or has multiple real implementations.
- Shields callers from unstable third-party APIs.
- Makes a complex expression readable by naming a non-obvious intent.

## Output

When editing, summarize:

- What abstractions were removed.
- What calls were inlined.
- What validation was run.

When only reviewing, report numbered findings with `path:line`, current code, suggested inline replacement, and why the abstraction does not earn its keep.
