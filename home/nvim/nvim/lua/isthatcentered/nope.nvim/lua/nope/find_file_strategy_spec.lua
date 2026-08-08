local strategies = require("find_file_strategy")
local LocalProjectFileStrategy = strategies.LocalProjectFileStrategy

-- Mock vim APIs for testing
_G.vim = _G.vim or {}
_G.vim.fn = _G.vim.fn or {}
_G.vim.loop = _G.vim.loop or {}

describe("LocalProjectFileStrategy", function()
  describe("new", function()
    it("creates instance with provided cwd", function()
      local strategy = LocalProjectFileStrategy.new("/test/path")
      assert.is_not_nil(strategy)
      assert.equals("/test/path", strategy.cwd)
    end)

    it("uses vim.fn.getcwd() if cwd not provided", function()
      _G.vim.fn.getcwd = function()
        return "/default/path"
      end

      local strategy = LocalProjectFileStrategy.new()
      assert.equals("/default/path", strategy.cwd)
    end)
  end)

  describe("_glob_to_pattern", function()
    it("converts simple wildcard *", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local pattern = strategy:_glob_to_pattern("*.json")
      assert.equals("^[^/]*%.json$", pattern)
    end)

    it("converts recursive wildcard **/ to match zero or more path segments", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local pattern = strategy:_glob_to_pattern("**/vitest*")
      assert.equals("^.*vitest[^/]*$", pattern)
    end)

    it("converts ? wildcard", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local pattern = strategy:_glob_to_pattern("test?.js")
      assert.equals("^test.%.js$", pattern)
    end)

    it("escapes special Lua pattern characters", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local pattern = strategy:_glob_to_pattern("test-file.json")
      assert.equals("^test%-file%.json$", pattern)
    end)

    it("handles complex patterns", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local pattern = strategy:_glob_to_pattern("**/vitest.*.config.*")
      assert.equals("^.*vitest%.[^/]*%.config%.[^/]*$", pattern)
    end)

    it("**/ pattern matches files at root level", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local pattern = strategy:_glob_to_pattern("**/vitest*")
      local lua_pattern = pattern

      -- Test that pattern matches root level files
      assert.is_true(("vitest.config.js"):match(lua_pattern) ~= nil)
      assert.is_true(("vitest.config.ts"):match(lua_pattern) ~= nil)
    end)

    it("**/ pattern matches files in subdirectories", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local pattern = strategy:_glob_to_pattern("**/vitest*")
      local lua_pattern = pattern

      -- Test that pattern matches nested files
      assert.is_true(("config/vitest.config.js"):match(lua_pattern) ~= nil)
      assert.is_true(("packages/api/vitest.test.ts"):match(lua_pattern) ~= nil)
    end)

    it("**/ pattern does not match files without the target string", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local pattern = strategy:_glob_to_pattern("**/vitest*")
      local lua_pattern = pattern

      -- Test that pattern doesn't match files without "vitest"
      assert.is_nil(("other.config.js"):match(lua_pattern))
      assert.is_nil(("config/jest.config.js"):match(lua_pattern))
    end)
  end)

  describe("_path_depth", function()
    it("returns 0 for files in root", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      assert.equals(0, strategy:_path_depth("file.txt"))
    end)

    it("returns 1 for files in subdirectory", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      assert.equals(1, strategy:_path_depth("dir/file.txt"))
    end)

    it("returns 3 for deeply nested files", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      assert.equals(3, strategy:_path_depth("a/b/c/file.txt"))
    end)
  end)

  describe("_sort_files", function()
    it("sorts by depth first, then alphabetically", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local files = {
        "z/file.txt",
        "a/file.txt",
        "file1.txt",
        "file2.txt",
        "b/c/file.txt",
      }
      strategy:_sort_files(files)
      assert.same({
        "file1.txt",
        "file2.txt",
        "a/file.txt",
        "z/file.txt",
        "b/c/file.txt",
      }, files)
    end)

    it("handles empty array", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local files = {}
      strategy:_sort_files(files)
      assert.same({}, files)
    end)
  end)

  describe("_scan_recursive", function()
    it("scans files matching pattern", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local matches = {}
      local pattern = "^[^/]*%.json$"

      -- Mock fs_scandir to return test files
      local scandir_results = {
        { "test.json", "file" },
        { "test.txt", "file" },
        { "config.json", "file" },
      }
      local index = 0

      _G.vim.loop.fs_scandir = function(dir)
        return true
      end

      _G.vim.loop.fs_scandir_next = function(handle)
        index = index + 1
        if index <= #scandir_results then
          return scandir_results[index][1], scandir_results[index][2]
        end
        return nil
      end

      strategy:_scan_recursive("/test", matches, pattern, "/test")

      -- Should match test.json and config.json, but not test.txt
      assert.equals(2, #matches)
      assert.is_true(vim.tbl_contains(matches, "test.json"))
      assert.is_true(vim.tbl_contains(matches, "config.json"))
    end)

    it("handles nil pattern (matches all files)", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local matches = {}

      local scandir_results = {
        { "test.json", "file" },
        { "test.txt", "file" },
      }
      local index = 0

      _G.vim.loop.fs_scandir = function(dir)
        return true
      end

      _G.vim.loop.fs_scandir_next = function(handle)
        index = index + 1
        if index <= #scandir_results then
          return scandir_results[index][1], scandir_results[index][2]
        end
        return nil
      end

      strategy:_scan_recursive("/test", matches, nil, "/test")

      -- Should match all files
      assert.equals(2, #matches)
    end)

    it("skips hidden files", function()
      local strategy = LocalProjectFileStrategy.new("/test")
      local matches = {}

      local scandir_results = {
        { "test.json", "file" },
        { ".hidden.json", "file" },
      }
      local index = 0

      _G.vim.loop.fs_scandir = function(dir)
        return true
      end

      _G.vim.loop.fs_scandir_next = function(handle)
        index = index + 1
        if index <= #scandir_results then
          return scandir_results[index][1], scandir_results[index][2]
        end
        return nil
      end

      strategy:_scan_recursive("/test", matches, nil, "/test")

      -- Should skip .hidden.json
      assert.equals(1, #matches)
      assert.equals("test.json", matches[1])
    end)
  end)

  describe("find", function()
    it("returns all files when glob is empty string", function()
      local strategy = LocalProjectFileStrategy.new("/test")

      local scandir_results = {
        { "test.json", "file" },
        { "test.txt", "file" },
      }
      local index = 0

      _G.vim.loop.fs_scandir = function(dir)
        return true
      end

      _G.vim.loop.fs_scandir_next = function(handle)
        index = index + 1
        if index <= #scandir_results then
          return scandir_results[index][1], scandir_results[index][2]
        end
        return nil
      end

      local files = strategy:find("")
      assert.equals(2, #files)
    end)

    it("returns filtered files when glob is provided", function()
      local strategy = LocalProjectFileStrategy.new("/test")

      local scandir_results = {
        { "vitest.config.js", "file" },
        { "other.config.js", "file" },
      }
      local index = 0

      _G.vim.loop.fs_scandir = function(dir)
        return true
      end

      _G.vim.loop.fs_scandir_next = function(handle)
        index = index + 1
        if index <= #scandir_results then
          return scandir_results[index][1], scandir_results[index][2]
        end
        return nil
      end

      local files = strategy:find("vitest*")
      assert.equals(1, #files)
      assert.equals("vitest.config.js", files[1])
    end)

    it("returns sorted files", function()
      local strategy = LocalProjectFileStrategy.new("/test")

      local scandir_results = {
        { "z.txt", "file" },
        { "a.txt", "file" },
      }
      local index = 0

      _G.vim.loop.fs_scandir = function(dir)
        return true
      end

      _G.vim.loop.fs_scandir_next = function(handle)
        index = index + 1
        if index <= #scandir_results then
          return scandir_results[index][1], scandir_results[index][2]
        end
        return nil
      end

      local files = strategy:find("*.txt")
      assert.equals(2, #files)
      assert.equals("a.txt", files[1])
      assert.equals("z.txt", files[2])
    end)

    it("returns empty array when no files match", function()
      local strategy = LocalProjectFileStrategy.new("/test")

      _G.vim.loop.fs_scandir = function(dir)
        return true
      end

      _G.vim.loop.fs_scandir_next = function(handle)
        return nil
      end

      local files = strategy:find("*.txt")
      assert.equals(0, #files)
    end)
  end)
end)
