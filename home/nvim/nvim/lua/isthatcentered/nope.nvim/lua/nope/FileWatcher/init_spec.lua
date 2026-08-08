local FileWatcher = require("nope.FileWatcher")

describe("FileWatcher", function()
  local watcher
  local test_dir
  local original_cwd

  before_each(function()
    original_cwd = vim.fn.getcwd()
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, "p")
    vim.fn.chdir(test_dir)
    -- Initialize git repo so git check-ignore works
    vim.fn.system({ "git", "init" })
  end)

  after_each(function()
    if watcher then
      watcher:stop()
      watcher = nil
    end
    vim.fn.chdir(original_cwd)
    vim.fn.delete(test_dir, "rf")
  end)

  it("creates instance with callback", function()
    local callback = function() end
    watcher = FileWatcher.new(callback)
    assert.is_not_nil(watcher)
  end)

  it("start is idempotent", function()
    watcher = FileWatcher.new(function() end)
    watcher:start()
    watcher:start()
    -- Should not error
  end)

  it("stop is idempotent", function()
    watcher = FileWatcher.new(function() end)
    watcher:start()
    watcher:stop()
    watcher:stop()
    -- Should not error
  end)

  it("can stop without starting", function()
    watcher = FileWatcher.new(function() end)
    watcher:stop()
    -- Should not error
  end)

  it("calls callback when lua file changes", function()
    local changed_files = nil
    watcher = FileWatcher.new(function(files)
      changed_files = files
    end)
    watcher:start()

    -- Create a lua file
    local test_file = test_dir .. "/test.lua"
    vim.fn.writefile({ "-- test" }, test_file)

    vim.wait(500, function()
      return changed_files ~= nil
    end)

    assert.is_not_nil(changed_files)
    assert.same(1, #changed_files)
    assert.truthy(changed_files[1]:match("test%.lua$"))
  end)

  it("ignores non-lua files", function()
    local changed_files = nil
    watcher = FileWatcher.new(function(files)
      changed_files = files
    end)
    watcher:start()

    -- Create a non-lua file
    local test_file = test_dir .. "/test.txt"
    vim.fn.writefile({ "test" }, test_file)

    vim.wait(200, function()
      return changed_files ~= nil
    end)

    assert.is_nil(changed_files)
  end)

  it("ignores gitignored files", function()
    -- Create .gitignore
    vim.fn.writefile({ "ignored/" }, test_dir .. "/.gitignore")
    vim.fn.mkdir(test_dir .. "/ignored", "p")

    local changed_files = nil
    watcher = FileWatcher.new(function(files)
      changed_files = files
    end)
    watcher:start()

    -- Create a lua file in ignored directory
    local test_file = test_dir .. "/ignored/test.lua"
    vim.fn.writefile({ "-- test" }, test_file)

    vim.wait(200, function()
      return changed_files ~= nil
    end)

    assert.is_nil(changed_files)
  end)

  it("detects changes in subdirectories", function()
    vim.fn.mkdir(test_dir .. "/subdir", "p")

    local changed_files = nil
    watcher = FileWatcher.new(function(files)
      changed_files = files
    end)
    watcher:start()

    -- Create a lua file in subdirectory
    local test_file = test_dir .. "/subdir/test.lua"
    vim.fn.writefile({ "-- test" }, test_file)

    vim.wait(500, function()
      return changed_files ~= nil
    end)

    assert.is_not_nil(changed_files)
    assert.truthy(changed_files[1]:match("subdir/test%.lua$"))
  end)
end)
