---
name: to-spec
description: Turn the current conversation into a spec and publish it to the project issue tracker — no interview, just synthesis of what you've already discussed.
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a spec (you may know this document as a PRD). 

Write the spec using the template below, then publish it to the issue tracker with the `ready-for-agent` label.

Issues and PRDs are tracked locally using the `wp` cli. 

<spec-template>

## Glossary
Domain terms used in this document and their definitions

## Goal
What we want to do and why from the user's perspective. Be precise but concise

## Solution
The shared understanding of the work to do reached after discussing with the user, verbatim. 

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)


## Out of Scope

A description of the things that are out of scope for this spec.

## Documentation

The paths/urls/... given by the user as additional reference, relevant ADRS or guides from .agents/guides if any.

## Further Notes

Any further notes about the feature.

</spec-template>

## Conversation history 
The convesation history with the user that led to the shared understanding. As is.

<Example>
Question: What should we do when ...
Answer: We must ...
</Example>

</Template>
