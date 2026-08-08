local function shouldSave(bufferId)
  local buffer = vim.bo[bufferId]

  return vim.api.nvim_buf_is_loaded(bufferId)
    and (vim.api.nvim_buf_get_name(bufferId) ~= '') -- Has a file path
    and (buffer.buftype == '') -- Is file type
    and buffer.modified
    and buffer.buflisted
    and not buffer.readonly
end

local debounce_delay_ms = 1000
local debounce_generations = {}

local function isCurrentBuffer(bufferId)
  return bufferId == vim.api.nvim_get_current_buf()
end

local function shouldDelayAutosave(bufferId)
  if not isCurrentBuffer(bufferId) then
    return false
  end

  local mode = vim.api.nvim_get_mode().mode
  local mode_prefix = string.sub(mode, 1, 1)

  return mode_prefix == 'i' or mode_prefix == 'R'
end

local function getChangedtick(bufferId)
  return vim.api.nvim_buf_get_changedtick(bufferId)
end

local function saveBuffer(bufferId)
  if not shouldSave(bufferId) then
    return
  end

  vim.api.nvim_buf_call(bufferId, function()
    vim.cmd 'write'
  end)
end

local function scheduleAutosave(bufferId)
  if not isCurrentBuffer(bufferId) then
    return
  end

  if not shouldSave(bufferId) then
    return
  end

  debounce_generations[bufferId] = (debounce_generations[bufferId] or 0) + 1
  local generation = debounce_generations[bufferId]
  local changedtick = getChangedtick(bufferId)

  vim.defer_fn(function()
    if generation ~= debounce_generations[bufferId] then
      return
    end

    if not shouldSave(bufferId) then
      return
    end

    if shouldDelayAutosave(bufferId) then
      return
    end

    if changedtick ~= getChangedtick(bufferId) then
      return
    end

    saveBuffer(bufferId)
  end, debounce_delay_ms)
end

local AutoSaveGroup = vim.api.nvim_create_augroup('isthatcentered/autosave', { clear = true })
vim.api.nvim_create_autocmd('TextChanged', {
  group = AutoSaveGroup,
  callback = function(args)
    scheduleAutosave(args.buf)
  end,
})

vim.api.nvim_create_autocmd('InsertLeave', {
  group = AutoSaveGroup,
  callback = function(args)
    scheduleAutosave(args.buf)
  end,
})
