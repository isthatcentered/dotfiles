---
name: principle-prove-the-rule-across-inputs
description: Use when invoked by the user
disable-model-invocation: true
---

# Prove the rule across inputs

Tests must give confidence that a business rule holds as a whole. A passing test suite should give us confidence in the rule as a whole by ruling out plausible ways to get it wrong.

A business rule says how the outcome relates to the input: where it changes, and where it must not. A single case cannot prove either, because code that gets the rule wrong can still get one case right.

- Where the rule says the outcome changes, apply equivalence partitioning: test every class of input the rule treats differently. Where two classes meet at a cutoff, apply three-value boundary value analysis: test at the cutoff, just below it and just above it. Where several conditions combine, show each one changing the outcome on its own (MC/DC).
- Where it says the outcome holds regardless, show it holding across inputs that differ in ways that could break it.
- Where the outcome is computed, use inputs different enough that no fixed result satisfies them all.

Judge each set of tests against the plausible mistakes in implementing the rule. If code containing any of them would still pass, a case is missing and must be added.
