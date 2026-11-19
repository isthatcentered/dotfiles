---
name: principle-lean-by-design
description: Use when invoked by the user
disable-model-invocation: true
---
# Lean by design

Maintenance burden comes from interfaces that expose unnecessary options, permit invalid states, or leak internals; from inconsistent behavior; from behavior not visible at the call site; and from unused features. 

We strive for simplification.

Design for observed usage, not speculative edge cases: build only what's needed, behind the smallest interface that can express it. Handle the common scenarios, plus rare failures whose impact is application-wide or irreversible. Everything else — unsupported use and unhandled failures alike — must fail loudly.

