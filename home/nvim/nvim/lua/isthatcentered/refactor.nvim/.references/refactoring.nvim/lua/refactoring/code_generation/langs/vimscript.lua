---@type refactor.CodeGeneration
local vim = {}

vim.comment = function(statement)
    return ('" %s'):format(statement)
end

vim.print = function(opts)
    return opts.statement:format(opts.content)
end
vim.default_printf_statement = function()
    return { "echom '%s'|" }
end

vim.print_var = function(opts)
    return opts.statement:format(opts.prefix, opts.var)
end
vim.default_print_var_statement = function()
    return { "echom '%s' %s|" }
end

return vim
