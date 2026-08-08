import * as fs from 'fs'
import type { Awaitable, UserConsoleLog } from 'vitest'
import type { Reporter, Vitest } from 'vitest/node'
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
  fs.appendFileSync(DEBUG_LOG, `[${new Date().toISOString()}] [V2] ${msg}\n`)
}

// Vitest 2 types - using interface declarations to avoid version conflicts
// These match the Vitest 2 API which differs from Vitest 3
interface V2Task {
  id: string
  name: string
  type: 'suite' | 'test' | 'custom'
  mode: 'run' | 'skip' | 'only' | 'todo'
  suite?: V2Task
  file?: V2File
  tasks?: V2Task[]
  result?: {
    state: string
    duration?: number
    errors?: unknown[]
  }
  location?: { line: number; column: number }
}

interface V2File extends V2Task {
  filepath: string
}

type V2TaskResultPack = [
  id: string,
  result: { state: string; duration?: number; errors?: unknown[] } | undefined,
  meta: unknown,
]

export class ReporterV2 implements Reporter {
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
    debugLog('ReporterV2 constructor called')
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

  private getOrCreateFile(filepath: string): FileNode {
    let file = this.fileMap.get(filepath)
    if (!file) {
      file = {
        id: `file:${filepath}`,
        path: filepath,
        status: 'pending',
        suites: [],
        tests: [],
      }
      this.fileMap.set(filepath, file)
      this.state.files.push(file)
    }
    return file
  }

  private getOrCreateSuite(
    task: V2Task,
    file: FileNode,
    parentSuite?: SuiteNode
  ): SuiteNode {
    const suiteId = `suite:${file.path}:${this.getFullName(task)}`
    let suite = this.suiteMap.get(suiteId)
    if (!suite) {
      suite = {
        id: suiteId,
        name: task.name,
        status: 'pending',
        tests: [],
        suites: [],
      }
      this.suiteMap.set(suiteId, suite)

      if (parentSuite) {
        parentSuite.suites.push(suite)
      } else {
        file.suites.push(suite)
      }
    }
    return suite
  }

  private getFullName(task: V2Task): string {
    const names: string[] = [task.name]
    let current = task.suite
    while (current && current.name) {
      names.unshift(current.name)
      current = current.suite
    }
    return names.join(' > ')
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

  private mapTaskState(state: string | undefined): TestStatus {
    switch (state) {
      case 'pass':
        return 'passed'
      case 'fail':
        return 'failed'
      case 'skip':
      case 'todo':
        return 'skipped'
      default:
        return 'pending'
    }
  }

  onInit(vitest: Vitest): void {
    debugLog(`onInit called, version: ${vitest.version}`)
    this.vitest = vitest
  }

  // Vitest 2 hook: Called when test files are collected
  // Using 'any' to handle version differences between compile-time (v3) and runtime (v2)
  onCollected(files?: unknown[]): Awaitable<void> {
    debugLog(`onCollected called, files: ${files?.length ?? 0}`)
    this.resetState()
    this.startTime = Date.now()
    this.state.status = 'pending'

    if (!files) {
      this.emit()
      return
    }

    for (const file of files as V2File[]) {
      const fileNode = this.getOrCreateFile(file.filepath)
      this.processTask(file, fileNode)
    }

    this.updateSummary()
    this.emit()
  }

  private processTask(
    task: V2Task,
    fileNode: FileNode,
    parentSuite?: SuiteNode
  ): void {
    if (task.type === 'suite') {
      // Skip the file-level suite (it has the same id as file)
      if (task.id === task.file?.id) {
        // Process children directly
        for (const child of task.tasks || []) {
          this.processTask(child, fileNode, parentSuite)
        }
      } else {
        const suite = this.getOrCreateSuite(task, fileNode, parentSuite)
        for (const child of task.tasks || []) {
          this.processTask(child, fileNode, suite)
        }
      }
    } else if (task.type === 'test' || task.type === 'custom') {
      const fullName = this.getFullName(task)
      const testId = `test:${fileNode.path}:${fullName}`

      if (!this.testMap.has(testId)) {
        const testNode: TestNode = {
          id: testId,
          name: task.name,
          full_name: fullName,
          status: this.mapTaskState(
            task.mode === 'skip' || task.mode === 'todo'
              ? task.mode
              : task.result?.state
          ),
          location: task.location,
        }
        this.testMap.set(testId, testNode)
        this.taskIdToTestId.set(task.id, testId)

        if (parentSuite) {
          parentSuite.tests.push(testNode)
        } else {
          fileNode.tests.push(testNode)
        }
      }
    }
  }

  // Vitest 2 hook: Called when task results are updated
  // Using 'any' to handle version differences between compile-time (v3) and runtime (v2)
  onTaskUpdate(packs: unknown[]): Awaitable<void> {
    debugLog(`onTaskUpdate called, packs: ${packs?.length ?? 0}`)
    for (const pack of packs as V2TaskResultPack[]) {
      const [taskId, result] = pack
      const testId = this.taskIdToTestId.get(taskId)
      if (!testId) continue

      const testNode = this.testMap.get(testId)
      if (!testNode) continue

      if (result) {
        testNode.status = this.mapTaskState(result.state)
        testNode.duration_ms = result.duration

        if (result.state === 'fail' && result.errors) {
          testNode.failure = this.extractFailure(
            result.errors as unknown as ReadonlyArray<TestError>
          )
        }
      }

      // Attach logs if any
      const logs = this.logMap.get(taskId)
      if (logs && logs.length > 0) {
        testNode.logs = logs
      }
    }

    // Update suite and file statuses
    for (const file of this.state.files) {
      for (const suite of file.suites) {
        this.updateSuiteStatusRecursive(suite)
      }
      file.status = this.computeFileStatus(file)
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

  // Vitest 2 hook: Called when test run is finished
  // Using 'any' to handle version differences between compile-time (v3) and runtime (v2)
  onFinished(files?: unknown[], _errors?: unknown[]): Awaitable<void> {
    debugLog(`onFinished called, files: ${files?.length ?? 0}`)
    this.state.status = 'done'
    this.state.duration_ms = Date.now() - this.startTime

    // Final status update for all files
    for (const file of this.state.files) {
      file.status = this.computeFileStatus(file)
    }

    this.updateSummary()
    this.emit()
  }

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
