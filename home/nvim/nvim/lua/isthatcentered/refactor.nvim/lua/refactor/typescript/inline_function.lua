local api = vim.api

local M = {}

local SUPPORTED_FILETYPES = {
	typescript = "typescript",
	typescriptreact = "tsx",
}

local FUNCTION_BODY_ERROR = "Inline function only supports functions with an expression body or a single return statement"
local PARAMETER_ERROR = "Inline function only supports required identifier parameters"
local DECLARATION_ERROR = "Inline function only supports function declarations and standalone const function values"
local METHOD_ERROR = "Inline function does not support class or object methods yet"
local NON_CALL_USAGE_ERROR = "Inline function found non-call usages for '%s'"
local NO_CALL_SITES_ERROR = "Inline function found no call sites in the current buffer"
local THIS_OR_SUPER_ERROR = "Inline function does not support this or super in the inlined body yet"
local OBJECT_ARGUMENT_KEY_ERROR = "Inline function only supports object arguments with static identifier keys"
local OBJECT_ARGUMENT_SPREAD_ERROR = "Inline function does not support spread properties in object arguments yet"
local OBJECT_ARGUMENT_DUPLICATE_KEY_ERROR = "Inline function found duplicate object argument key '%s'"
local OBJECT_ARGUMENT_PROPERTY_ERROR = "Inline function could not resolve property '%s' from object argument for parameter '%s'"
local OBJECT_ARGUMENT_BRACKET_ERROR = "Inline function does not support bracket property access for object-argument parameters yet"
local OMITTED_DESTRUCTURED_OPTIONAL_ERROR = "Inline function does not support omitted optional destructured parameters yet"
local TYPE_ARGUMENT_ERROR = "Inline function expected %d type arguments but found %d"
local LOCAL_SCOPE_CAPTURE = "local.scope"
local LOCAL_DEFINITION_PREFIX = "local.definition"

local SAFE_CALLEE_NODE_TYPES = {
	call_expression = true,
	identifier = true,
	member_expression = true,
	new_expression = true,
	parenthesized_expression = true,
	subscript_expression = true,
	super = true,
	this = true,
}

local SAFE_MEMBER_OBJECT_NODE_TYPES = {
	call_expression = true,
	identifier = true,
	member_expression = true,
	new_expression = true,
	parenthesized_expression = true,
	subscript_expression = true,
	super = true,
	this = true,
}

local DEFAULT_WRAPPED_NODE_TYPES = {
	arrow_function = true,
	assignment_expression = true,
	await_expression = true,
	binary_expression = true,
	ternary_expression = true,
	object = true,
	sequence_expression = true,
	yield_expression = true,
}

local function raise(message)
	error("Refactor: " .. message, 0)
end

local function parser_language_for(filetype)
	return SUPPORTED_FILETYPES[filetype]
end

local function ensure_parser(bufnr, lang)
	vim.treesitter.start(bufnr, lang)
	vim.treesitter.get_parser(bufnr, lang):parse()
end

local function validate_context(context)
	if type(context) ~= "table" then
		raise("Context is required")
	end

	if context.buffer_id == nil then
		raise("Context buffer_id is required")
	end

	if type(context.cursor_position) ~= "table" then
		raise("Context cursor_position is required")
	end

	if type(context.cursor_position.line) ~= "number" then
		raise("Context cursor_position.line is required")
	end

	if type(context.cursor_position.column) ~= "number" then
		raise("Context cursor_position.column is required")
	end
end

local function resolve_buffer_id(buffer_id)
	if buffer_id == 0 then
		return api.nvim_get_current_buf()
	end

	return buffer_id
end

local function node_text(node, source)
	return vim.treesitter.get_node_text(node, source)
end

local function has_child_type(node, child_type)
	for child in node:iter_children() do
		if child:type() == child_type then
			return true
		end
	end

	return false
end

local function same_node(left, right)
	return left ~= nil and right ~= nil and left:id() == right:id()
end

local function root_for_node(node)
	local current = node

	while current ~= nil and current:parent() ~= nil do
		current = current:parent()
	end

	return current
end

local function compare_ranges_desc(left, right)
	if left.start_row ~= right.start_row then
		return left.start_row > right.start_row
	end

	return left.start_col > right.start_col
end

local function position_before(line, col, other_line, other_col)
	return line < other_line or (line == other_line and col < other_col)
end

