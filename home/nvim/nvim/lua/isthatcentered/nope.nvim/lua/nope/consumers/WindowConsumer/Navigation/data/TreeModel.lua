---@class TreeNode
---@field id string
---@field type "root"|"header"|"file"|"suite"|"test"
---@field node any|nil -- raw FileNode|SuiteNode|TestNode
---@field file_path string
---@field children TreeNode[]
---@field _depth number|nil -- set by flatten()

local M = {}

---Build tree nodes from suites recursively
---@param suites SuiteNode[]
---@param file_path string
---@return TreeNode[]
local function build_suite_nodes(suites, file_path)
  local nodes = {}

  for _, suite in ipairs(suites) do
    local children = {}

    -- Add tests as children
    for _, test in ipairs(suite.tests) do
      table.insert(children, {
        id = test.id,
        type = "test",
        node = test,
        file_path = file_path,
        children = {},
      })
    end

    -- Add nested suites as children
    vim.list_extend(children, build_suite_nodes(suite.suites, file_path))

    table.insert(nodes, {
      id = suite.id,
      type = "suite",
      node = suite,
      file_path = file_path,
      children = children,
    })
  end

  return nodes
end

---Build tree from TestRunState
---@param state TestRunState
---@param show_only_failures boolean|nil (unused, kept for API compatibility)
---@return TreeNode root
function M.build(state, show_only_failures)
  _ = show_only_failures -- unused, display formatting moved to UI layer
  local root_children = {}

  -- Add header as first child
  table.insert(root_children, {
    id = "__header__",
    type = "header",
    node = { status = state.status, summary = state.summary, duration_ms = state.duration_ms },
    file_path = "",
    children = {},
  })

  -- Add file nodes
  for _, file in ipairs(state.files) do
    local file_children = {}

    -- Add top-level tests
    for _, test in ipairs(file.tests) do
      table.insert(file_children, {
        id = test.id,
        type = "test",
        node = test,
        file_path = file.path,
        children = {},
      })
    end

    -- Add suites
    vim.list_extend(file_children, build_suite_nodes(file.suites, file.path))

    table.insert(root_children, {
      id = file.id,
      type = "file",
      node = file,
      file_path = file.path,
      children = file_children,
    })
  end

  return {
    id = "__root__",
    type = "root",
    node = nil,
    file_path = "",
    children = root_children,
  }
end

---Find node by id in tree
---@param root TreeNode
---@param id string
---@return TreeNode|nil
function M.find_by_id(root, id)
  if root.id == id then
    return root
  end
  for _, child in ipairs(root.children) do
    local found = M.find_by_id(child, id)
    if found then
      return found
    end
  end
  return nil
end

---Flatten tree to array (for rendering)
---@param root TreeNode
---@return TreeNode[] nodes, table<string, number> id_to_line
function M.flatten(root)
  local nodes = {}
  local id_to_line = {}

  local function walk(node, depth)
    -- Skip root node itself
    if node.type ~= "root" then
      table.insert(nodes, node)
      node._depth = depth
      id_to_line[node.id] = #nodes
    end

    for _, child in ipairs(node.children) do
      walk(child, node.type == "root" and 0 or depth + 1)
    end
  end

  walk(root, 0)
  return nodes, id_to_line
end

---Find test by file path and test name
---@param root TreeNode
---@param file_path string exact relative path
---@param test_name string matches node.name or node.full_name
---@return TreeNode|nil test_node, string[]|nil ancestor_ids
function M.find_test_by_file_and_name(root, file_path, test_name)
  ---@param node TreeNode
  ---@param ancestors string[]
  ---@return TreeNode|nil, string[]|nil
  local function search(node, ancestors)
    -- Check if this is the target test
    if node.type == "test" and node.file_path == file_path then
      local test = node.node
      if test and (test.name == test_name or test.full_name == test_name) then
        return node, ancestors
      end
    end

    -- Build new ancestors list for children
    local new_ancestors = ancestors
    if node.type == "file" or node.type == "suite" then
      new_ancestors = vim.list_extend({}, ancestors)
      table.insert(new_ancestors, node.id)
    end

    -- Search children
    for _, child in ipairs(node.children) do
      local found, found_ancestors = search(child, new_ancestors)
      if found then
        return found, found_ancestors
      end
    end

    return nil, nil
  end

  return search(root, {})
end

---Check if a node or any descendant has failed status
---@param node TreeNode
---@return boolean
local function has_failure(node)
  if node.node and node.node.status == "failed" then
    return true
  end
  for _, child in ipairs(node.children) do
    if has_failure(child) then
      return true
    end
  end
  return false
end

---Filter tree to only show failing tests and their ancestors
---@param root TreeNode
---@return TreeNode filtered_root
function M.filter_failures(root)
  local function filter_node(node)
    -- Always keep header
    if node.type == "header" then
      return node
    end

    -- For tests: only keep if failed
    if node.type == "test" then
      if node.node and node.node.status == "failed" then
        return {
          id = node.id,
          type = node.type,
          node = node.node,
          file_path = node.file_path,
          children = {},
          _depth = node._depth,
        }
      end
      return nil
    end

    -- For files/suites: filter children and keep if any remain
    local filtered_children = {}
    for _, child in ipairs(node.children) do
      local filtered = filter_node(child)
      if filtered then
        table.insert(filtered_children, filtered)
      end
    end

    if #filtered_children > 0 then
      return {
        id = node.id,
        type = node.type,
        node = node.node,
        file_path = node.file_path,
        children = filtered_children,
        _depth = node._depth,
      }
    end

    return nil
  end

  -- Filter root's children
  local filtered_children = {}
  for _, child in ipairs(root.children) do
    local filtered = filter_node(child)
    if filtered then
      table.insert(filtered_children, filtered)
    end
  end

  return {
    id = root.id,
    type = root.type,
    node = root.node,
    file_path = root.file_path,
    children = filtered_children,
  }
end

---Filter tree to a specific scope (file/suite/test)
---@param root TreeNode
---@param scope_id string the id of the node to filter to
---@return TreeNode|nil filtered root, or nil if scope_id not found
function M.filter_by_scope(root, scope_id)
  -- Find the target node
  local target = M.find_by_id(root, scope_id)
  if not target then
    return nil
  end

  -- Get header from original root
  local header = nil
  for _, child in ipairs(root.children) do
    if child.type == "header" then
      header = child
      break
    end
  end

  -- Build new root with header + target (preserving target's children)
  return {
    id = root.id,
    type = root.type,
    node = root.node,
    file_path = root.file_path,
    children = { header, target },
  }
end

---Get breadcrumb path for a node
---@param root TreeNode
---@param target_id string
---@return string[] breadcrumb names from file to target
function M.get_breadcrumb(root, target_id)
  ---@param node TreeNode
  ---@param path string[]
  ---@return string[]|nil
  local function search(node, path)
    -- Build name for this node
    local name = nil
    if node.type == "file" then
      name = node.file_path:match("([^/]+)$") or node.file_path
    elseif node.type == "suite" and node.node then
      name = node.node.name
    elseif node.type == "test" and node.node then
      name = node.node.name
    end

    -- Add to path if has name
    local new_path = path
    if name then
      new_path = vim.list_extend({}, path)
      table.insert(new_path, name)
    end

    -- Found target
    if node.id == target_id then
      return new_path
    end

    -- Search children
    for _, child in ipairs(node.children) do
      local result = search(child, new_path)
      if result then
        return result
      end
    end

    return nil
  end

  return search(root, {}) or {}
end

return M
