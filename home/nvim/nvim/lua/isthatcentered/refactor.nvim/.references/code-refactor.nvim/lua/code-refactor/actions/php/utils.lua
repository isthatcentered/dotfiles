local ts_utils = require("nvim-treesitter.ts_utils")

local M = {}

M.get_outer_scope_variables = function(func_node)
  local bufnr = vim.api.nvim_get_current_buf()

  local used_vars = {}
  local declared_vars = {}

  local function collect_vars(node)
    if not node then
      return
    end
    local node_type = node:type()

    -- Collect parameters
    if node_type == "simple_parameter" then
      local var_node = node:field("name")[1]
      if var_node then
        local var_name = vim.treesitter.get_node_text(var_node, bufnr)
        declared_vars[var_name] = true
      end
    end

    -- Collect variable assignments (local variables)
    if node_type == "assignment_expression" then
      local left = node:child(0)
      if left and left:type() == "variable_name" then
        local var_name = vim.treesitter.get_node_text(left, bufnr)
        declared_vars[var_name] = true
      end
    end

    -- Collect variable usages
    if node_type == "variable_name" then
      local var_name = vim.treesitter.get_node_text(node, bufnr)
      used_vars[var_name] = true
    end

    -- Recurse into child nodes
    for child in node:iter_children() do
      collect_vars(child)
    end
  end

  -- Collect variables that are used but not defined in the function
  collect_vars(func_node)

  -- Subtract declared variables from used variables
  local outer_vars = {}
  for var_name, _ in pairs(used_vars) do
    if not declared_vars[var_name] then
      outer_vars[var_name] = true
    end
  end

  return vim.tbl_keys(outer_vars)
end

M.get_single_statement_function_body = function(body_node)
  if not body_node or body_node:type() ~= "compound_statement" then
    return false, nil
  end

  local first_named_child = body_node:named_child(0)
  if not first_named_child then
    return false, nil
  end

  if first_named_child:type() == "return_statement" then
    return true, vim.treesitter.get_node_text(first_named_child:child(1), 0)
  end

  if first_named_child:type() ~= "expression_statement" then
    return false, nil
  end

  if body_node:named_child_count() ~= 1 then
    return false, nil
  end

  return true, vim.treesitter.get_node_text(first_named_child, 0):gsub(";$", "")
end

M.get_function_node_at_cursor = function()
  local node = ts_utils.get_node_at_cursor()

  -- 'function' means non-arrow anonymous function
  while
    node ~= nil
    and node:type() ~= "function_definition"
    and node:type() ~= "anonymous_function"
    and node:type() ~= "arrow_function"
  do
    node = node:parent()
  end

  if node == nil then
    return nil
  end

  return node
end

M.get_function_info_from_node = function(node)
  if
    node:type() ~= "function_definition"
    and node:type() ~= "anonymous_function"
    and node:type() ~= "arrow_function"
  then
    return nil
  end

  -- Extract the function name, and body, and rest.
  local func_name, params, return_type, body

  local name_node = node:field("name")[1]
  local params_node = node:field("parameters")[1]
  local return_type_node = node:field("return_type")[1]
  local body_node = node:field("body")[1]

  if not params_node or not body_node then
    return nil
  end

  local buf = vim.api.nvim_get_current_buf()
  if name_node then
    func_name = vim.treesitter.get_node_text(name_node, buf)
  end
  params = vim.treesitter.get_node_text(params_node, buf)
  if return_type_node then
    return_type = vim.treesitter.get_node_text(return_type_node, buf)
  end
  body = vim.treesitter.get_node_text(body_node, buf)

  local start_row, start_col, end_row, end_col = node:range()

  local outer_scope_vars = M.get_outer_scope_variables(node)

  return {
    func_name = func_name,
    params = params,
    return_type = return_type,
    body = body,
    outer_scope_vars = outer_scope_vars,
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
  }
end

return M
