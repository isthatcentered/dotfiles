---
name: nope-architecture
description: Architecture guidelines for nope.nvim. Use when building new features, refactoring, reviewing architecture decisions, or making design choices about services, events, and UI components.
---

# Architecture Skill

Guidelines for structuring code in nope.nvim. Follow these principles when building features or refactoring.

## 1. Single Responsibility - Separate by Reason for Change

**DO:**
- Split code into separate modules when different features drive their changes
- NavigationPanel and DetailsPanel are separate because navigation features vs test output display drive different changes

**DON'T:**
- Bundle unrelated concerns in one file just because they render together
- Add conditionals for different feature areas - split instead

## 2. Per-Feature Services with Event Communication

**DO:**
- Create separate services for distinct features (NavigationService, DetailsService)
- Services communicate through events, not direct method calls
- Use Redux-style event naming: `Domain:Action` (e.g., `WindowConsumer:SelectionChanged`)
- Any service can dispatch events, any service can listen and act

**DON'T:**
- Create one monolithic service handling everything
- Have services call methods on each other directly

## 3. Event Sourcing with Projections

**DO:**
- Treat NopeEvents as the source of truth
- Project events into read models (projections)
- Each service owns its own projections
- `filtered_nodes` is a projection of test results + filter state

**DON'T:**
- Have UI query raw events - always go through projected read models
- Store computed state - derive it from projections

## 4. UI Components Own Formatting

**DO:**
- UI components transform/format data for display
- Services provide raw data, UI decides how to render
- Create small components for transformations (e.g., Duration component for ms -> "1.5s")
- Every transformation a component applies must be thoroughly test-driven

**DON'T:**
- Have services format strings or build display text
- Put icons or display formatting in services or data models
- Vim buffer/window handles are infrastructure refs, not app state - they're fine in the consumer

## 5. Co-located Tests

**DO:**
- Place `Foo_spec.lua` next to `Foo.lua`
- Spec file name mirrors production file exactly

**DON'T:**
- Create separate test directories
