---
name: spin-up-codex
description: Start a new Codex CLI instance with a chosen model and reasoning effort, optionally using a JSON output schema.
---

# Spin Up Codex

Use `codex exec` for a new non-interactive instance. Use the requested model and
reasoning effort; default to `high` when no effort is specified. Pass both
explicitly. Give the instance a self-contained task; it does not inherit this
conversation.

| Model | Supported reasoning efforts |
| --- | --- |
| `gpt-6-astra`, `gpt-5.6-sol`, `gpt-5.6-terra` | `low`, `medium`, `high`, `xhigh`, `max`, `ultra` |
| `gpt-5.6-luna` | `low`, `medium`, `high`, `xhigh`, `max` |

`ultra` includes automatic task delegation; use it only when delegation is
authorized. For other models, check supported efforts in
`${CODEX_HOME:-$HOME/.codex}/models_cache.json`.

```bash
codex exec -C /path/to/repo \
  -m gpt-6-astra -c 'model_reasoning_effort="high"' \
  'Your task'
```

For a final response constrained by a JSON Schema, add these flags before the
prompt:

```bash
--output-schema /path/to/schema.json -o /path/to/result.json
```

- `-C` selects the working directory; omit it to use the current directory.
- `-o` saves the final response and also works without a schema.
- For long prompts, replace the quoted prompt with `- < /path/to/task.md`.
