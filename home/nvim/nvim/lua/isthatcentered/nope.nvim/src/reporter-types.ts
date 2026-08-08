// State types emitted to stdout for Lua consumption
export type TestRunStatus = 'idle' | 'pending' | 'done'
export type TestStatus = 'pending' | 'passed' | 'failed' | 'skipped'

export interface TestFailure {
  message: string
  stack?: string | undefined
  expected?: string | undefined
  actual?: string | undefined
  diff?: string | undefined
}

export interface TestNode {
  id: string
  name: string
  full_name: string
  status: TestStatus
  duration_ms?: number | undefined
  location?: { line: number; column: number } | undefined
  failure?: TestFailure | undefined
  logs?: string[] | undefined
}

export interface SuiteNode {
  id: string
  name: string
  status: TestStatus
  tests: TestNode[]
  suites: SuiteNode[]
}

export interface FileNode {
  id: string
  path: string
  status: TestStatus
  suites: SuiteNode[]
  tests: TestNode[] // top-level tests not in a suite
}

export interface TestRunSummary {
  total: number
  passed: number
  failed: number
  skipped: number
}

export interface TestRunState {
  status: TestRunStatus
  duration_ms?: number | undefined
  summary: TestRunSummary
  files: FileNode[]
}

// Internal tracking types
export interface TestError {
  message: string
  stack?: string
  diff?: string
  actual?: string
  expected?: string
}
