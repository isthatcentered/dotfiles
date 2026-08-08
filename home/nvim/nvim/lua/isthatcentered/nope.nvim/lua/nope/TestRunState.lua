---@alias TestRunStatus "idle"|"pending"|"done"|"cancelled"
---@alias TestStatus "pending"|"passed"|"failed"|"skipped"

---@class TestFailure
---@field message string
---@field stack? string
---@field expected? string
---@field actual? string
---@field diff? string

---@class TestNode
---@field id string
---@field name string
---@field full_name string
---@field status TestStatus
---@field duration_ms? number
---@field location? {line: number, column: number}
---@field failure? TestFailure
---@field logs? string[]

---@class SuiteNode
---@field id string
---@field name string
---@field status TestStatus
---@field tests TestNode[]
---@field suites SuiteNode[]

---@class FileNode
---@field id string
---@field path string
---@field status TestStatus
---@field suites SuiteNode[]
---@field tests TestNode[]

---@class TestRunSummary
---@field total number
---@field passed number
---@field failed number
---@field skipped number

---@class TestRunState
---@field status TestRunStatus
---@field duration_ms? number
---@field summary TestRunSummary
---@field files FileNode[]

