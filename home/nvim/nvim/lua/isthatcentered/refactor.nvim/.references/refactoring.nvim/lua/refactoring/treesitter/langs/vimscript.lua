local TreeSitter = require("refactoring.treesitter.treesitter")

local Nodes = require("refactoring.treesitter.nodes")
local InlineNode = Nodes.InlineNode
local StringNode = Nodes.StringNode
local QueryNode = Nodes.QueryNode

---@class refactor.TreeSitterInstance
local Vim = {}

function Vim.new(bufnr, ft)
    ---@type refactor.TreeSitterLanguageConfig
    local config = {
        filetype = ft,
        bufnr = bufnr,
        scope_names = {},
        block_scope = {},
        variable_scope = {},
        indent_scopes = {
            while_loop = true,
            for_loop = true,
            if_statement = true,
            try_statement = true,
            function_definition = true,
            body = true,
        },
        valid_class_nodes = {},
        local_var_names = {},
        function_args = {},
        local_var_values = {},
        local_declarations = {},
        debug_paths = {
            while_loop = StringNode("while"),
            for_loop = StringNode("for"),
            if_statement = StringNode("if"),
            try_statement = StringNode("try"),
            function_definition = QueryNode(
                "(function_definition (function_declaration name: (_) @name))"
            ),
        },
        statements = {
            InlineNode("(body) @tmp_capture"),
            InlineNode("(let_statement) @tmp_capture"),
            InlineNode("(unlet_statement) @tmp_capture"),
            InlineNode("(const_statement) @tmp_capture"),
            InlineNode("(set_statement) @tmp_capture"),
            InlineNode("(setlocal_statement) @tmp_capture"),
            InlineNode("(return_statement) @tmp_capture"),
            InlineNode("(normal_statement) @tmp_capture"),
            InlineNode("(while_loop) @tmp_capture"),
            InlineNode("(for_loop) @tmp_capture"),
            InlineNode("(if_statement) @tmp_capture"),
            InlineNode("(lua_statement) @tmp_capture"),
            InlineNode("(range_statement) @tmp_capture"),
            InlineNode("(ruby_statement) @tmp_capture"),
            InlineNode("(python_statement) @tmp_capture"),
            InlineNode("(perl_statement) @tmp_capture"),
            InlineNode("(call_statement) @tmp_capture"),
            InlineNode("(execute_statement) @tmp_capture"),
            InlineNode("(echo_statement) @tmp_capture"),
            InlineNode("(echon_statement) @tmp_capture"),
            InlineNode("(echohl_statement) @tmp_capture"),
            InlineNode("(echomsg_statement) @tmp_capture"),
            InlineNode("(echoerr_statement) @tmp_capture"),
            InlineNode("(try_statement) @tmp_capture"),
            InlineNode("(throw_statement) @tmp_capture"),
            InlineNode("(autocmd_statement) @tmp_capture"),
            InlineNode("(silent_statement) @tmp_capture"),
            InlineNode("(vertical_statement) @tmp_capture"),
            InlineNode("(belowright_statement) @tmp_capture"),
            InlineNode("(aboveleft_statement) @tmp_capture"),
            InlineNode("(topleft_statement) @tmp_capture"),
            InlineNode("(botright_statement) @tmp_capture"),
            InlineNode("(register_statement) @tmp_capture"),
            InlineNode("(map_statement) @tmp_capture"),
            InlineNode("(augroup_statement) @tmp_capture"),
            InlineNode("(bang_filter_statement) @tmp_capture"),
            InlineNode("(highlight_statement) @tmp_capture"),
            InlineNode("(syntax_statement) @tmp_capture"),
            InlineNode("(setfiletype_statement) @tmp_capture"),
            InlineNode("(options_statement) @tmp_capture"),
            InlineNode("(startinsert_statement) @tmp_capture"),
            InlineNode("(stopinsert_statement) @tmp_capture"),
            InlineNode("(scriptencoding_statement) @tmp_capture"),
            InlineNode("(source_statement) @tmp_capture"),
            InlineNode("(global_statement) @tmp_capture"),
            InlineNode("(colorscheme_statement) @tmp_capture"),
            InlineNode("(command_statement) @tmp_capture"),
            InlineNode("(comclear_statement) @tmp_capture"),
            InlineNode("(delcommand_statement) @tmp_capture"),
            InlineNode("(filetype_statement) @tmp_capture"),
            InlineNode("(runtime_statement) @tmp_capture"),
            InlineNode("(wincmd_statement) @tmp_capture"),
            InlineNode("(sign_statement) @tmp_capture"),
            InlineNode("(break_statement) @tmp_capture"),
            InlineNode("(continue_statement) @tmp_capture"),
            InlineNode("(cnext_statement) @tmp_capture"),
            InlineNode("(cprevious_statement) @tmp_capture"),
            InlineNode("(unknown_builtin_statement) @tmp_capture"),
            InlineNode("(edit_statement) @tmp_capture"),
            InlineNode("(enew_statement) @tmp_capture"),
            InlineNode("(find_statement) @tmp_capture"),
            InlineNode("(ex_statement) @tmp_capture"),
            InlineNode("(visual_statement) @tmp_capture"),
            InlineNode("(view_statement) @tmp_capture"),
            InlineNode("(eval_statement) @tmp_capture"),
            InlineNode("(substitute_statement) @tmp_capture"),
        },
        ident_with_type = {},
        function_body = {},
        return_values = {},
        caller_args = {},
        return_statement = {},
        function_references = {},
        should_check_parent_node_print_var = function(node)
            if node:type() ~= "identifier" then
                return false
            end

            local prev = node:prev_named_sibling()
            if not prev or prev:type() ~= "scope" then
                return false
            end

            local parent = node:parent()
            if not parent or parent:type() ~= "scoped_identifier" then
                return false
            end

            return true
        end,
    }
    local ts = TreeSitter:new(config, bufnr)

    return ts
end

return Vim
