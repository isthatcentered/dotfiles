import * as fs from 'fs'
import { Awaitable, TestAnnotation, UserConsoleLog } from 'vitest'
import {
  SerializedError,
  TestCase,
  TestModule,
  TestSuite,
  Vitest,
} from 'vitest/node'
import {
  ReportedHookContext,
  Reporter,
  TestRunEndReason,
} from 'vitest/reporters'
import type { TestSpecification } from 'vitest/node'
import type {
  TestRunState,
  FileNode,
  SuiteNode,
  TestNode,
  TestStatus,
  TestFailure,
  TestError,
} from './reporter-types'

// Debug logging - writes to file for debugging stdout issues
const DEBUG_LOG = '/tmp/nope-vitest-debug.log'

function debugLog(msg: string): void {
  fs.appendFileSync(DEBUG_LOG, `[${new Date().toISOString()}] [V3] ${msg}\n`)
}

export class ReporterV3 implements Reporter {
  private vitest!: Vitest
  private startTime = 0

  // State tracking
  private state: TestRunState = this.createInitialState()

  // Maps for quick lookups
  private fileMap = new Map<string, FileNode>()
  private suiteMap = new Map<string, SuiteNode>()
  private testMap = new Map<string, TestNode>()
  private taskIdToTestId = new Map<string, string>()
  private logMap = new Map<string, string[]>()

  constructor(vitest: Vitest) {
    debugLog('ReporterV3 constructor called')
    this.vitest = vitest
  }

  private createInitialState(): TestRunState {
    return {
      status: 'idle',
      summary: { total: 0, passed: 0, failed: 0, skipped: 0 },
      files: [],
    }
  }

  private resetState(): void {
    this.state = this.createInitialState()
    this.fileMap.clear()
    this.suiteMap.clear()
    this.testMap.clear()
    this.taskIdToTestId.clear()
    this.logMap.clear()
  }

  private computeFileStatus(file: FileNode): TestStatus {
    const allTests = this.collectAllTests(file)
    if (allTests.some(t => t.status === 'failed')) return 'failed'
    if (allTests.some(t => t.status === 'pending')) return 'pending'
    if (allTests.every(t => t.status === 'skipped')) return 'skipped'
    return 'passed'
  }

  private computeSuiteStatus(suite: SuiteNode): TestStatus {
    const allTests = this.collectSuiteTests(suite)
    if (allTests.some(t => t.status === 'failed')) return 'failed'
    if (allTests.some(t => t.status === 'pending')) return 'pending'
    if (allTests.every(t => t.status === 'skipped')) return 'skipped'
    return 'passed'
  }

  private collectAllTests(file: FileNode): TestNode[] {
    const tests: TestNode[] = [...file.tests]
    const collectFromSuite = (suite: SuiteNode): void => {
      tests.push(...suite.tests)
      suite.suites.forEach(collectFromSuite)
    }
    file.suites.forEach(collectFromSuite)
    return tests
  }

  private collectSuiteTests(suite: SuiteNode): TestNode[] {
    const tests: TestNode[] = [...suite.tests]
    const collectFromSuite = (s: SuiteNode): void => {
      tests.push(...s.tests)
      s.suites.forEach(collectFromSuite)
    }
    suite.suites.forEach(collectFromSuite)
    return tests
  }

  private updateSummary(): void {
    let total = 0,
      passed = 0,
      failed = 0,
      skipped = 0
    for (const file of this.state.files) {
      const tests = this.collectAllTests(file)
      for (const t of tests) {
        total++
        if (t.status === 'passed') passed++
        else if (t.status === 'failed') failed++
        else if (t.status === 'skipped') skipped++
      }
    }
    this.state.summary = { total, passed, failed, skipped }
  }

  private getOrCreateFile(moduleId: string): FileNode {
    let file = this.fileMap.get(moduleId)
    if (!file) {
      file = {
        id: `file:${moduleId}`,
        path: moduleId,
        status: 'pending',
        suites: [],
        tests: [],
      }
      this.fileMap.set(moduleId, file)
      this.state.files.push(file)
    }
    return file
  }

  private getOrCreateSuite(testSuite: TestSuite, file: FileNode): SuiteNode {
    const suiteId = `suite:${testSuite.module.moduleId}:${testSuite.fullName}`
    let suite = this.suiteMap.get(suiteId)
    if (!suite) {
      suite = {
        id: suiteId,
        name: testSuite.name,
        status: 'pending',
        tests: [],
        suites: [],
      }
      this.suiteMap.set(suiteId, suite)

      const parent = testSuite.parent
      if (parent.type === 'module') {
        file.suites.push(suite)
      } else if (parent.type === 'suite') {
        const parentSuite = this.getOrCreateSuite(parent, file)
        parentSuite.suites.push(suite)
      }
    }
    return suite
  }

  private extractFailure(
    errors: ReadonlyArray<TestError> | undefined
  ): TestFailure | undefined {
    if (!errors || errors.length === 0) return undefined
    const err = errors[0]
    if (!err) return undefined
    return {
      message: err.message || 'Unknown error',
      stack: err.stack,
      expected: err.expected,
      actual: err.actual,
      diff: err.diff,
    }
  }

  onInit(vitest: Vitest): void {
    debugLog(`onInit called, version: ${vitest.version}`)
    this.vitest = vitest
  }

