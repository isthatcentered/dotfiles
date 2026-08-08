local async = require 'isthatcentered.vtsls.async'

local path_sep = package.config:sub(1, 1)

local function to_file_range_request_args(file, range)
  return {
    file = file,
    startLine = range.start.line + 1,
    startOffset = range.start.character + 1,
    endLine = range['end'].line + 1,
    endOffset = range['end'].character + 1,
  }
end

return function(client)
  local function get_target_file(uri, range)
    local bufnr = vim.uri_to_bufnr(uri)
    local fname = vim.uri_to_fname(uri)

    local err, response = async.request(client, 'workspace/executeCommand', {
      command = 'typescript.tsserverRequest',
      arguments = { 'getMoveToRefactoringFileSuggestions', to_file_range_request_args(fname, range) },
    }, bufnr)

    if err or response.type ~= 'response' or not response.body then
      error('get candidate target files failed: ' .. vim.inspect(response))
    end

    local files = response.body.files
    local items = { { '', 'Enter new file path...', 1 } }

    async.schedule()
    for i = 1, #files do
      local path = files[i]
      table.insert(items, { path, vim.fn.fnamemodify(path, ':.'), i + 1 })
    end

    local item, idx = async.call(vim.ui.select, items, {
      prompt = 'Select move destination:',
      kind = 'nvim_vtsls_move_to_file_destination',
      format_item = function(item)
        return item[2]
      end,
    })

    if not item then -- selection cancelled
      return
    end

    if idx == 1 then
      return async.call(vim.ui.input, {
        prompt = 'Enter move destination:',
        default = vim.fn.fnamemodify(fname, ':h') .. path_sep,
        completion = 'file',
      })
    else
      return item[1]
    end
  end

  local function move_to_file_handler(command)
    async.exec(
      function()
        local args = command.arguments
        local action = args[1]
        local uri = args[2]
        local range = args[3]

        --[[
        -- 
{ "Command", {
    arguments = { {
        description = "Move to file",
        kind = "refactor.move.file",
        name = "Move to file",
        range = {
          ["end"] = {
            line = 16,
            offset = 23
          },
          start = {
            line = 16,
            offset = 1
          }
        }
      }, "file:///Users/edouardpenin/Test/random-ts-project-for-test/src/index.ts", {
        This is where I asked for refactorings
        ["end"] = {
          character = 6,
          line = 15
        },
        start = {
          character = 6,
          line = 15
        }
      } },
    command = "_typescript.moveToFileRefactoring",
    title = "Move to file"
  } }
        --]]

        --[[
        --{ "typescript.tsserverRequest", { "getMoveToRefactoringFileSuggestions", {
        endLine = 16,
        endOffset = 7,
        file = "/Users/edouardpenin/Test/random-ts-project-for-test/src/index.ts",
        startLine = 16,
        startOffset = 7
      } } }
        --]]
        vim.print { 'Command', command }

        local bufnr = vim.uri_to_bufnr(uri)
        local target_file = get_target_file(uri, range)

        --[[
        --{ "After get file", "_typescript.moveToFileRefactoring", { {
      description = "Move to file",
      kind = "refactor.move.file",
      name = "Move to file",
      range = {
        ["end"] = {
          line = 16,
          offset = 23
        },
        start = {
          line = 16,
          offset = 1
        }
      }
    }, "file:///Users/edouardpenin/Test/random-ts-project-for-test/src/index.ts", {
      ["end"] = {
        character = 6,
        line = 15
      },
      start = {
        character = 6,
        line = 15
      }
    }, "/Users/edouardpenin/Test/random-ts-project-for-test/src/blah.ts" } }
        --]]
        vim.print { 'After get file', command.command, { action, uri, range, target_file } }

        if target_file then
          async.request(client, 'workspace/executeCommand', {
            command = command.command,
            arguments = { action, uri, range, target_file },
          }, bufnr)
        end
      end, --
      config.get().default_resolve,
      config.get().default_reject
    )
  end

  return move_to_file_handler
end
