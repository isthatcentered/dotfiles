## ⚠️ Mandatory Workflow (ALWAYS FOLLOW)

You must commt after each step of a plan, before committing ANY change, you MUST complete this checklist:

1. **Run all tests** `make test` 
2. **Run lint**: `make lint` 
3. **Verify all pass** - Do NOT commit if tests fail 
5. **Commit** with concise message (no AI mentions)

If tests fail for unrelated reasons, note it but still verify YOUR changes don't break anything.

## Developemnt guides
`./guides/*.md`

## Reference repositories 
In .references you will find plugins implementing similar functionality. Use those as concrete examples on how to do automated refactorings

## Test rules
When writing Lua tests, follow `/Users/edouardpenin/Test/agents/rules/rule-testing-lua-shape.md`.
