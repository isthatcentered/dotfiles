# Vitest Event Capture Script

This directory contains a reusable script to capture all Vitest test events as individual JSON files. This is useful for analyzing test execution flow, debugging, or building custom test UIs.

## Files

- `capture-vitest-outputs.ts` - Main script that orchestrates the test run and output capture
- `vitest-event-capture-reporter.ts` - Custom Vitest reporter that captures events as JSON files

## Usage

```bash
npx tsx scripts/capture-vitest-outputs.ts --dir <test-dir> --config <config-path> [--output <output-dir>]
```

### Parameters

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `--dir` | Yes | Directory or file pattern to test | - |
| `--config` | Yes | Path to Vitest config file | - |
| `--output` | No | Output directory for captured events | `./vitest_test_run_output` |

### Examples

Run tests in a specific module:
```bash
npx tsx scripts/capture-vitest-outputs.ts \
  --dir src/modules/admin \
  --config config/vitest.unit.config.ts
```

Run tests in a library directory:
```bash
npx tsx scripts/capture-vitest-outputs.ts \
  --dir src/lib/batch \
  --config config/vitest.unit.config.ts
```

Run with custom output directory:
```bash
npx tsx scripts/capture-vitest-outputs.ts \
  --dir src/lib/ui-context \
  --config config/vitest.unit.config.ts \
  --output ./my-custom-output
```

Run integration tests:
```bash
npx tsx scripts/capture-vitest-outputs.ts \
  --dir src/modules/data-extract \
  --config config/vitest.integration.config.ts
```

## Output Structure

The script creates a timestamped directory with all captured events:

```
vitest_test_run_output/
└── run_2025-12-22_09-10-55/
    ├── 0001_onInit.json
    ├── 0002_onPathsCollected.json
    ├── 0003_onCollected.json
    ├── 0004_onTaskUpdate_src-lib-ui-context-index_unit_test.json
    ├── 0005_onTaskUpdate_src-lib-ui-context-index_unit_test.json
    ├── ...
    ├── 0033_onFinished.json
    └── manifest.json
```

### File Naming Convention

- Files are numbered sequentially with 4-digit padding (0001, 0002, etc.)
- Format: `{number}_{eventType}_{testFilePath}.json`
- Test file path is sanitized and appended when available
- Events without a specific test file don't have the path suffix

### Event Files

Each event file contains:

```json
{
  "eventType": "onTaskUpdate",
  "counter": 10,
  "timestamp": "2025-12-22T09:10:57.492Z",
  "data": {
    "taskId": "-794335663_0_0_0_2",
    "name": "should handle session with single scope",
    "type": "test",
    "file": "/path/to/test/file.ts",
    "result": {
      "state": "pass",
      "duration": 0.14,
      "errors": "[undefined]"
    }
  }
}
```

### Manifest File

The `manifest.json` file contains a summary of the entire test run:

```json
{
  "totalEvents": 33,
  "runTimestamp": "2025-12-22T09:10:57.504Z",
  "summary": {
    "totalTests": 20,
    "passed": 20,
    "failed": 0,
    "skipped": 0,
    "todo": 0,
    "totalDuration": 30.23
  },
  "outputDirectory": "vitest_test_run_output/run_2025-12-22_09-10-55"
}
```

## Captured Events

The reporter captures the following Vitest lifecycle events:

| Event | Description |
|-------|-------------|
| `onInit` | Vitest initialization |
| `onPathsCollected` | Test file paths collected |
| `onCollected` | Test files collected and parsed |
| `onTaskUpdate` | Individual test task updates (state changes) |
| `onFinished` | Test run completed |
| `onTestRemoved` | Test removed from run |
| `onWatcherStart` | Watch mode started (if applicable) |
| `onWatcherRerun` | Watch mode triggered rerun (if applicable) |
| `onServerRestart` | Vite server restarted (if applicable) |
| `onProcessTimeout` | Process timeout occurred (if applicable) |
| `onUserConsoleLog` | User console output (if captured) |

## Copying to Other Projects

This script is designed to be portable. To use it in another project:

1. Copy both script files:
   ```bash
   cp scripts/capture-vitest-outputs.ts /path/to/other/project/scripts/
   cp scripts/vitest-event-capture-reporter.ts /path/to/other/project/scripts/
   ```

2. Ensure the target project has the required dependencies:
   - `vitest` (version 2.x or compatible)
   - `tsx` (for running TypeScript directly)

3. Run the script from the target project's root directory

## Requirements

- Node.js 18+
- Vitest 2.x
- TypeScript
- `tsx` package (included in devDependencies)

## Notes

- The script creates a temporary Vitest config file (`.vitest.capture.config.ts`) during execution, which is automatically cleaned up
- All test events are serialized to JSON, with circular references handled automatically
- Functions, symbols, and other non-JSON-serializable values are converted to string representations
- The reporter is compatible with both ESM and CommonJS module systems
- Test execution happens in a single run (no watch mode)

## Troubleshooting

### "Config file not found" error
- Verify the path to the config file is correct
- Use relative or absolute paths
- Check that the config file exists

### "Directory not found" warning
- This is usually safe - Vitest will attempt pattern matching
- Verify the directory path if tests don't run as expected

### No events captured
- Check that the output directory has write permissions
- Verify the reporter is being loaded correctly
- Check console for any error messages

### Module resolution errors
- Ensure `tsx` is installed: `npm install -D tsx`
- Try running with `npx tsx` instead of `tsx` directly
- Check that all dependencies are installed: `npm install`

## Example Output

Running the script will show:
```
================================================================================
Vitest Event Capture Script
================================================================================
Test directory:   /path/to/tests
Config file:      /path/to/config.ts
Output directory: vitest_test_run_output/run_2025-12-22_09-10-55
================================================================================

Running: npx vitest run --config .vitest.capture.config.ts /path/to/tests

✓ src/lib/ui-context/index.unit.test.ts (20 tests) 31ms

Test Files  1 passed (1)
     Tests  20 passed (20)
  Duration  1.09s

================================================================================
Test run completed!
Events captured in: vitest_test_run_output/run_2025-12-22_09-10-55
================================================================================

Summary:
  Total events captured: 33
  Total tests: 20
  Passed: 20
  Failed: 0
  Skipped: 0
```
