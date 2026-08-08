local TreeSitter = require("refactoring.treesitter.treesitter")

local Nodes = require("refactoring.treesitter.nodes")
local InlineNode = Nodes.InlineNode
local StringNode = Nodes.StringNode
local QueryNode = Nodes.QueryNode

---@class refactor.TreeSitterInstance
local Powershell = {}

function Powershell.new(bufnr, ft)
    ---@type refactor.TreeSitterLanguageConfig
    local config = {
        filetype = ft,
        bufnr = bufnr,
        scope_names = {},
        block_scope = {},
        variable_scope = {},
        indent_scopes = {
            if_statement = true,
            class_method_definition = true,
            function_statement = true,
            class_statement = true,
            trap_statement = true,
            try_statement = true,
            data_statement = true,
            inlinescript_statement = true,
            parallel_statement = true,
            sequence_statement = true,
        },
        valid_class_nodes = {},
        local_var_names = {},
        function_args = {},
        local_var_values = {},
        local_declarations = {},
        debug_paths = {
            if_statement = StringNode("if"),
            class_method_definition = QueryNode(
                "(class_method_definition (simple_name) @name)"
            ),
            function_statement = QueryNode(
                "(function_statement (function_name) @name)"
            ),
            class_statement = QueryNode(
                "(class_statement . (simple_name) @name)"
            ),
            trap_statement = StringNode("trap"),
            try_statement = StringNode("try"),
            data_statement = StringNode("data"),
            inlinescript_statement = StringNode("inlinescript"),
            parallel_statement = StringNode("parallel"),
            sequence_statement = StringNode("sequence"),
        },
        statements = {
            InlineNode("(pipeline) @tmp_capture"),
            InlineNode("(if_statement) @tmp_capture"),
            InlineNode("(function_statement) @tmp_capture"),
            InlineNode("(class_statement) @tmp_capture"),
            InlineNode("(enum_statement) @tmp_capture"),
            InlineNode("(trap_statement) @tmp_capture"),
            InlineNode("(try_statement) @tmp_capture"),
            InlineNode("(data_statement) @tmp_capture"),
            InlineNode("(inlinescript_statement) @tmp_capture"),
            InlineNode("(parallel_statement) @tmp_capture"),
            InlineNode("(sequence_statement) @tmp_capture"),
            InlineNode("(empty_statement) @tmp_capture"),
            InlineNode("(param_block) @tmp_capture"),
        },
        ident_with_type = {},
        function_body = {},
        return_values = {},
        caller_args = {},
        return_statement = {},
        function_references = {},
    }
    local ts = TreeSitter:new(config, bufnr)

    return ts
end

return Powershell
