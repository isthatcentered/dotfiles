---
name: spin-up-codex
description: Start a new Codex CLI instance with a chosen model and reasoning effort, optionally using a JSON output schema. Use only when explicitly asked to launch an instance.
---

# Spin Up Codex

Use `codex exec` for a new non-interactive instance. Pass the requested model and
reasoning effort explicitly; these overrides apply only to this run. Give it a
self-contained task, since a new instance does not inherit this conversation.

## Model and reasoning effort

`gpt-6-astra` (GPT-6-Astra) is the most capable model for complex, demanding work.
Its default reasoning effort is `medium`.

| Model | Supported reasoning efforts |
| --- | --- |
| `gpt-6-astra`, `gpt-5.6-sol`, `gpt-5.6-terra` | `low`, `medium`, `high`, `xhigh`, `max`, `ultra` |
| `gpt-5.6-luna` | `low`, `medium`, `high`, `xhigh`, `max` |

`ultra` includes automatic task delegation; use it only when delegation is
authorized. Do not assume `none` is supported by these models.

Verified against the local model catalog on 2026-09-05. For other models or
availability changes, inspect `models[].slug` and
`models[].supported_reasoning_levels` in
`${CODEX_HOME:-$HOME/.codex}/models_cache.json` when available. Do not silently
substitute a different model or effort if the requested combination is unavailable.

## Launch

Replace the example model, effort, directory, and task with the requested values.
Without an output schema:

```bash
codex exec -C /path/to/repo \
  -m gpt-6-astra -c 'model_reasoning_effort="high"' \
  -o /tmp/codex-result.txt \
  'Summarize the authentication flow in this repository.'
```

With an output schema, add `--output-schema` pointing to an existing JSON Schema
file and save the final JSON message:

```bash
codex exec -C /path/to/repo \
  -m gpt-6-astra -c 'model_reasoning_effort="high"' \
  --output-schema /tmp/codex-schema.json \
  -o /tmp/codex-result.json \
  'Summarize the authentication flow in this repository.'
```

For example, create `/tmp/codex-schema.json` with:

```json
{
  "type": "object",
  "properties": {
    "summary": { "type": "string" }
  },
  "required": ["summary"],
  "additionalProperties": false
}
```

- Omit `-C` to use the current directory and `-o` if no result file is needed.
- For long prompts, use `- < /path/to/task.md` instead of the quoted prompt.
- Use distinct result paths for separate runs. Check the exit status and read the
  final result before reporting completion.
- `--json` streams execution events as JSONL; `--output-schema` constrains the
  final response. They serve different purposes.

Check `codex exec --help` for flags supported by the installed CLI.
