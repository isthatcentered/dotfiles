-- Dependency-free headless runner; specs use describe/it and real temporary files.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
vim.o.columns, vim.o.lines = 160, 50
local total, failed, suite = 0, 0, ''
local directories = {}
function describe(name, callback)
  suite = name
  callback()
end
function it(name, callback)
  total = total + 1
  local ok, err = xpcall(callback, debug.traceback)
  if not ok then
    failed = failed + 1
    print('FAIL ' .. suite .. ': ' .. name .. '\n' .. err)
  end
end
function eq(actual, expected)
  assert(vim.deep_equal(actual, expected), 'expected ' .. vim.inspect(expected) .. ', got ' .. vim.inspect(actual))
end
function tempdir()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, 'p')
  directories[#directories + 1] = path
  return path
end
function task(id, kind)
  return { version = 1, id = id or 1, title = 'A task', description = '', status = { kind = kind or 'backlog' } }
end
function read(path)
  local file = assert(io.open(path, 'rb'))
  local result = file:read '*a'
  file:close()
  return result
end
function write(path, value)
  local file = assert(io.open(path, 'wb'))
  file:write(value)
  file:close()
end
for _, name in ipairs { 'model_spec', 'repository_spec', 'ui_spec' } do
  dofile(root .. '/tests/' .. name .. '.lua')
end
for _, directory in ipairs(directories) do
  vim.fn.delete(directory, 'rf')
end
print(('%d tests, %d failures'):format(total, failed))
vim.cmd(failed == 0 and 'qa!' or 'cquit 1')
