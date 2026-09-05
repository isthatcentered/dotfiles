Consolidate the validated reviewer reports in the supplied input. Return JSON
matching the schema. Keep the supplied runId. Merge only findings with the same
underlying defect, trigger, and consequence; independent defects remain separate.

Preserve the clearest explanation, complementary evidence, reproduction details,
and limits. Resolve severity/likelihood against evidence, preserving uncertainty
and explicit disagreement. Do not infer dissent from a reviewer saying nothing.
Agreement does not increase likelihood. Do not add fixes or invent new findings.

Every raw finding must appear exactly once: as a source of one consolidated
finding, or in excluded with a substantive reason. Sources identify the original
reviewer and findingId. Preserve revision-specific locations and exact excerpts.
Use distinct consolidated finding IDs. Do not make execution-status claims in
whatChanged: completion and failures are supplied separately by the script.

Only inspect the supplied reports and, if necessary, the pinned source revisions
to resolve conflicting evidence. Do not run additional reviewers.

Preserve complementary code views, labeled ranges, structured evidence, supplied
context, and unresolved assumptions from the input findings. Remap source
evidence codeViewId references if merging view IDs. Do not silently upgrade
needs-verification to supported; explain the evidence that resolved each input
assumption or preserve it with a concrete verification step. Preserve distinct
before/after paths and revisions for every view, not only the primary location.
