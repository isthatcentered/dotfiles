---
name: principle-pin-the-scenario-randomize-the-noise
description: Use when invoked by the user
disable-model-invocation: true
---

# Pin the scenario, randomize the noise

Tests must make obvious what a scenario depends on, and prove that nothing else affects it.

Every test states a property: for any valid setup satisfying its constraints, the behavior holds. Start by generating a valid setup randomly, then pin only the constraints that define the scenario, whether an exact value or a relationship between values. Pinning signals intent. Leaving everything else arbitrary means a hidden dependency cannot last: sooner or later a generated value breaks the test.

A failure on generated data is a counterexample, not flake. It exposes either a bug or a dependency the scenario left implicit. Fix the bug, or pin the dependency once you know why the scenario requires it. Never pin values just to turn the test green.

Judge each test by two checks:
- Everything pinned must be required by the scenario.
- Replacing anything unpinned with another valid alternative must not change the outcome.
