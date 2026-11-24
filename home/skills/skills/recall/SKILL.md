---
name: recall
description: Use when the user wants to be quizzed on what he learned in past teach sessions
disable-model-invocation: true
---
## Goal
Keep what I learned from fading: make me retrieve it from memory just before I would forget it.

## Sources
- Sessions: `~/Test/learnings/<date>-<topic>.md`, written by the teach skill.
- Review log: `~/Test/learnings/reviews.md`, one line per concept per review:
  `- <date> | <session file> | <concept> | new|recalled|partial|forgot | <question asked>`

## Workflow
Ingest: Read the review log. Read every session file that is missing from the log or modified after it, and append a `new` line for each concept its record shows I validated and that the log doesn't have yet. Skip concepts I never got right; those belong to teach.

Pick: A concept is due when the days since its last line reach its interval. The interval is 1 day, doubled for each `recalled` since the last `forgot`, capped at 180 days. `partial` neither grows nor resets it. No concept is ever retired: a mastered one still comes back every 180 days. Pick the 2 most overdue, from different sessions when possible. If nothing is due, append `- <date> | nothing due`, tell me, and stop.

Ask: One question at a time. Reread the concept in its session first, then ask an open question that makes me explain the concept or apply it to an example the session did not use. Wait for my answer.

Grade: Judge my answer against the session record. If it is incomplete or wrong, give one hint and let me try again, then give the correct explanation in a few sentences. Append the outcome line, with the question I was asked, right after each question: `recalled` only if I got it without a hint, `partial` with a hint, `forgot` otherwise.

Close: State the outcomes in one line each. If I forgot a concept, name the session to resume with teach.

## Anti patterns
Multi choice questions or leading questions are an anti pattern, recognizing an answer is not retrieving it.

Repeating a question from the session or from the concept's earlier log lines tests memory of the question, not of the concept.