local function collect_named_children(node)
	local children = {}

	for index = 0, node:named_child_count() - 1 do
		children[#children + 1] = node:named_child(index)
	end

	return children
end

local function split_lines(text)
	return vim.split(text, "\n", { plain = true })
end

local function build_line_start_offsets(text)
	local lines = split_lines(text)
	local offsets = {}
	local total = 0

	for index, line in ipairs(lines) do
		offsets[index] = total
		total = total + #line + 1
	end

	return lines, offsets
end

local function relative_offset(line_offsets, base_start_row, base_start_col, row, col)
	local row_delta = row - base_start_row
	if row_delta == 0 then
		return col - base_start_col
	end

	return line_offsets[row_delta + 1] + col
end

local function normalize_multiline_indentation(lines)
	if #lines <= 1 then
		return lines
	end

	local common_indent = nil

	for index = 2, #lines do
		local line = lines[index]
		if not line:match("^%s*$") then
			local indent = #(line:match("^(%s*)"))
			if common_indent == nil or indent < common_indent then
				common_indent = indent
			end
		end
	end

	if common_indent == nil or common_indent == 0 then
		return lines
	end

	local normalized = { lines[1] }

	for index = 2, #lines do
		local line = lines[index]
		if line:match("^%s*$") then
			normalized[index] = ""
		else
			normalized[index] = line:sub(common_indent + 1)
		end
	end

	return normalized
end

local function parse_type_parameters(function_node, bufnr)
	local type_parameter_names = {}
	local type_parameters_node = function_node:field("type_parameters")[1]
	if type_parameters_node == nil then
		return type_parameter_names
	end

	for _, type_parameter_node in ipairs(collect_named_children(type_parameters_node)) do
		if type_parameter_node:type() ~= "type_parameter" then
			raise(PARAMETER_ERROR)
		end

		local name_node = type_parameter_node:named_child(0)
		if name_node == nil or name_node:type() ~= "type_identifier" then
			raise(PARAMETER_ERROR)
		end

		type_parameter_names[#type_parameter_names + 1] = node_text(name_node, bufnr)
	end

	return type_parameter_names
end

local function parse_parameters(parameters_node, bufnr)
	local parameter_names = {}
	local parameter_definitions = {}
	local parameter_argument_indexes = {}
	local parameter_property_names = {}
	local argument_count = 0
	local minimum_argument_count = 0
	local saw_optional_parameter = false

	for _, parameter_node in ipairs(collect_named_children(parameters_node)) do
		local parameter_type = parameter_node:type()
		if parameter_type ~= "required_parameter" and parameter_type ~= "optional_parameter" then
			raise(PARAMETER_ERROR)
		end

		local is_optional = parameter_type == "optional_parameter"
		if is_optional then
			saw_optional_parameter = true
		elseif saw_optional_parameter then
			raise(PARAMETER_ERROR)
		end

		argument_count = argument_count + 1
		if not is_optional then
			minimum_argument_count = argument_count
		end

		local binding_node = parameter_node:named_child(0)
		if binding_node == nil then
			raise(PARAMETER_ERROR)
		end

		for index = 1, parameter_node:named_child_count() - 1 do
			local child = parameter_node:named_child(index)
			if child:type() ~= "type_annotation" then
				raise(PARAMETER_ERROR)
			end
		end

		if binding_node:type() == "identifier" then
			local parameter_name = node_text(binding_node, bufnr)
			parameter_names[#parameter_names + 1] = parameter_name
			parameter_definitions[parameter_name] = binding_node
			parameter_argument_indexes[parameter_name] = argument_count
		elseif binding_node:type() == "object_pattern" then
			for _, property_node in ipairs(collect_named_children(binding_node)) do
				if property_node:type() ~= "shorthand_property_identifier_pattern" then
					raise(PARAMETER_ERROR)
				end

				local parameter_name = node_text(property_node, bufnr)
				parameter_names[#parameter_names + 1] = parameter_name
				parameter_definitions[parameter_name] = property_node
				parameter_argument_indexes[parameter_name] = argument_count
				parameter_property_names[parameter_name] = parameter_name
			end
		else
			raise(PARAMETER_ERROR)
		end
	end

	return parameter_names, parameter_definitions, parameter_argument_indexes, parameter_property_names, minimum_argument_count, argument_count
end

local function expression_body_from(function_node)
	local body_node = function_node:field("body")[1]
	if body_node == nil then
		raise(FUNCTION_BODY_ERROR)
	end

	if function_node:type() == "arrow_function" and body_node:type() ~= "statement_block" then
		return body_node
	end

	if body_node:type() ~= "statement_block" then
		raise(FUNCTION_BODY_ERROR)
	end

	local statements = collect_named_children(body_node)
	if #statements ~= 1 or statements[1]:type() ~= "return_statement" then
		raise(FUNCTION_BODY_ERROR)
	end

	local return_value = statements[1]:named_child(0)
	if return_value == nil then
		raise(FUNCTION_BODY_ERROR)
	end

	return return_value
end

local function validate_expression_body(expression_node)
	local function visit(node)
		local node_type = node:type()

		if node_type == "this" or node_type == "super" then
			raise(THIS_OR_SUPER_ERROR)
		end

		for child in node:iter_children() do
			visit(child)
		end
	end

	visit(expression_node)
end

local function const_keyword_text(declaration_node, bufnr)
	local keyword_node = declaration_node:child(0)
	if keyword_node == nil then
		return nil
	end

	return node_text(keyword_node, bufnr)
end

local function variable_declarator_is_supported_candidate(variable_declarator, bufnr)
	local declaration_node = variable_declarator:parent()
	if declaration_node == nil or declaration_node:type() ~= "lexical_declaration" then
		return false
	end

	if declaration_node:named_child_count() ~= 1 or const_keyword_text(declaration_node, bufnr) ~= "const" then
		return false
	end

	local name_node = variable_declarator:field("name")[1]
	local value_node = variable_declarator:field("value")[1]
	if name_node == nil or name_node:type() ~= "identifier" or value_node == nil then
		return false
	end

	local value_type = value_node:type()
	return value_type == "arrow_function" or value_type == "function_expression"
end

local function build_variable_target(variable_declarator, bufnr)
	if not variable_declarator_is_supported_candidate(variable_declarator, bufnr) then
		raise(DECLARATION_ERROR)
	end

	local declaration_node = variable_declarator:parent()
	local name_node = variable_declarator:field("name")[1]
	local value_node = variable_declarator:field("value")[1]

	if has_child_type(value_node, "async") then
		raise("Inline function does not support async functions yet")
	end

	local parameters_node = value_node:field("parameters")[1]
	if parameters_node == nil then
		raise(DECLARATION_ERROR)
	end

	local expression_node = expression_body_from(value_node)
	validate_expression_body(expression_node)
	local parameter_names, parameter_definitions, parameter_argument_indexes, parameter_property_names, minimum_argument_count, argument_count = parse_parameters(parameters_node, bufnr)

	return {
		argument_count = argument_count,
		declaration_node = declaration_node,
		expression_node = expression_node,
		minimum_argument_count = minimum_argument_count,
		name = node_text(name_node, bufnr),
		name_node = name_node,
		parameter_argument_indexes = parameter_argument_indexes,
		parameter_definitions = parameter_definitions,
		parameter_names = parameter_names,
		parameter_property_names = parameter_property_names,
		type_parameter_names = parse_type_parameters(value_node, bufnr),
	}
end

local function build_function_declaration_target(function_node, bufnr)
	if has_child_type(function_node, "async") then
		raise("Inline function does not support async functions yet")
	end

	local name_node = function_node:field("name")[1]
	local parameters_node = function_node:field("parameters")[1]
	if name_node == nil or name_node:type() ~= "identifier" or parameters_node == nil then
		raise(DECLARATION_ERROR)
	end

	local expression_node = expression_body_from(function_node)
	validate_expression_body(expression_node)
	local parameter_names, parameter_definitions, parameter_argument_indexes, parameter_property_names, minimum_argument_count, argument_count = parse_parameters(parameters_node, bufnr)

	return {
		argument_count = argument_count,
		declaration_node = function_node,
		expression_node = expression_node,
		minimum_argument_count = minimum_argument_count,
		name = node_text(name_node, bufnr),
		name_node = name_node,
		parameter_argument_indexes = parameter_argument_indexes,
		parameter_definitions = parameter_definitions,
		parameter_names = parameter_names,
		parameter_property_names = parameter_property_names,
		type_parameter_names = parse_type_parameters(function_node, bufnr),
	}
end

local function collect_local_definitions(root, bufnr, lang)
	local query = vim.treesitter.query.get(lang, "locals")
	if query == nil then
		return {}, {}
	end

	local scope_lookup = {}
	local definitions = {}

	for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
		local capture_name = query.captures[id]

		if node ~= nil and capture_name == LOCAL_SCOPE_CAPTURE then
			scope_lookup[node:id()] = node
		end

		if node ~= nil and vim.startswith(capture_name, LOCAL_DEFINITION_PREFIX) then
			local scope_type = "local"
			for key, value in pairs(metadata or {}) do
				if type(key) == "string" and vim.endswith(key, LOCAL_SCOPE_CAPTURE) then
					scope_type = value
					break
				end
			end

			definitions[#definitions + 1] = {
				node = node,
				scope_type = scope_type,
				text = node_text(node, bufnr),
			}
		end
	end

	return definitions, scope_lookup
end

local function containing_scope(node, scope_lookup)
	local current = node

	while current ~= nil do
		if scope_lookup[current:id()] ~= nil then
			return current
		end

		current = current:parent()
	end
end

local function scope_tree(node, scope_lookup)
	local scopes = {}
	local root = root_for_node(node)
	local last_node = node

	while last_node ~= nil do
		local scope = containing_scope(last_node, scope_lookup) or root
		scopes[#scopes + 1] = scope

		if same_node(scope, root) then
			break
		end

		last_node = scope:parent()
	end

	return scopes
end

local function definition_visible_scope_ids(definition, scope_lookup)
	local definition_scopes = scope_tree(definition.node, scope_lookup)
	local visible_scope_ids = {}
	local max_index = 1

	if definition.scope_type == "parent" then
		max_index = math.min(2, #definition_scopes)
	elseif definition.scope_type == "global" then
		max_index = #definition_scopes
	end

	for index = 1, max_index do
		visible_scope_ids[definition_scopes[index]:id()] = true
	end

	return visible_scope_ids
end

local function find_definition(node, root, bufnr, lang)
	if vim.treesitter.query.get(lang, "locals") == nil then
		return nil
	end

	local current_name = node_text(node, bufnr)

	local definitions, scope_lookup = collect_local_definitions(root, bufnr, lang)
	local scopes = scope_tree(node, scope_lookup)

	for _, scope in ipairs(scopes) do
		for _, definition in ipairs(definitions) do
			if definition.text == current_name then
				local visible_scope_ids = definition.visible_scope_ids
				if visible_scope_ids == nil then
					visible_scope_ids = definition_visible_scope_ids(definition, scope_lookup)
					definition.visible_scope_ids = visible_scope_ids
				end

				if visible_scope_ids[scope:id()] then
					return definition.node
				end
			end
		end
	end
end

local function declaration_target_from_node(node, bufnr)
	local saw_method_definition = false

	while node do
		local node_type = node:type()

		if node_type == "method_definition" then
			saw_method_definition = true
		elseif node_type == "function_declaration" then
			return build_function_declaration_target(node, bufnr)
		elseif node_type == "variable_declarator" and variable_declarator_is_supported_candidate(node, bufnr) then
			return build_variable_target(node, bufnr)
		elseif node_type == "arrow_function" or node_type == "function_expression" then
			local parent = node:parent()
			if parent ~= nil and variable_declarator_is_supported_candidate(parent, bufnr) then
				return build_variable_target(parent, bufnr)
			end
		end

		node = node:parent()
	end

	if saw_method_definition then
		raise(METHOD_ERROR)
	end
end

local function direct_call_identifier_from_node(node)
	local current = node

	while current ~= nil do
		if current:type() == "identifier" then
			local parent = current:parent()
			if parent ~= nil and parent:type() == "call_expression" then
				local callee_node = parent:field("function")[1]
				if same_node(callee_node, current) then
					return current
				end
			end
		end

		current = current:parent()
	end
end

local function target_from_definition_node(definition_node, bufnr)
	local current = definition_node

	while current ~= nil do
		local node_type = current:type()

		if node_type == "method_definition" then
			raise(METHOD_ERROR)
		end

		if node_type == "function_declaration" then
			return build_function_declaration_target(current, bufnr)
		end

		if node_type == "variable_declarator" and variable_declarator_is_supported_candidate(current, bufnr) then
			return build_variable_target(current, bufnr)
		end

		current = current:parent()
	end
end

local function find_target_function(bufnr, lang, cursor_position)
	local root = vim.treesitter.get_parser(bufnr, lang):parse()[1]:root()
	local node = vim.treesitter.get_node({
		bufnr = bufnr,
		lang = lang,
		pos = { cursor_position.line, cursor_position.column },
	})

	local call_identifier = direct_call_identifier_from_node(node)
	if call_identifier ~= nil then
		local definition = find_definition(call_identifier, root, bufnr, lang)
		if definition ~= nil and not same_node(definition, call_identifier) then
			local target = target_from_definition_node(definition, bufnr)
			if target ~= nil then
				return target
			end
		end
	end

	local declaration_target = declaration_target_from_node(node, bufnr)
	if declaration_target ~= nil then
		return declaration_target
	end

	raise("Cursor is not inside a supported function")
end

local function traverse(node, callback)
	callback(node)

	for child in node:iter_children() do
		traverse(child, callback)
	end
end

local function is_direct_call_identifier(identifier_node)
	local parent = identifier_node:parent()
	if parent == nil or parent:type() ~= "call_expression" then
		return false
	end

	local callee_node = parent:field("function")[1]
	return same_node(callee_node, identifier_node)
end

local function gather_call_sites(root, target, bufnr)
	local call_sites = {}
	local has_non_call_usage = false

	traverse(root, function(node)
		if node:type() ~= "identifier" then
			return
		end

		if node_text(node, bufnr) ~= target.name or same_node(node, target.name_node) then
			return
		end

		if is_direct_call_identifier(node) then
			call_sites[#call_sites + 1] = node:parent()
			return
		end

		has_non_call_usage = true
	end)

	if has_non_call_usage then
		raise(NON_CALL_USAGE_ERROR:format(target.name))
	end

	if #call_sites == 0 then
		raise(NO_CALL_SITES_ERROR)
	end

	local declaration_start_row, declaration_start_col, declaration_end_row, declaration_end_col = target.declaration_node:range()
	for _, call_site in ipairs(call_sites) do
		local start_row, start_col, end_row, end_col = call_site:range()
		local starts_after_declaration = start_row > declaration_start_row or (start_row == declaration_start_row and start_col >= declaration_start_col)
		local ends_before_declaration = end_row < declaration_end_row or (end_row == declaration_end_row and end_col <= declaration_end_col)
		if starts_after_declaration and ends_before_declaration then
			raise("Inline function does not support recursive functions yet")
		end
	end

	return call_sites
end

local function build_object_argument_lookup(argument_node, bufnr)
	if argument_node:type() ~= "object" then
		return nil
	end

	local properties = {}
	local ordered_entries = {}
	local spread_count = 0

	for _, child in ipairs(collect_named_children(argument_node)) do
		local child_type = child:type()

		if child_type == "spread_element" then
			spread_count = spread_count + 1
			if spread_count > 1 then
				raise(OBJECT_ARGUMENT_SPREAD_ERROR)
			end

			local source_node = child:named_child(0)
			if source_node == nil or not SAFE_MEMBER_OBJECT_NODE_TYPES[source_node:type()] then
				raise(OBJECT_ARGUMENT_SPREAD_ERROR)
			end

			ordered_entries[#ordered_entries + 1] = {
				node = source_node,
				text = node_text(source_node, bufnr),
				type = "spread",
			}
		elseif child_type == "shorthand_property_identifier" then
			local property_name = node_text(child, bufnr)
			if properties[property_name] ~= nil then
				raise(OBJECT_ARGUMENT_DUPLICATE_KEY_ERROR:format(property_name))
			end

			local property = {
				name = property_name,
				node = child,
				text = property_name,
				type = "property",
			}
			properties[property_name] = property
			ordered_entries[#ordered_entries + 1] = property
		elseif child_type == "pair" then
			local key_node = child:named_child(0)
			local value_node = child:named_child(1)
			if key_node == nil or key_node:type() ~= "property_identifier" or value_node == nil then
				raise(OBJECT_ARGUMENT_KEY_ERROR)
			end

			local property_name = node_text(key_node, bufnr)
			if properties[property_name] ~= nil then
				raise(OBJECT_ARGUMENT_DUPLICATE_KEY_ERROR:format(property_name))
			end

			local property = {
				name = property_name,
				node = value_node,
				text = node_text(value_node, bufnr),
				type = "property",
			}
			properties[property_name] = property
			ordered_entries[#ordered_entries + 1] = property
		else
			raise(OBJECT_ARGUMENT_KEY_ERROR)
		end
	end

	return {
		entries = ordered_entries,
		properties = properties,
	}
end

local function collect_type_arguments(call_expression, bufnr)
	local type_arguments_node = call_expression:field("type_arguments")[1]
	local type_arguments = {}

	if type_arguments_node ~= nil then
		for _, child in ipairs(collect_named_children(type_arguments_node)) do
			type_arguments[#type_arguments + 1] = {
				node = child,
				text = node_text(child, bufnr),
			}
		end
	end

	return type_arguments
end

local function collect_arguments(call_expression, minimum_argument_count, parameter_count, bufnr)
	local arguments_node = call_expression:field("arguments")[1]
	if arguments_node == nil then
		raise("Inline function only supports standard call expressions")
	end

	local arguments = {}
	for _, child in ipairs(collect_named_children(arguments_node)) do
		if child:type() == "spread_element" then
			raise("Inline function does not support spread arguments yet")
		end

		arguments[#arguments + 1] = {
			node = child,
			object_properties = build_object_argument_lookup(child, bufnr),
			text = node_text(child, bufnr),
		}
	end

	if #arguments < minimum_argument_count or #arguments > parameter_count then
		local expected_argument_count = tostring(parameter_count)
		if minimum_argument_count == parameter_count then
			raise(("Inline function expected %s arguments but found %d"):format(expected_argument_count, #arguments))
		end

		expected_argument_count = ("%d to %d"):format(minimum_argument_count, parameter_count)
		raise(("Inline function expected %s arguments but found %d"):format(expected_argument_count, #arguments))
	end

	return arguments
end

local function node_is_named_child(parent, index, node)
	return parent ~= nil and same_node(parent:named_child(index), node)
end

local function should_wrap_replacement(replacement_node, replaced_node)
	local parent = replaced_node:parent()
	if parent == nil or replacement_node:type() == "parenthesized_expression" then
		return false
	end

	local parent_type = parent:type()
	local replacement_type = replacement_node:type()

	if (parent_type == "call_expression" or parent_type == "new_expression") and node_is_named_child(parent, 0, replaced_node) then
		return not SAFE_CALLEE_NODE_TYPES[replacement_type]
	end

	if (parent_type == "member_expression" or parent_type == "subscript_expression") and node_is_named_child(parent, 0, replaced_node) then
		return not SAFE_MEMBER_OBJECT_NODE_TYPES[replacement_type]
	end

	if parent_type == "expression_statement" and replacement_type == "object" then
		return true
	end

	return DEFAULT_WRAPPED_NODE_TYPES[replacement_type] == true
end

local function render_replacement_text(replacement)
	if should_wrap_replacement(replacement.node, replacement.target_node) then
		return "(" .. replacement.text .. ")"
	end

	return replacement.text
end

local function resolve_object_argument_property(argument, parameter_name, property_name)
	if argument.object_properties == nil then
		raise(OBJECT_ARGUMENT_PROPERTY_ERROR:format(property_name, parameter_name))
	end

	for index = #argument.object_properties.entries, 1, -1 do
		local entry = argument.object_properties.entries[index]
		if entry.type == "property" and entry.name == property_name then
			return entry
		end

		if entry.type == "spread" then
			return {
				node = entry.node,
				text = entry.text .. "." .. property_name,
			}
		end
	end

	local property = argument.object_properties.properties[property_name]
	if property == nil then
		raise(OBJECT_ARGUMENT_PROPERTY_ERROR:format(property_name, parameter_name))
	end

	return property
end

local function identifier_resolves_to_parameter(identifier_node, parameter_definitions, root, bufnr, lang)
	local parameter_name = node_text(identifier_node, bufnr)
	local parameter_definition = parameter_definitions[parameter_name]
	if parameter_definition == nil then
		return false
	end

	local definition = find_definition(identifier_node, root, bufnr, lang)
	if definition == nil then
		return true
	end

	return same_node(definition, parameter_definition)
end

local function collect_parameter_replacements(expression_node, parameter_names, parameter_definitions, arguments_by_name, root, bufnr, lang)
	local expression_start_row, expression_start_col = expression_node:range()
	local expression_text = node_text(expression_node, bufnr)
	local _, line_offsets = build_line_start_offsets(expression_text)
	local replacements = {}
	local parameter_lookup = {}

	for _, parameter_name in ipairs(parameter_names) do
		parameter_lookup[parameter_name] = true
	end

	local function add_replacement(node, replacement)
		local start_row, start_col, end_row, end_col = node:range()
		replacements[#replacements + 1] = {
			end_offset = relative_offset(line_offsets, expression_start_row, expression_start_col, end_row, end_col),
			start_offset = relative_offset(line_offsets, expression_start_row, expression_start_col, start_row, start_col),
			text = render_replacement_text({
				node = replacement.node,
				target_node = node,
				text = replacement.text,
			}),
		}
	end

	local function visit(node)
		local node_type = node:type()

		if node_type == "shorthand_property_identifier" then
			local parameter_name = node_text(node, bufnr)
			if parameter_lookup[parameter_name] and identifier_resolves_to_parameter(node, parameter_definitions, root, bufnr, lang) then
				local argument = arguments_by_name[parameter_name]
				local replacement_text = render_replacement_text({
					node = argument.node,
					target_node = node,
					text = argument.text,
				})

				add_replacement(node, {
					node = node,
					text = parameter_name .. ": " .. replacement_text,
				})
			end
			return
		end

		if node_type == "member_expression" then
			local object_node = node:named_child(0)
			local property_node = node:named_child(1)
			if object_node ~= nil and object_node:type() == "identifier" and property_node ~= nil and property_node:type() == "property_identifier" then
				local parameter_name = node_text(object_node, bufnr)
				local argument = arguments_by_name[parameter_name]
				if argument ~= nil and argument.object_properties ~= nil and identifier_resolves_to_parameter(object_node, parameter_definitions, root, bufnr, lang) then
					add_replacement(node, resolve_object_argument_property(argument, parameter_name, node_text(property_node, bufnr)))
					return
				end
			end
		elseif node_type == "subscript_expression" then
			local object_node = node:named_child(0)
			if object_node ~= nil and object_node:type() == "identifier" then
				local argument = arguments_by_name[node_text(object_node, bufnr)]
				if argument ~= nil and argument.object_properties ~= nil then
					raise(OBJECT_ARGUMENT_BRACKET_ERROR)
				end
			end
		elseif node_type == "identifier" then
			local parameter_name = node_text(node, bufnr)
			if parameter_lookup[parameter_name] then
				local parent = node:parent()
				local argument = arguments_by_name[parameter_name]
				if not identifier_resolves_to_parameter(node, parameter_definitions, root, bufnr, lang) then
					return
				end

				if parent ~= nil and (parent:type() == "member_expression" or parent:type() == "subscript_expression") and node_is_named_child(parent, 0, node) then
					if argument ~= nil and argument.object_properties ~= nil then
						return
					end
				end

				add_replacement(node, argument)
				return
			end
		end

		for child in node:iter_children() do
			visit(child)
		end
	end

	visit(expression_node)

	return replacements
end

local function collect_type_parameter_replacements(expression_node, type_arguments_by_name, bufnr)
	local expression_start_row, expression_start_col = expression_node:range()
	local expression_text = node_text(expression_node, bufnr)
	local _, line_offsets = build_line_start_offsets(expression_text)
	local replacements = {}

	local function visit(node)
		if node:type() == "type_identifier" then
			local type_argument = type_arguments_by_name[node_text(node, bufnr)]
			if type_argument ~= nil then
				local start_row, start_col, end_row, end_col = node:range()
				replacements[#replacements + 1] = {
					end_offset = relative_offset(line_offsets, expression_start_row, expression_start_col, end_row, end_col),
					start_offset = relative_offset(line_offsets, expression_start_row, expression_start_col, start_row, start_col),
					text = type_argument.text,
				}
			end
		end

		for child in node:iter_children() do
			visit(child)
		end
	end

	visit(expression_node)

	return replacements
end

local function expression_references_type_parameters(expression_node, type_parameter_names, bufnr)
	local type_parameter_lookup = {}
	local references_type_parameter = false

	for _, type_parameter_name in ipairs(type_parameter_names) do
		type_parameter_lookup[type_parameter_name] = true
	end

	local function visit(node)
		if references_type_parameter then
			return
		end

		if node:type() == "type_identifier" and type_parameter_lookup[node_text(node, bufnr)] then
			references_type_parameter = true
			return
		end

		for child in node:iter_children() do
			visit(child)
		end
	end

	visit(expression_node)

	return references_type_parameter
end

local function apply_replacements(source, replacements)
	table.sort(replacements, function(left, right)
		return left.start_offset > right.start_offset
	end)

	for _, replacement in ipairs(replacements) do
		source = source:sub(1, replacement.start_offset) .. replacement.text .. source:sub(replacement.end_offset + 1)
	end

	return source
end

local function render_multiline_expression(text, call_expression)
	local lines = normalize_multiline_indentation(split_lines(text))
	if #lines == 1 then
		return lines
	end

	local _, start_col = call_expression:range()
	local indent = string.rep(" ", start_col)

	for index = 2, #lines do
		lines[index] = indent .. lines[index]
	end

	return lines
end

local function inline_call_expression(call_expression, target, bufnr)
	local arguments = collect_arguments(call_expression, target.minimum_argument_count, target.argument_count, bufnr)
	local type_arguments = collect_type_arguments(call_expression, bufnr)
	local arguments_by_name = {}
	local type_arguments_by_name = {}
	local root = root_for_node(call_expression)
	local lang = parser_language_for(vim.bo[bufnr].filetype)

	local type_parameter_names = target.type_parameter_names or {}
	if #type_arguments ~= #type_parameter_names then
		local can_infer_type_arguments = #type_arguments == 0 and not expression_references_type_parameters(target.expression_node, type_parameter_names, bufnr)
		if not can_infer_type_arguments then
			raise(TYPE_ARGUMENT_ERROR:format(#type_parameter_names, #type_arguments))
		end
	end

	for index, type_parameter_name in ipairs(type_parameter_names) do
		type_arguments_by_name[type_parameter_name] = type_arguments[index]
	end

	for index, parameter_name in ipairs(target.parameter_names) do
		local argument = arguments[target.parameter_argument_indexes[parameter_name] or index]
		local property_name = target.parameter_property_names[parameter_name]
		if argument == nil then
			if property_name ~= nil then
				raise(OMITTED_DESTRUCTURED_OPTIONAL_ERROR)
			end

			argument = {
				node = target.parameter_definitions[parameter_name],
				text = "undefined",
			}
		end

		if property_name ~= nil then
			arguments_by_name[parameter_name] = resolve_object_argument_property(argument, parameter_name, property_name)
		else
			arguments_by_name[parameter_name] = argument
		end
	end

	local expression_text = node_text(target.expression_node, bufnr)
	local replacements = collect_parameter_replacements(target.expression_node, target.parameter_names, target.parameter_definitions, arguments_by_name, root, bufnr, lang)
	vim.list_extend(replacements, collect_type_parameter_replacements(target.expression_node, type_arguments_by_name, bufnr))
	local inlined_expression = apply_replacements(expression_text, replacements)

	return render_multiline_expression(
		render_replacement_text({
			node = target.expression_node,
			target_node = call_expression,
			text = inlined_expression,
		}),
		call_expression
	)
end

local function declaration_delete_range(bufnr, declaration_node)
	local start_row, start_col, end_row, end_col = declaration_node:range()
	local line_count = api.nvim_buf_line_count(bufnr)
	local start_line = api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
	local end_line = api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]
	local prefix = start_line:sub(1, start_col)
	local suffix = end_line:sub(end_col + 1)

	if prefix:match("^%s*$") and suffix:match("^%s*$") and end_row + 1 < line_count then
		return start_row, 0, end_row + 1, 0
	end

	if prefix:match("^%s*$") and suffix:match("^%s*$") and start_row > 0 then
		local previous_line = api.nvim_buf_get_lines(bufnr, start_row - 1, start_row, false)[1] or ""
		return start_row - 1, #previous_line, end_row, end_col
	end

	return start_row, start_col, end_row, end_col
end

local function apply_text_edits(bufnr, edits)
	table.sort(edits, compare_ranges_desc)

	for _, edit in ipairs(edits) do
		api.nvim_buf_set_text(bufnr, edit.start_row, edit.start_col, edit.end_row, edit.end_col, edit.replacement)
	end
end

local function replacement_end_position(edit)
	local line_count = #edit.replacement
	if line_count == 0 then
		return edit.start_row, edit.start_col
	end

	if line_count == 1 then
		return edit.start_row, edit.start_col + #edit.replacement[1]
	end

	return edit.start_row + line_count - 1, #edit.replacement[line_count]
end

local function map_cursor_through_edit(cursor_position, edit)
	local line = cursor_position.line
	local col = cursor_position.column

	if position_before(line, col, edit.start_row, edit.start_col) then
		return {
			line = line,
			column = col,
		}
	end

	if position_before(line, col, edit.end_row, edit.end_col) then
		return {
			line = edit.start_row,
			column = edit.start_col,
		}
	end

	local replacement_end_row, replacement_end_col = replacement_end_position(edit)
	local line_delta = line - edit.end_row

	if line_delta == 0 then
		return {
			line = replacement_end_row,
			column = replacement_end_col + (col - edit.end_col),
		}
	end

	return {
		line = replacement_end_row + line_delta,
		column = col,
	}
end

local function map_cursor_position(cursor_position, edits)
	local mapped_cursor = {
		line = cursor_position.line,
		column = cursor_position.column,
	}
	local ordered_edits = {}

	for index, edit in ipairs(edits) do
		ordered_edits[index] = edit
	end

	table.sort(ordered_edits, compare_ranges_desc)

	for _, edit in ipairs(ordered_edits) do
		mapped_cursor = map_cursor_through_edit(mapped_cursor, edit)
	end

	return mapped_cursor
end

local function sync_cursor(bufnr, cursor_position)
	if api.nvim_get_current_buf() ~= bufnr then
		return
	end

	local line_count = api.nvim_buf_line_count(bufnr)
	local target_row = math.min(cursor_position.line + 1, line_count)
	local line = api.nvim_buf_get_lines(bufnr, target_row - 1, target_row, false)[1] or ""
	local target_col = math.min(cursor_position.column, #line)

	api.nvim_win_set_cursor(0, { target_row, target_col })
end

function M.run(context)
	validate_context(context)

	local bufnr = resolve_buffer_id(context.buffer_id)
	local filetype = vim.bo[bufnr].filetype
	local lang = parser_language_for(filetype)
	if lang == nil then
		raise(("Unsupported filetype '%s'"):format(filetype))
	end

	ensure_parser(bufnr, lang)

	local target = find_target_function(bufnr, lang, context.cursor_position)
	local root = vim.treesitter.get_parser(bufnr, lang):parse()[1]:root()
	local call_sites = gather_call_sites(root, target, bufnr)
	local edits = {}

	for _, call_site in ipairs(call_sites) do
		local start_row, start_col, end_row, end_col = call_site:range()
		edits[#edits + 1] = {
			start_row = start_row,
			start_col = start_col,
			end_row = end_row,
			end_col = end_col,
			replacement = inline_call_expression(call_site, target, bufnr),
		}
	end

	local delete_start_row, delete_start_col, delete_end_row, delete_end_col = declaration_delete_range(bufnr, target.declaration_node)
	edits[#edits + 1] = {
		start_row = delete_start_row,
		start_col = delete_start_col,
		end_row = delete_end_row,
		end_col = delete_end_col,
		replacement = {},
	}

	local target_cursor = map_cursor_position(context.cursor_position, edits)

	apply_text_edits(bufnr, edits)
	sync_cursor(bufnr, target_cursor)
end

return M
