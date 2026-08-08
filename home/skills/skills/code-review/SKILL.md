---
name: code-review
description: Deep code review of either the last commit or all commits on the current branch vs main/master. Walks commits oldest→newest, builds before/after understanding, then hunts bugs, regressions, logic gaps, and security issues. Use only when explicitely asked by the user.
---

# Code Review

Goal: understand what changed and why, then find what's wrong.

Bugs hide in the gap between what the author *thought* they changed and what they *actually* changed. A flat diff shows the second; Phase 1 reconstructs the first.

## Scope

- "last commit" / "HEAD" → `HEAD` only
- "branch" / "my changes" / "PR" / unspecified → branch vs `main` (fallback `master`)

If ambiguous, ask once. Otherwise pick and state in one line.

## Phase 1 — Understand

Do this fully before Phase 2. Skipping = shallow review.

### 1a. List commits oldest → newest

Oldest first: each commit builds on the previous, same as authored.

### 1b. Per commit

1. Read the message + full diff
2. For each non-trivial hunk, read the post-commit file — trace one level out (callers, inputs, return usage)
3. Read the pre-commit file
4. Hold both: what was the code's job before? now? what's intended? what's incidental?

The diff hides context. Bugs live in the interaction between changed and unchanged lines.

If a commit spans many concerns, group hunks (e.g. "auth changes", "the rename") and walk each.

### 1c. Synthesize (do not skip)

Answer these before Phase 2:

1. **Before** — what did the system do?
2. **After** — what does it do now?
3. **Intent** — what was the author trying to do? (verify against code; messages lie)
4. **Drift** — what changed *outside* the stated intent?

Drift is the highest-yield place to look. "Fix login redirect" + an `||` quietly flipped to `&&` = the bug.

## Phase 2 — Find issues

**Review the final state only.** Phase 1's per-commit walk was for understanding intent and drift. Findings are about the code as it stands at `HEAD` vs the base — not about intermediate commits.

A bug introduced in commit 2 and fixed in commit 5 is not a finding. The author already fixed it. Flagging it wastes the user's time and signals you reviewed history instead of code.

For each finding, verify it still exists in the final state before writing it up. Walk the changes adversarially using these lenses (prompts to think, not checklists):

**Logic** — boundaries (empty, zero, negative, off-by-one), null/undefined, error paths (swallowed, wrong type, logged-not-handled), concurrency (races, await placement), type coercion, resource lifecycle, refactor drift.

**Regressions** (highest-value — what before/after is *for*) — dropped branch/case, changed default, reordered ops (validate-then-effect → effect-then-validate), inputs that used to work, guard clauses "simplified" away.

**Security** — untrusted input → SQL/shell/eval/deserialize/path/URL/regex; auth checks skipped or moved below data fetch; secrets logged or returned; weak crypto, hardcoded keys, predictable randomness; SSRF, XXE, path traversal, open redirect; permissions on new resources.

**Logic gaps** — happy path only, TODO/FIXME left in, caller assumes invariant new code doesn't guarantee, tests passing for the wrong reason.

If a change is fine, say nothing.

## Output

Inline markdown. Concise. Fragments fine. No preamble, no closing summary.

````
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

**Fix:**
```<lang>
<code>
```
**Why:** <invariant restored>
```
````

**Before** = state at the base (or `(new code)` if didn't exist). **After** = state at `HEAD`. Not intermediate commits.

Nothing wrong → say so in one line. Don't invent.

Uncertain → `(low confidence: <why>)`. Don't drop, don't overstate.

### Good finding

````
### 1. Empty cart bypasses minimum order check — bug
**Where:** `checkout/validate.ts:42` (at `HEAD`)

**Before:**
```ts
if (cart.items.length > 0 && total < MIN_ORDER) throw new MinOrderError();
```

**After:**
```ts
if (total < MIN_ORDER) throw new MinOrderError();
```

**Issue:** Empty cart hits `MIN_ORDER` check (total=0), throws `MinOrderError` instead of the empty-cart branch downstream. Fresh checkout shows "minimum order is $20".

**Fix:** restore the `cart.items.length > 0 &&` guard.
**Why:** the simplification dropped a non-redundant short-circuit.
````

Names the trigger, shows the one-line behavior change, fix is minimal, "why" explains the lost invariant.

### Bad finding

```
### 1. Possible issue in checkout
**Issue:** Validation was simplified, might cause edge case problems.
**Fix:** Consider adding more checks.
```

No trigger, no line, no before/after, hedge-speak, fake fix. Vague findings waste time — worse than no finding.

## Style

- Backticks on every identifier, path, value
- "Issue" names a trigger ("fails on empty list"), not a vibe ("may fail in cases")
- "Fix" must compile. If broader changes needed, say so: "fix requires changes to caller in `X.ts`; sketch:"
- No emoji, no congratulations, no "looks good overall"

## Don't flag

- Style, formatting, naming
- Generic "add tests" — only if absence enables a specific bug; name the test
- Restating the diff — the user already has it
- Commit message wording

## Gotchas

**"Looks simple, skip Phase 1"** — simple-looking diffs are where regressions hide. Always do pre/post.

**Diff-only reading** — bug is usually in the interaction between changed and unchanged lines. Pull the whole containing function.

**Trusting commit messages** — they state intent, not behavior. Read diff *against* message; divergence = drift = flag it.

**Newest-first** — later commits fix earlier ones; you'll flag already-fixed issues. Always oldest → newest.

**Flagging issues from intermediate commits** — Phase 1 walks per-commit to understand *intent*. Findings are about the *final state* (base vs `HEAD`). A bug introduced in commit 2 and fixed in commit 5 doesn't exist anymore. Before writing any finding: verify it's still present at `HEAD`.

**"Different" ≠ "wrong"** — before flagging, name the input that produces wrong behavior. Can't? Not a bug.

**Padding** — "looks good overall", "you might consider…". Friction. If nothing's wrong, one line.

**Inventing findings** — a skill that always finds something fabricates. Trust the empty review.

**Stopping early** — finish the Phase 2 walk before writing up.

**Silently reviewing huge scopes** — 50+ commits or 5000+ lines: tell the user, offer full-walk-on-subset vs shallow-walk-on-all. Don't fake depth.
