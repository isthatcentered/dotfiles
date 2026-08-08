---@alias VitestSnapshot {
--- added: number,
--- didUpdate:boolean,
--- failure:boolean,
--- filesAdded: number,
--- filesRemoved: number,
--- filesRemovedList: {},
--- filesUnmatched: number,
--- filesUpdated: number,
--- matched: number,
--- total: number,
--- unchecked: number,
--- uncheckedKeysByFile: {},
--- unmatched: number,
--- updated: number,
--- }

---@alias VitestAssertionResult {
---   ancestorTitles: string[],
---   duration?: number,
---   failureMessages: string[],
---   fullName:string,
---   meta: {},
---   location: {line: number, column: number},
---   status:string,
---   title:string,
--- }

---@alias VitestTestResult {
--- endTime: number,
--- message:string,
--- name:string,
--- startTime: number,
--- status:string,
--- assertionResults: VitestAssertionResult[],
--- }

---@alias VitestJson {
--- numFailedTestSuites: number,
--- numFailedTests: number,
--- numPassedTestSuites: number,
--- numPassedTests: number,
--- numPendingTestSuites: number,
--- numPendingTests: number,
--- numTodoTests: number,
--- numTotalTestSuites: number,
--- numTotalTests: number,
--- startTime: number,
--- success: boolean,
--- snapshot: string,
--- testResults: VitestTestResult[],
--- }

-- TODO: prevent buffer switch in window
-- TODO: Delete buffer on exit
function table.clone(org)
  return { table.unpack(org) }
end

local function isValidBuffer(bufferId)
  return vim.api.nvim_buf_is_valid(bufferId) and vim.api.nvim_buf_is_loaded(bufferId)
end

local openWindowBelow = function(bufferId)
  local windowId = vim.api.nvim_open_win(bufferId, false, {
    height = 20,
    style = 'minimal',
    vertical = true,
    split = 'below',
    focusable = false,
  })

  return windowId
end

-- TODO: Display status bar of failing files in red
-- TODO: Add a Telescope searhc for failing files (that's already the diagnostics)
-- TODO: On quit nvim, quit job
-- TODO: On quit display, quit job
-- TODO: When someone tries to switch the buffer in that window, prevent it
-- TODO: On new buffer display, add extmarks
local function runVitestGlobal(sourceBufferId)
  local state = {
    windowId = nil,
    bufferId = nil,
    jobId = nil,
  }

  if not state.bufferId or not isValidBuffer(state.bufferId) then
    state.bufferId = vim.api.nvim_create_buf(false, true)
  end

  if not state.windowId or not vim.api.nvim_win_is_valid(state.windowId) then
    state.windowId = openWindowBelow(state.bufferId)
  end

  -- local filename = vim.api.nvim_buf_get_name(event.buf)
  -- vim.api.nvim_buf_set_lines(state.bufferId, 0, -1, false, { 'Running: ' .. filename })
  if state.jobId then
    return
  end

  local handleData = function(_jobId, data, _e)
    local jsonString = unpack(data)
    ---@type VitestJson
    local json = vim.json.decode(jsonString)
    -- vim.print(json.testResults)

    local failures = {}
    for _, testResult in pairs(json.testResults) do
      local filepath = testResult.name

      for _, assertionResult in pairs(testResult.assertionResults) do
        if assertionResult.status == 'failed' then
          -- keep results in memory if the file is opened later
          local bufferId = vim.uri_to_bufnr(vim.uri_from_fname(filepath))
          vim.print("A")
          table.insert(failures, {
            bufnr = bufferId,
            lnum = assertionResult.location.line,
            col = assertionResult.location.column,
            type = 'E',
            text = vim.api.nvim_buf_get_lines(bufferId, assertionResult.location.line - 1, assertionResult.location.line, false),
          })
        end
      end
    end

    local quicklistResult = vim.fn.setqflist(failures, "r")
    vim.print("QL", quicklistResult)
    if data then
      vim.api.nvim_buf_set_lines(state.bufferId, -1, -1, false, data)
    end
  end

  state.jobId = vim.fn.jobstart({ 'npx', 'vitest', '--reporter', 'json', '--watch', '--includeTaskLocation' }, {
    on_stdout = handleData,
    on_stderr = handleData,
    on_exit = function(data)
      vim.print 'DONE!!!'
    end,
  })

  local GROUP = vim.api.nvim_create_augroup('IsThatCenteredAutorun', { clear = true })
  vim.api.nvim_create_autocmd('ExitPre', {
    group = GROUP,
    callback = function()
      if not state.windowId or not vim.api.nvim_win_is_valid(state.windowId) then
        return
      end
      vim.api.nvim_win_close(state.windowId, true)
      if state.jobId then
        vim.fn.jobstop(state.jobId)
      end
    end,
  })
end

vim.api.nvim_create_user_command('AutoRun', function()
  runVitestGlobal(vim.api.nvim_get_current_buf())
end, {})
