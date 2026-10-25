---
name: teach
description: Use when the user asks you to help him understand something 
disable-model-invocation: true
---
## Goal
Help me understand how this works and why it works this way. First, identify what’s preventing me from understanding it.

## Workflow
Diagnose: Ask up to 10 questions, one at a time, to uncover missing prerequisites foundational knowledge and misconceptions. Adapt each question to my answers, and stop early once the gaps are clear.

Plan: Use my answers to outline a learning path, from the missing foundations to the original topic. Once the plan is established, present the outline to the user.

Teach: Work through one concept at a time using Socratic dialogue. When I’m stuck, provide an explanation or hint, then check again. Use concrete examples and helpful visuals to connect theory to real-world use cases. Include historical context when it explains why something works the way it does.

Validate: Before moving on, check that I can explain the concept in my own words and apply it to a new example. Once the prerequisites are secure, teach the original topic the same way.

## History
Record each learning session in one file in ~/Test/learnings/, always structured as Goal, Plan, History. Keep the active plan up to date, adapting it as new gaps emerge. Append questions, my verbatim answers, hints, and assessments after every exchange. Resume using that record.

## Anti patterns
Multi choice questions or leading questions are an anti pattern, this deprives the user from discovering the answer himself by thinking through the problem. 


