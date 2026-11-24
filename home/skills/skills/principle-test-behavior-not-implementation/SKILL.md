---
name: principle-test-behavior-not-implementation
description: Use when invoked by the user
disable-model-invocation: true
---

# Test Behavior, Not Implementation

Tests should prove the application does what the business expects, not how the code happens to do it. A test should fail only when a business rule breaks, never because the internals were reworked.

Any function that carries a business rule can be a unit under test, including one used only inside its module. Test only what is observable from outside the unit under test: what it accepts, what it returns, and the effects it has on the world beyond itself. Everything that happens inside it is private and must not be asserted on. 

Drive the code through its public interface. Derive the expected value from the requirements, never from the code under test.

Judge each test against two imagined edits:
- **Break the behavior**. If the test still passes, it proves nothing. 
- **Change the internals** and keep every observable result. If the test fails, it is pinned to the implementation.

Keep a test that catches the first edit and survives the second. Rewrite or delete the rest. 




