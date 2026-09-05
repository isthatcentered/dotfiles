# Report example

Illustrative example; paths and line ranges below are fictional.

````
### 1. An explicit timeout of 0 becomes 30 seconds

Severity: medium — operations can be aborted despite the caller disabling the timeout.
Likelihood: unknown — the code establishes support for `0`, but not how often callers use it.

**Problematic location**
File: `src/options.js` @ `<head SHA>`
Start line: 18
End line: 20

**What goes wrong**
Callers that set `timeoutMs: 0` to disable timeouts instead get
a 30-second timeout. Operations lasting longer than that can
be aborted despite the caller explicitly disabling the limit.

**Before**
`src/options.js` @ `<base SHA>`, lines 18–20
```js
function resolveTimeout(options) {
  return options.timeoutMs ?? 30_000;
}
```

**After**
`src/options.js` @ `<head SHA>`, lines 18–20
```js
function resolveTimeout(options) {
  return options.timeoutMs || 30_000;
}
```

**Why it happens**
`0` is falsy, so `||` selects `30_000`. The previous `??`
expression preserved `0` and used the default only for
`null` or `undefined`.

The timeout contract documents `0` as disabling the limit
(`docs/options.md`, lines 44–46 at `<head SHA>`).

**How to reproduce**
Prerequisites: none beyond loading the reviewed function.

1. Call `resolveTimeout({ timeoutMs: 0 })`.
2. Inspect the returned value.

Expected: `0`, preserving the documented disabled timeout.
Predicted actual: `30000`.

**Evidence and limits**
The return value follows directly from the expression.
This reproduction has not been executed. An actual operation
being aborted after 30 seconds has not been tested.
````