  onTestRunStart(
    _specifications: ReadonlyArray<TestSpecification>
  ): Awaitable<void> {
    debugLog(`onTestRunStart called, specs: ${_specifications?.length ?? 0}`)
    this.resetState()
    this.startTime = Date.now()
    this.state.status = 'pending'
    this.emit()
  }

  onTestRunEnd(
    _testModules: ReadonlyArray<TestModule>,
    _unhandledErrors: ReadonlyArray<SerializedError>,
    _reason: TestRunEndReason
  ): Awaitable<void> {
    debugLog(`onTestRunEnd called, modules: ${_testModules?.length ?? 0}`)
    this.state.status = 'done'
    this.state.duration_ms = Date.now() - this.startTime

    for (const file of this.state.files) {
      file.status = this.computeFileStatus(file)
    }
    this.updateSummary()
    this.emit()
  }

  onTestModuleQueued(_testModule: TestModule): Awaitable<void> {}

  onTestModuleCollected(testModule: TestModule): Awaitable<void> {
    debugLog(`onTestModuleCollected called, moduleId: ${testModule.moduleId}`)
    const file = this.getOrCreateFile(testModule.moduleId)

    const processChildren = (
      children: Iterable<TestCase | TestSuite>,
      parentFile: FileNode,
      parentSuite?: SuiteNode
    ): void => {
      for (const child of children) {
        if (child.type === 'suite') {
          const suite = this.getOrCreateSuite(child, parentFile)
          processChildren(child.children, parentFile, suite)
        } else if (child.type === 'test') {
          const testId = `test:${child.module.moduleId}:${child.fullName}`
          if (!this.testMap.has(testId)) {
            const testNode: TestNode = {
              id: testId,
              name: child.name,
              full_name: child.fullName,
              status: 'pending',
              location: child.location,
            }
            this.testMap.set(testId, testNode)
            this.taskIdToTestId.set(child.id, testId)
            if (parentSuite) {
              parentSuite.tests.push(testNode)
            } else {
              parentFile.tests.push(testNode)
            }
          }
        }
      }
    }

    processChildren(testModule.children, file)
    this.updateSummary()
    this.emit()
  }

  onTestModuleStart(_testModule: TestModule): Awaitable<void> {}

  onTestModuleEnd(testModule: TestModule): Awaitable<void> {
    const file = this.fileMap.get(testModule.moduleId)
    if (file) {
      file.status = this.computeFileStatus(file)
      for (const suite of file.suites) {
        this.updateSuiteStatusRecursive(suite)
      }
    }
    this.updateSummary()
    this.emit()
  }

  private updateSuiteStatusRecursive(suite: SuiteNode): void {
    for (const childSuite of suite.suites) {
      this.updateSuiteStatusRecursive(childSuite)
    }
    suite.status = this.computeSuiteStatus(suite)
  }

  onTestCaseReady(testCase: TestCase): Awaitable<void> {
    const testId = `test:${testCase.module.moduleId}:${testCase.fullName}`
    const testNode = this.testMap.get(testId)
    if (testNode) {
      testNode.status = 'pending'
    }
  }

  onTestCaseResult(testCase: TestCase): Awaitable<void> {
    debugLog(`onTestCaseResult called, test: ${testCase.fullName}`)
    const testId = `test:${testCase.module.moduleId}:${testCase.fullName}`
    const testNode = this.testMap.get(testId)
    if (!testNode) return

    const result = testCase.result()
    testNode.status = result.state as TestStatus

    const diag = testCase.diagnostic()
    if (diag) {
      testNode.duration_ms = diag.duration
    }

    if (result.state === 'failed' && result.errors) {
      testNode.failure = this.extractFailure(
        result.errors as unknown as ReadonlyArray<TestError>
      )
    }

    const logs = this.logMap.get(testCase.id)
    if (logs && logs.length > 0) {
      testNode.logs = logs
    }

    this.updateSummary()
    this.emit()
  }

  onTestCaseAnnotate(
    _testCase: TestCase,
    _annotation: TestAnnotation
  ): Awaitable<void> {}

  onTestSuiteReady(testSuite: TestSuite): Awaitable<void> {
    const file = this.fileMap.get(testSuite.module.moduleId)
    if (file) {
      const suite = this.getOrCreateSuite(testSuite, file)
      suite.status = 'pending'
    }
  }

  onTestSuiteResult(testSuite: TestSuite): Awaitable<void> {
    const suiteId = `suite:${testSuite.module.moduleId}:${testSuite.fullName}`
    const suite = this.suiteMap.get(suiteId)
    if (suite) {
      suite.status = this.computeSuiteStatus(suite)
    }
    this.emit()
  }

  onHookStart(_hook: ReportedHookContext): Awaitable<void> {}
  onHookEnd(_hook: ReportedHookContext): Awaitable<void> {}
  onCoverage(_coverage: unknown): Awaitable<void> {}

  onUserConsoleLog(log: UserConsoleLog): Awaitable<void> {
    if (!log.taskId) return
    const logs = this.logMap.get(log.taskId) ?? []
    logs.push(log.content)
    this.logMap.set(log.taskId, logs)
  }

  private emit(): void {
    const json = JSON.stringify(this.state)
    debugLog(`emit called, json length: ${json.length}`)
    process.stdout.write(json + '\n')
  }
}
