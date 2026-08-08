import * as fs from 'fs'
import type { Awaitable, UserConsoleLog } from 'vitest'
import type {
  Reporter,
  Vitest,
  TestSpecification,
  TestModule,
  TestCase,
  TestSuite,
  SerializedError,
} from 'vitest/node'
import type { ReportedHookContext, TestRunEndReason } from 'vitest/reporters'
import { ReporterV2 } from './reporter-v2'
import { ReporterV3 } from './reporter-v3'

// Debug logging - writes to file for debugging stdout issues
const DEBUG_LOG = '/tmp/nope-vitest-debug.log'

function debugLog(msg: string): void {
  fs.appendFileSync(DEBUG_LOG, `[${new Date().toISOString()}] [MAIN] ${msg}\n`)
}

export default class MyReporter implements Reporter {
  private delegate!: Reporter

  onInit(vitest: Vitest): void {
    debugLog(`onInit called, vitest.version: ${vitest.version}`)
    const major = parseInt(vitest.version.split('.')[0] ?? '0', 10)
    debugLog(
      `Detected major version: ${major}, using V${major === 2 ? '2' : '3'} reporter`
    )

    if (major < 2) {
      throw new Error(
        `nope.nvim requires Vitest 2 or higher (found ${vitest.version})`
      )
    }

    this.delegate =
      major === 2 ? new ReporterV2(vitest) : new ReporterV3(vitest)

    this.delegate.onInit?.(vitest)
  }

  // Vitest 3 hooks
  onTestRunStart(specs: ReadonlyArray<TestSpecification>): Awaitable<void> {
    return this.delegate.onTestRunStart?.(specs)
  }
  onTestRunEnd(
    testModules: ReadonlyArray<TestModule>,
    unhandledErrors: ReadonlyArray<SerializedError>,
    reason: TestRunEndReason
  ): Awaitable<void> {
    return this.delegate.onTestRunEnd?.(testModules, unhandledErrors, reason)
  }
  onTestModuleQueued(m: TestModule): Awaitable<void> {
    return this.delegate.onTestModuleQueued?.(m)
  }
  onTestModuleCollected(m: TestModule): Awaitable<void> {
    return this.delegate.onTestModuleCollected?.(m)
  }
  onTestModuleStart(m: TestModule): Awaitable<void> {
    return this.delegate.onTestModuleStart?.(m)
  }
  onTestModuleEnd(m: TestModule): Awaitable<void> {
    return this.delegate.onTestModuleEnd?.(m)
  }
  onTestCaseReady(t: TestCase): Awaitable<void> {
    return this.delegate.onTestCaseReady?.(t)
  }
  onTestCaseResult(t: TestCase): Awaitable<void> {
    return this.delegate.onTestCaseResult?.(t)
  }
  onTestSuiteReady(s: TestSuite): Awaitable<void> {
    return this.delegate.onTestSuiteReady?.(s)
  }
  onTestSuiteResult(s: TestSuite): Awaitable<void> {
    return this.delegate.onTestSuiteResult?.(s)
  }
  onHookStart(h: ReportedHookContext): Awaitable<void> {
    return this.delegate.onHookStart?.(h)
  }
  onHookEnd(h: ReportedHookContext): Awaitable<void> {
    return this.delegate.onHookEnd?.(h)
  }

  // Vitest 2 hooks (use 'any' for v2-specific types that don't exist in v3)
  onCollected(files: any): Awaitable<void> {
    return this.delegate.onCollected?.(files)
  }
  onTaskUpdate(packs: any, events?: any): Awaitable<void> {
    return (this.delegate as any).onTaskUpdate?.(packs, events)
  }
  onFinished(
    files: any,
    errors: unknown[],
    coverage?: unknown
  ): Awaitable<void> {
    return this.delegate.onFinished?.(files, errors, coverage)
  }

  // Shared hooks
  onUserConsoleLog(log: UserConsoleLog): Awaitable<void> {
    return this.delegate.onUserConsoleLog?.(log)
  }
  onCoverage(c: unknown): Awaitable<void> {
    return this.delegate.onCoverage?.(c)
  }
}
