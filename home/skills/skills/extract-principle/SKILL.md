---
name: extract-principle
description: Use when invoked by the user
disable-model-invocation: true
---
Be assertive: must, not should
Start witht the intent

<template>
# {principle_name}

{intent}

{how to verify}
</template>

The user presented you with an issue or a principle. your goal is to clarify it. 

## 1. Understand the intent
What is the goal of this principle
What are the benefits of applying it
What does it look like when applied (before/after)
What are the known exceptions
How to handle exceptions that are not listed
How do you verify that the principle has been faithfully applied

If working in a codebase, proactively find concrete examples and counterexamples of the principle under discussion, and use them to ground the discussion.

## 2. Present to the user
The goal of a principle is to establish a practice/pattern by providing the rational behind it so that when faced with an unknown exception, the user/agent can decide if and how to apply the principle.

- $beconcise /beconcise
- The guide should be snippet/diagrams driven, a diagram/code snippet is speaks a 1000 words
- A principle expresses intent; examples illustrate how to apply it, not prescribe the only way

## 3. Iterate
The user might have feedback. Every time, take the feedback into account then go back to 1 with the new learnings
