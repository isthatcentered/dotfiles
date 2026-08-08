local codelens = require("beacon.codelens")

local function isJson(chunk)
  if type(chunk) ~= "string" then
    return false
  end

  -- Trim leading whitespace (spaces, tabs, newlines)
  local trimmed = chunk:match("^%s*(.-)$")
  if trimmed == "" then
    return false
  end

  -- Check first two characters
  return trimmed:sub(1, 2) == "[{"
end

---@param options SafeBeaconOptions
function runEslint(options)
  local output = ""
  local hasStartedEmittingJson = false

  local function handleStd(_, data, origin)
    if origin == "stdout" then
      if not isJson(data[1]) and not hasStartedEmittingJson then
        return
      end

      hasStartedEmittingJson = true
      for _, element in pairs(data) do
        output = output .. element
      end
    elseif origin == "stderr" then
    elseif origin == "exit" then
      local jsonOutput = vim.json.decode(output)
      vim.print(jsonOutput)
      ---@type vim.quickfix.entry[]
      local entries = {}
      -- vim.print(jsonOutput)
      for _, fileReport in pairs(jsonOutput) do
        for _, error in pairs(fileReport.messages) do
          local bufnr = vim.uri_to_bufnr(vim.uri_from_fname(fileReport.filePath))

          ---@ type vim.quickfix.entry
          local quickfix = {
            filename = fileReport.filePath,
            lnum = error.line,
            end_lnum = error.endLine,
            col = error.column,
            end_col = error.endColumn,
            text = error.message,
            type = "E",
            valid = error.ruleId,
          }
          table.insert(entries, quickfix)
        end
      end

      if #entries < 1 then
        vim.notify("No eslint issues found")
        return
      end

      vim.fn.setqflist(entries, " ")
      vim.cmd("botright copen")
    end
  end

  local jobIdOrErrorCode = vim.fn.jobstart(options.eslint_command, {
    detach = false, -- Kill the job when neovim exits
    on_stderr = handleStd,
    on_stdout = handleStd,
    on_exit = handleStd,
  })

  if jobIdOrErrorCode == 0 then
    vim.notify("Eslint: Invalid given arguments for eslint command")
    return
  elseif jobIdOrErrorCode == -1 then
    vim.notify("Eslint: Given eslint command is not executable")
    return
  end
end

local M = {}

---@alias SafeBeaconOptions {eslint_command: string[]}

---@alias BeaconOptions {eslint_command?: string[]}

---@param options BeaconOptions
function M.setup(options)
  -- codelens.register()

  ---@type SafeBeaconOptions
  local defaultOptions = {
    eslint_command = {
      "npx",
      "eslint",
      "src/**/*",
      "--ext",
      ".ts",
      "--format",
      "json",
    },
  }
  local safeOptions = vim.tbl_extend("force", defaultOptions, options)
  vim.api.nvim_create_user_command("BeaconRunEslint", function()
    runEslint(safeOptions)
  end, { force = true })
end

return M
