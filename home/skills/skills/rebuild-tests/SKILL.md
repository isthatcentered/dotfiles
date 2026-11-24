---
name: rebuild-tests
description: Use when invoked by the user
disable-model-invocation: true
---
# Rebuild the tests

The goal is a suite that proves what this code is for, designed from its business rules rather than repaired test by test.

1. Establish the rules. Read everything in scope, and whatever else is needed to understand it. List the business rules it carries, using /principle-test-behavior-not-implementation to decide what is a unit and what is observable. Treat the existing tests as evidence of rules that matter, not as a structure to preserve.
2. Resolve disagreements. The code shows what happens, not what should happen. Where the code, the existing tests and the stated intent disagree, do not pick one silently: apply /principle-escalate-by-impact.
3. State the list of rules you will test, and anything the old suite covered that you are dropping, with the reason.
4. Design the suite from that list, as if no tests had ever existed. For each rule, apply /principle-prove-the-rule-across-inputs, then /principle-pin-the-scenario-randomize-the-noise.
5. Replace the old suite only once the new one passes.

Do not change the code under test. A new test that fails against it is a finding to report, not something to fix on either side.
