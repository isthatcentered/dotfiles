---
name: adversarial-code-review-final
description: Run an explicitly requested scripted code review of a repository branch with a supplied list of Codex and Claude reviewers, returning all findings as a JSON array.
disable-model-invocation: true
---

Run the bundled script to execute the entire review workflow. Require a repository URL, a nonempty branch name, and a nonempty JSON array of reviewers. Each reviewer has an `agent` (`codex` or `claude`) and a nonempty `model` string. If the lineup is not provided, default to the lineup presented in the example below and the current branch.

Use Python 3.10+, Git, and the authenticated CLIs selected by the reviewer list. Resolve `scripts/review.py` relative to this skill directory, then run:

```sh
python3 /path/to/adversarial-code-review-final/scripts/review.py \
  --repo git@github.com:owner/repository.git \
  --branch feature/example \
  --reviewers '[{"agent":"codex","model":"gpt-6-astra"},{"agent":"codex","model":"gpt-6-astra"},{"agent":"claude","model":"claude-opus-5-5"}]'
```

The script owns the workflow, you are only in charge of running the script with the correct branch and repository and reporting the findings once available.
