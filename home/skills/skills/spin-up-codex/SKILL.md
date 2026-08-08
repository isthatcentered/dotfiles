---
name: spin-up-codex
description: Spin up an autonomous codex agent via cli. Do not use unless explicitely asked to 
disable-model-invocation: true
---

# Spin Up Codex

Use `codex exec` to run Codex non-interactively from the CLI:

```bash
codex exec -m gpt-5.6-sol -c 'model_reasoning_effort="xhigh"' "your prompt here"
```

`-m` / `--model` selects the model for the run.

`-c` / `--config` overrides a Codex config value for this invocation without
editing `~/.codex/config.toml`.

Supported `model_reasoning_effort` values:

- `none`
- `low`
- `medium`
- `high`
- `xhigh`

## Structured Output

Use `--output-schema` when the final response must conform to a JSON Schema.

```bash
codex exec \
  -m gpt-5.6-sol \
  -c 'model_reasoning_effort="xhigh"' \
  --output-schema ./schema.json \
  -o ./result.json \
  "Extract the requested fields and return only schema-compliant JSON"
```

Example schema:

```json
{
  "type": "object",
  "properties": {
    "summary": { "type": "string" },
    "risks": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "required": ["summary", "risks"],
  "additionalProperties": false
}
```

`--output-schema ./schema.json` constrains the final answer shape.

`-o ./result.json` writes the final agent message to a file while still printing
it to stdout.
