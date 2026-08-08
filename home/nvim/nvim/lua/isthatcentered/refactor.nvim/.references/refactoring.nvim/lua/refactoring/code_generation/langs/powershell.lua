---@type refactor.CodeGeneration
local powershell = {}

powershell.comment = function(statement)
    return ("# %s"):format(statement)
end

powershell.print = function(opts)
    return opts.statement:format(opts.content)
end
powershell.default_printf_statement = function()
    return { "Write-Host '%s'" }
end

powershell.print_var = function(opts)
    return opts.statement:format(opts.prefix, opts.var)
end
powershell.default_print_var_statement = function()
    return { "Write-Host '%s' %s" }
end

return powershell
