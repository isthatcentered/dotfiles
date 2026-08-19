---
name: create-task
description: Create a work task.
disable-model-invocation: true
---
This skill takes the current conversation context and codebase understanding and produces a spec. Do NOT interview the user — just synthesize what you already know.

The issue tracker and triage label vocabulary should have been provided to you — run `/setup-matt-pocock-skills` if not.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Write the spec using the template below, then publish it to the project issue tracker. Apply the `ready-for-agent` triage label - no need for additional triage.

## Template

<Template>
## Goal
What we want to do and why from the user's perspective.

## The solution
The shared understanding of the work to do, reached after discussing with the user.

## Architecture
### Contracts
The function signatures/interfaces/types that will be impacted by the change. Presented per file as a diff, including, for each function, the list of existing tests if any and the expected list of tests after the change. 

This presents only the interfaces, not the implementation.

### Call stack
A call stack presenting the relationship between functions to fulfill the task.

<Example>
Raw HTTP request
  Context<HonoEnv>
  context.req.raw.body: ReadableStream<Uint8Array> | null
    → receivePack(context, transport)
      if body null → Response 400
      → withGitProtocolTimeout(callback, 60_000, 'receive_pack')
        callback(signal)
          → abortableRequestBody(body, signal)
          → decodeRequestBody(abortableBody, headers)
          → peelFlushOnlyProbe(decodedBody)
            'flushOnlyProbe' → toStream(0000)
            stream → GitWriteTransport.receivePack(stream)
              → DurableObjectStub<GitServer>.handleReceivePackWithRefUpdates(stream)
                → beginQuarantine('receive-pack')
                → WasmBridge.handleReceivePackStreaming(stream, { quarantineId })
                  → runWithQuarantine(qid, ingest)
                    → reader.read()*
                    → handle_receive_pack_streaming_feed*
                    → handle_receive_pack_streaming_finish
                    → handle_receive_pack_streaming_updates
                → publishQuarantine(qid, updates, metadata)
                → deleteQuarantine(qid, metadata)
                → ReceivePackPublicationResult
              → analytics + push events if published
              → ReadableStream<Uint8Array>
      → packResultResponse('git-receive-pack', result)
</Example>

## Implementation decisions
A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

## QA plan
A gherkin based list of tests that will be run to validate the work is correct.

## Documentation
The paths/urls/... given by the user as additional reference if any.

## Out of Scope
A description of the things that are out of scope for this spec.

## Further Notes
Any further notes about the feature.

## Conversation history 
The convesation history with the user that led to the shared understanding. As is.

<Example>
Question: What should we do when ...
Answer: We must ...
</Example>

</Template>
