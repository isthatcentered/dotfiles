local JSONParser = require("json_parser")

-- Mock vim.json.decode for testing
_G.vim = _G.vim or {}
_G.vim.json = _G.vim.json or {}
_G.vim.json.decode = function(str)
  -- Simple JSON parser for testing
  if str:match("^%s*{") then
    if str:find('"test"%s*:%s*true') then
      return { test = true }
    elseif str:find('"numFailedTests"%s*:%s*0') then
      return { numFailedTests = 0 }
    elseif str:find('"valid"%s*:%s*true') then
      return { valid = true }
    elseif str:find('"test"%s*:%s*}') or str:find('"bad"%s*:%s*}') then
      error("Invalid JSON")
    else
      return {}
    end
  elseif str:match("^%s*%[") then
    return {}
  else
    error("Invalid JSON")
  end
end

describe("JSONParser", function()
  describe("new", function()
    it("creates a new parser instance with default options", function()
      local parser = JSONParser.new()
      assert.is_not_nil(parser)
    end)

    it("creates a new parser with skip_non_json=false", function()
      local parser = JSONParser.new({ skip_non_json = false })
      assert.is_not_nil(parser)
    end)
  end)

  describe("parse_line", function()
    it("skips empty lines", function()
      local parser = JSONParser.new()
      local data, err = parser:parse_line("")
      assert.is_nil(data)
      assert.is_nil(err)
    end)

    it("skips whitespace-only lines", function()
      local parser = JSONParser.new()
      local data, err = parser:parse_line("   \t  ")
      assert.is_nil(data)
      assert.is_nil(err)
    end)

    it("skips non-JSON lines when skip_non_json is true", function()
      local parser = JSONParser.new({ skip_non_json = true })
      local data, err = parser:parse_line("Some startup text")
      assert.is_nil(data)
      assert.is_nil(err)
    end)

    it("skips non-JSON lines that don't start with { or [", function()
      local parser = JSONParser.new()
      local data, err = parser:parse_line("RERUN  ../src/sum.test.js")
      assert.is_nil(data)
      assert.is_nil(err)
    end)

    it("parses valid JSON object", function()
      local parser = JSONParser.new()
      local data, err = parser:parse_line('{"test": true}')
      assert.is_table(data)
      assert.is_nil(err)
      assert.is_true(data.test)
    end)

    it("parses valid JSON array", function()
      local parser = JSONParser.new()
      local data, err = parser:parse_line("[]")
      assert.is_table(data)
      assert.is_nil(err)
    end)

    it("returns error for malformed JSON that looks like JSON", function()
      local parser = JSONParser.new()
      local data, err = parser:parse_line('{"test": }')
      assert.is_nil(data)
      assert.is_string(err)
      assert.is_true(err:find("JSON parse error") ~= nil)
    end)

    it("handles JSON with leading whitespace", function()
      local parser = JSONParser.new()
      local data, err = parser:parse_line('  {"test": true}')
      assert.is_table(data)
      assert.is_nil(err)
    end)
  end)

  describe("parse_lines", function()
    it("parses multiple valid JSON lines", function()
      local parser = JSONParser.new()
      local lines = {
        '{"numFailedTests": 0}',
        '{"test": true}',
      }
      local parsed, errors = parser:parse_lines(lines)
      assert.are.equal(2, #parsed)
      assert.are.equal(0, #errors)
    end)

    it("skips non-JSON lines and parses valid ones", function()
      local parser = JSONParser.new()
      local lines = {
        "RERUN  ../src/sum.test.js",
        '{"numFailedTests": 0}',
        "Some other text",
        '{"test": true}',
      }
      local parsed, errors = parser:parse_lines(lines)
      assert.are.equal(2, #parsed)
      assert.are.equal(0, #errors)
    end)

    it("collects errors for malformed JSON", function()
      local parser = JSONParser.new()
      local lines = {
        '{"test": }',
        '{"valid": true}',
      }
      local parsed, errors = parser:parse_lines(lines)
      assert.are.equal(1, #parsed)
      assert.are.equal(1, #errors)
      assert.are.equal('{"test": }', errors[1].line)
      assert.is_string(errors[1].error)
    end)

    it("handles empty array", function()
      local parser = JSONParser.new()
      local parsed, errors = parser:parse_lines({})
      assert.are.equal(0, #parsed)
      assert.are.equal(0, #errors)
    end)

    it("handles mix of valid, invalid, and non-JSON lines", function()
      local parser = JSONParser.new()
      local lines = {
        "",
        "Plain text",
        '{"test": true}',
        "   ",
        '{"bad": }',
        '{"numFailedTests": 0}',
      }
      local parsed, errors = parser:parse_lines(lines)
      assert.are.equal(2, #parsed)
      assert.are.equal(1, #errors)
    end)
  end)
end)
