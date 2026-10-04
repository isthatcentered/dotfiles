---
name: babysit-pr
description: Monitor a pull request and fix failing checks in up to four rounds. Use when asked to babysit a PR or resolve CI failures.
disable-model-invocation: true
---

Monitor the PR until all checks pass. If any fail, investigate, fix the issues, validate locally, push the changes, and wait for the new check results. Allow at most four rounds of fixes.

If checks still fail after the fourth round, stop and report the remaining failures and fixes attempted.
