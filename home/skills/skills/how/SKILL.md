---
name: how
description: "Answer code questions by searching local reference repositories and library documentation. Use whenever the user asks how to do X in library/framework/language Y — including phrasings like 'how to X in Y', 'how does X work in Y', 'how would I...', 'show me an example of X in Y', 'what's the pattern for X in Y', or 'best way to do X in Y'. Searches real codebases for battle-tested patterns, so prefer it over answering from memory."
---

# how

Answer code questions by combining local reference repositories with Context7 library docs. Grounding in both avoids hallucinated APIs and outdated patterns.

## Workflow

### 1. Parse the question

Extract the **task** (what to accomplish) and the **library** (which ecosystem). If either is ambiguous, ask before proceeding.

### 2. Run both searches in parallel

Spawn two subagents at once.

**Subagent A — Local references:**
```
Search ~/Test/.references for code examples.

1. List directories to see available repos.
2. Pick repos relevant to "{library}" (check names, package.json, etc).
   If none, respond exactly: "NO_LOCAL_REPO: No local reference repository found for {library}"
3. grep/ripgrep for "{task}" patterns across *.ts/tsx/js/jsx/...; 
   Look for real usage, not just imports or types.
4. Report: which repo(s), code snippets with file paths, a brief note on the pattern, and any variations seen.
```

**Subagent B — Context7 docs:**
```
Look up "{task}" in "{library}" via Context7.

1. resolve-library-id for "{library}".
2. get-library-docs with that ID, topic "{task}".
3. Report: doc excerpts, official examples, key signatures/options, caveats.
   If unavailable, respond: "CONTEXT7_UNAVAILABLE: Could not fetch documentation via Context7 for {library}"
```

### 3. Synthesize

If more than one valid approach exists (local and docs differ, or the sources show several patterns), present each one as a labeled option with its own code example and a note on when to use it and what it trades off — then let the user choose. Don't silently pick one. Only collapse to a single answer when there's genuinely one reasonable way to do it.

- **Both sources:** Lead with a concise how-to. Surface every distinct approach found across the local code and docs as separate options. For each, show the example (prefer the local one if clean, supplement with docs for API details) and name the source repo.
- **Context7 only:** Say "I don't have a local reference repository for {library}, so this is docs-only." Present each documented approach. Suggest adding a reference repo.
- **Local only:** Present each pattern found in the code; note you couldn't cross-check docs; flag if unsure any is current best practice.
- **Neither:** Say so. Offer a general-knowledge answer with an "unverified" caveat.

### Formatting

One-sentence summary, then a complete runnable example per approach with brief inline comments for non-obvious parts. End with gotchas. Keep simple single-approach answers short.
