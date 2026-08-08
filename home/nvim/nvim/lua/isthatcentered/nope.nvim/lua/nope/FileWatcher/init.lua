---@class FileWatcher
---@field private on_files_changed fun(files: string[])
---@field private fs_event userdata?
---@field private pending_files table<string, boolean>
---@field private cwd string
local M = {}
M.__index = M

---Check if file is ignored by git
---@param filepath string
---@return boolean
local function is_git_ignored(filepath)
  vim.fn.system({ "git", "check-ignore", "-q", filepath })
  return vim.v.shell_error == 0
end

---@param on_files_changed fun(files: string[])
---@return FileWatcher
function M.new(on_files_changed)
  return setmetatable({
    on_files_changed = on_files_changed,
    fs_event = nil,
    pending_files = {},
    cwd = vim.fn.getcwd(),
  }, M)
end

function M:start()
  if self.fs_event then
    return
  end

  self.fs_event = vim.uv.new_fs_event()

  self.fs_event:start(self.cwd, { recursive = true }, vim.schedule_wrap(function(err, filename, _)
    if err then
      vim.notify("FileWatcher error: " .. err, vim.log.levels.ERROR)
      return
    end

    if not filename then
      return
    end

    -- Only care about .lua files
    if not filename:match("%.lua$") then
      return
    end

    local full_path = self.cwd .. "/" .. filename

    -- Skip git-ignored files
    if is_git_ignored(full_path) then
      return
    end

    -- Collect changed file and notify
    self.pending_files[full_path] = true
    local files = vim.tbl_keys(self.pending_files)
    self.pending_files = {}
    self.on_files_changed(files)
  end))
end

function M:stop()
  if self.fs_event then
    self.fs_event:stop()
    self.fs_event:close()
    self.fs_event = nil
  end
  self.pending_files = {}
end

return M
