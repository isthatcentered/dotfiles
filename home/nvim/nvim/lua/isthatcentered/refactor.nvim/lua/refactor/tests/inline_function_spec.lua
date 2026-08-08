local api = vim.api
local Refactor = require("refactor")
local TypescriptRefactor = require("refactor.typescript")
local inline_function = require("refactor.typescript.inline_function")
local pack = table.pack or function(...)
	return {
		n = select("#", ...),
		...,
	}
end
local unpack = table.unpack or unpack

local function with_test_buffer(filetype, lines, cursor, callback)
	vim.cmd("enew!")

	local bufnr = api.nvim_create_buf(false, true)

	api.nvim_win_set_buf(0, bufnr)
	vim.bo[bufnr].buftype = ""
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.cmd("setfiletype " .. filetype)
	api.nvim_win_set_cursor(0, cursor)

	local result
	local ok, err = xpcall(function()
		result = pack(callback(bufnr))
	end, debug.traceback)

	vim.cmd("enew!")

	if api.nvim_buf_is_valid(bufnr) then
		api.nvim_buf_delete(bufnr, { force = true })
	end

	if not ok then
		error(err)
	end

	return unpack(result, 1, result.n)
end

local function normalize_error(err)
	local message = tostring(err):match("Refactor: [^\n]+")
	if message ~= nil then
		return message
	end

	message = tostring(err):match("E%d+: [^\n]+")
	if message ~= nil then
		return message
	end

	return tostring(err)
end

local function run_refactor(filetype, lines, cursor)
	return with_test_buffer(filetype, lines, cursor, function(bufnr)
		local ok, err = pcall(inline_function.run, {
			buffer_id = bufnr,
			cursor_position = {
				line = cursor[1] - 1,
				column = cursor[2],
			},
		})
		local error_message = nil
		if not ok then
			error_message = normalize_error(err)
		end

		return {
			lines = api.nvim_buf_get_lines(bufnr, 0, -1, false),
			cursor = api.nvim_win_get_cursor(0),
			error = error_message,
		}
	end)
end

describe("inline_function", function()
	it("inlines a function declaration with a single return statement across direct call sites", function()
		local input = {
			filetype = "typescript",
			lines = {
				"function add(a: number, b: number) {",
				"\treturn a + b;",
				"}",
				"const first = add(1, 2);",
				"const second = add(total, 3);",
			},
			cursor = { 1, 10 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const first = (1 + 2);",
				"const second = (total + 3);",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("inlines a standalone const arrow function expression body", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const add = (a, b) => a + b;",
				"const total = add(1 + 2, count * scale);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const total = ((1 + 2) + (count * scale));",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("inlines a standalone const function expression with a single return", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const trim = function (value: string) { return value.trim(); };",
				"const result = trim(name);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const result = name.trim();",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("expands parameter shorthand properties when inlining", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const replaceCurrentAttempt = (job: DataExtractJob, status: JobStatus.JobStatus): Attempt =>",
				"  new Attempt({",
				"    attemptNumber: job.lastAttempt.attemptNumber,",
				"    status,",
				"    triggeredBy: job.lastAttempt.triggeredBy,",
				"  });",
				"const attempt = replaceCurrentAttempt(emptyJob, emptyJobStatus);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const attempt = new Attempt({",
				"                  attemptNumber: emptyJob.lastAttempt.attemptNumber,",
				"                  status: emptyJobStatus,",
				"                  triggeredBy: emptyJob.lastAttempt.triggeredBy,",
				"                });",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("keeps non-parameter shorthand properties when inlining", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const build = (status: Status) => ({",
				"  status,",
				"  reason,",
				"});",
				"const result = build(nextStatus);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const result = ({",
				"                 status: nextStatus,",
				"                 reason,",
				"               });",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("inlines multiline bodies that read object-literal argument properties", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const makeCommandRunnerError = (parameters: {",
				"  error: PlatformError.PlatformError",
				'  reason: CommandRunnerError["reason"]',
				"}) =>",
				"  new CommandRunnerError({",
				"    reason: parameters.reason,",
				"    message: formatPlatformError(parameters.error),",
				"  });",
				"Stream.mapError((error) =>",
				"  makeCommandRunnerError({",
				"    error,",
				'    reason: "io",',
				"  }),",
				");",
			},
			cursor = { 1, 10 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"Stream.mapError((error) =>",
				"  new CommandRunnerError({",
				'    reason: "io",',
				"    message: formatPlatformError(error),",
				"  }),",
				");",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("inlines object-literal spread argument properties", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const createCodexCliJudgeScorer = <TInput, TOutput, TExpected>(options: Options) =>",
				"  createScorer<TInput, TOutput, TExpected>({",
				'    name: "Codex",',
				"    scorer: async ({ input, output, expected }) => ({",
				"      model: options.model,",
				"      reasoningEffort: options.reasoningEffort,",
				"      input,",
				"      output,",
				"      expected,",
				"    }),",
				"  });",
				"export const makeCodexScorer = (configuration: Configuration) =>",
				"  createCodexCliJudgeScorer<string, string, string>({",
				"    ...configuration,",
				"  });",
			},
			cursor = { 13, 2 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"export const makeCodexScorer = (configuration: Configuration) =>",
				"  createScorer<string, string, string>({",
				'    name: "Codex",',
				"    scorer: async ({ input, output, expected }) => ({",
				"      model: configuration.model,",
				"      reasoningEffort: configuration.reasoningEffort,",
				"      input,",
				"      output,",
				"      expected,",
				"    }),",
				"  });",
			},
			cursor = { 2, 2 },
			error = nil,
		}, result)
	end)

	it("inlines generic helpers with inferred type arguments when the body does not reference them", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const collect = <A, E>(stream: Stream.Stream<A, E>) =>",
				"  pipe(",
				"    Stream.runCollect(stream),",
				"    Effect.map((chunk) => Chunk.toReadonlyArray(chunk)),",
				"  );",
				"const events = collect(result);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const events = pipe(",
				"                 Stream.runCollect(result),",
				"                 Effect.map((chunk) => Chunk.toReadonlyArray(chunk)),",
				"               );",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("keeps the cursor on the inlined call site when the declaration is above it", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const add = (a: number, b: number) => a + b;",
				"const total = add(1, 2);",
			},
			cursor = { 2, 14 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const total = (1 + 2);",
			},
			cursor = { 1, 14 },
			error = nil,
		}, result)
	end)

	it("keeps the cursor on the inlined call site when the declaration is below it", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const total = add(1, 2);",
				"const add = (a: number, b: number) => a + b;",
			},
			cursor = { 1, 14 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const total = (1 + 2);",
			},
			cursor = { 1, 14 },
			error = nil,
		}, result)
	end)

	it("inlines a standalone const function value when invoked from a call site", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const makeCommandRunnerError = (parameters: {",
				"  error: PlatformError.PlatformError",
				'  reason: CommandRunnerError["reason"]',
				"}) =>",
				"  new CommandRunnerError({",
				"    reason: parameters.reason,",
				"    message: formatPlatformError(parameters.error),",
				"  });",
				"const first = Stream.mapError((error) =>",
				"  makeCommandRunnerError({",
				"    error,",
				'    reason: "io",',
				"  }),",
				");",
				"const second = Effect.mapError((error) =>",
				"  makeCommandRunnerError({",
				"    error,",
				'    reason: "spawn",',
				"  }),",
				");",
			},
			cursor = { 10, 2 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const first = Stream.mapError((error) =>",
				"  new CommandRunnerError({",
				'    reason: "io",',
				"    message: formatPlatformError(error),",
				"  }),",
				");",
				"const second = Effect.mapError((error) =>",
				"  new CommandRunnerError({",
				'    reason: "spawn",',
				"    message: formatPlatformError(error),",
				"  }),",
				");",
			},
			cursor = { 2, 2 },
			error = nil,
		}, result)
	end)

	it("prefers the direct callee under the cursor over an enclosing function declaration", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const makeCommandRunnerError = (parameters: {",
				"  error: PlatformError.PlatformError",
				'  reason: CommandRunnerError["reason"]',
				"}) =>",
				"  new CommandRunnerError({",
				"    reason: parameters.reason,",
				"    message: formatPlatformError(parameters.error),",
				"  });",
				"const decodeOutput = (parameters: {",
				"  stream: Stream.Stream<Uint8Array, PlatformError.PlatformError>",
				"}) =>",
				"  pipe(",
				"    parameters.stream,",
				"    Stream.mapError((error) =>",
				"      makeCommandRunnerError({",
				"        error,",
				'        reason: "io",',
				"      }),",
				"    ),",
				"  );",
			},
			cursor = { 15, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const decodeOutput = (parameters: {",
				"  stream: Stream.Stream<Uint8Array, PlatformError.PlatformError>",
				"}) =>",
				"  pipe(",
				"    parameters.stream,",
				"    Stream.mapError((error) =>",
				"      new CommandRunnerError({",
				'        reason: "io",',
				"        message: formatPlatformError(error),",
				"      }),",
				"    ),",
				"  );",
			},
			cursor = { 7, 6 },
			error = nil,
		}, result)
	end)

	it("inlines nested-callback helpers from a call site across all usages", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const decodeOutput = (parameters: {",
				"  stream: Stream.Stream<Uint8Array, PlatformError.PlatformError>",
				"  decoder: TextDecoder",
				"  mapChunk: (chunk: string) => CommandRunnerEvent",
				"}) =>",
				"  pipe(",
				"    parameters.stream,",
				"    Stream.mapError((error) =>",
				"      new CommandRunnerError({",
				'        reason: "io",',
				"        message: formatPlatformError(error),",
				"      }),",
				"    ),",
				"    Stream.map((chunk) => parameters.decoder.decode(chunk, { stream: true })),",
				"    Stream.concat(Stream.make(parameters.decoder.decode())),",
				'    Stream.filter((chunk) => chunk !== ""),',
				"    Stream.map(parameters.mapChunk),",
				"  );",
				"const output = pipe(",
				"  decodeOutput({",
				"    stream: process.stdout,",
				"    decoder: stdoutDecoder,",
				"    mapChunk: (chunk) => new StdoutChunk({ chunk }),",
				"  }),",
				"  Stream.merge(",
				"    decodeOutput({",
				"      stream: process.stderr,",
				"      decoder: stderrDecoder,",
				"      mapChunk: (chunk) => new StderrChunk({ chunk }),",
				"    }),",
				"  ),",
				");",
			},
			cursor = { 20, 2 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const output = pipe(",
				"  pipe(",
				"    process.stdout,",
				"    Stream.mapError((error) =>",
				"      new CommandRunnerError({",
				'        reason: "io",',
				"        message: formatPlatformError(error),",
				"      }),",
				"    ),",
				"    Stream.map((chunk) => stdoutDecoder.decode(chunk, { stream: true })),",
				"    Stream.concat(Stream.make(stdoutDecoder.decode())),",
				'    Stream.filter((chunk) => chunk !== ""),',
				"    Stream.map(((chunk) => new StdoutChunk({ chunk }))),",
				"  ),",
				"  Stream.merge(",
				"    pipe(",
				"      process.stderr,",
				"      Stream.mapError((error) =>",
				"        new CommandRunnerError({",
				'          reason: "io",',
				"          message: formatPlatformError(error),",
				"        }),",
				"      ),",
				"      Stream.map((chunk) => stderrDecoder.decode(chunk, { stream: true })),",
				"      Stream.concat(Stream.make(stderrDecoder.decode())),",
				'      Stream.filter((chunk) => chunk !== ""),',
				"      Stream.map(((chunk) => new StderrChunk({ chunk }))),",
				"    ),",
				"  ),",
				");",
			},
			cursor = { 2, 2 },
			error = nil,
		}, result)
	end)

	it("inlines nested-callback helpers from the declaration", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const decodeOutput = (parameters: {",
				"  stream: Stream.Stream<Uint8Array, PlatformError.PlatformError>",
				"  decoder: TextDecoder",
				"  mapChunk: (chunk: string) => CommandRunnerEvent",
				"}) =>",
				"  pipe(",
				"    parameters.stream,",
				"    Stream.mapError((error) =>",
				"      new CommandRunnerError({",
				'        reason: "io",',
				"        message: formatPlatformError(error),",
				"      }),",
				"    ),",
				"    Stream.map((chunk) => parameters.decoder.decode(chunk, { stream: true })),",
				"    Stream.concat(Stream.make(parameters.decoder.decode())),",
				'    Stream.filter((chunk) => chunk !== ""),',
				"    Stream.map(parameters.mapChunk),",
				"  );",
				"const output = pipe(",
				"  decodeOutput({",
				"    stream: process.stdout,",
				"    decoder: stdoutDecoder,",
				"    mapChunk: (chunk) => new StdoutChunk({ chunk }),",
				"  }),",
				"  Stream.merge(",
				"    decodeOutput({",
				"      stream: process.stderr,",
				"      decoder: stderrDecoder,",
				"      mapChunk: (chunk) => new StderrChunk({ chunk }),",
				"    }),",
				"  ),",
				");",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const output = pipe(",
				"  pipe(",
				"    process.stdout,",
				"    Stream.mapError((error) =>",
				"      new CommandRunnerError({",
				'        reason: "io",',
				"        message: formatPlatformError(error),",
				"      }),",
				"    ),",
				"    Stream.map((chunk) => stdoutDecoder.decode(chunk, { stream: true })),",
				"    Stream.concat(Stream.make(stdoutDecoder.decode())),",
				'    Stream.filter((chunk) => chunk !== ""),',
				"    Stream.map(((chunk) => new StdoutChunk({ chunk }))),",
				"  ),",
				"  Stream.merge(",
				"    pipe(",
				"      process.stderr,",
				"      Stream.mapError((error) =>",
				"        new CommandRunnerError({",
				'          reason: "io",',
				"          message: formatPlatformError(error),",
				"        }),",
				"      ),",
				"      Stream.map((chunk) => stderrDecoder.decode(chunk, { stream: true })),",
				"      Stream.concat(Stream.make(stderrDecoder.decode())),",
				'      Stream.filter((chunk) => chunk !== ""),',
				"      Stream.map(((chunk) => new StderrChunk({ chunk }))),",
				"    ),",
				"  ),",
				");",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("inlines helpers with destructured object parameters", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const buildJudgePrompt = ({",
				"  input,",
				"  output,",
				"  expected,",
				"  rubric,",
				"}: {",
				"  input: unknown;",
				"  output: unknown;",
				"  expected: unknown;",
				"  rubric: string;",
				"}) =>",
				"  [",
				"    `Rubric: ${rubric}`,",
				"    serializeForPrompt(input),",
				"    serializeForPrompt(expected),",
				"    serializeForPrompt(output),",
				'  ].join("\\n");',
				"const prompt = buildJudgePrompt({ input, output, expected, rubric });",
			},
			cursor = { 18, 15 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const prompt = [",
				"                 `Rubric: ${rubric}`,",
				"                 serializeForPrompt(input),",
				"                 serializeForPrompt(expected),",
				"                 serializeForPrompt(output),",
				'               ].join("\\n");',
			},
			cursor = { 1, 15 },
			error = nil,
		}, result)
	end)

	it("inlines omitted optional identifier parameters as undefined", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const newEvent = (overrides?: Partial<NewEvent>) =>",
				"  NewEvent.random({",
				"    data: {},",
				"    metadata: {},",
				"    ...overrides,",
				"  });",
				"const event = newEvent();",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const event = NewEvent.random({",
				"                data: {},",
				"                metadata: {},",
				"                ...undefined,",
				"              });",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("inlines provided optional identifier parameters", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const wrap = (value?: string) => ({ value });",
				"const result = wrap(name);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const result = ({ value: name });",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("fills multiple omitted trailing optional parameters with undefined", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const combine = (required: string, first?: string, second?: string) =>",
				"  [required, first, second];",
				"const result = combine(name);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const result = [name, undefined, undefined];",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("does not replace identifiers shadowed inside nested callbacks", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const wrap = (value: number) =>",
				"  items.map((value) => value + 1).map(() => value);",
				"const result = wrap(count);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const result = items.map((value) => value + 1).map(() => count);",
			},
			cursor = { 1, 0 },
			error = nil,
		}, result)
	end)

	it("rejects class or object methods", function()
		local input = {
			filetype = "typescript",
			lines = {
				"class Box { size(value: number) { return value + 1; } }",
			},
			cursor = { 1, 13 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"class Box { size(value: number) { return value + 1; } }",
			},
			cursor = { 1, 13 },
			error = "Refactor: Inline function does not support class or object methods yet",
		}, result)
	end)

	it("rejects functions with non-call usages", function()
		local input = {
			filetype = "typescript",
			lines = {
				"function add(a, b) { return a + b; }",
				"const alias = add;",
				"const total = add(1, 2);",
			},
			cursor = { 1, 10 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"function add(a, b) { return a + b; }",
				"const alias = add;",
				"const total = add(1, 2);",
			},
			cursor = { 1, 10 },
			error = "Refactor: Inline function found non-call usages for 'add'",
		}, result)
	end)

	it("rejects functions without an expression body or single return statement", function()
		local input = {
			filetype = "typescript",
			lines = {
				"function add(a, b) {",
				"\tconst total = a + b;",
				"\treturn total;",
				"}",
				"const value = add(1, 2);",
			},
			cursor = { 1, 10 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"function add(a, b) {",
				"\tconst total = a + b;",
				"\treturn total;",
				"}",
				"const value = add(1, 2);",
			},
			cursor = { 1, 10 },
			error = "Refactor: Inline function only supports functions with an expression body or a single return statement",
		}, result)
	end)

	it("rejects default parameters", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const add = ({ value }, count = 1) => value + count;",
				"const total = add({ value: item }, 2);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const add = ({ value }, count = 1) => value + count;",
				"const total = add({ value: item }, 2);",
			},
			cursor = { 1, 6 },
			error = "Refactor: Inline function only supports required identifier parameters",
		}, result)
	end)

	it("rejects omitted optional destructured parameters", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const readValue = ({ value }?: { value: string }) => value;",
				"const result = readValue();",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const readValue = ({ value }?: { value: string }) => value;",
				"const result = readValue();",
			},
			cursor = { 1, 6 },
			error = "Refactor: Inline function does not support omitted optional destructured parameters yet",
		}, result)
	end)

	it("rejects inferred type arguments when the body references type parameters", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const option = <A>(value: A) => Option.some<A>(value);",
				"const result = option(value);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const option = <A>(value: A) => Option.some<A>(value);",
				"const result = option(value);",
			},
			cursor = { 1, 6 },
			error = "Refactor: Inline function expected 1 type arguments but found 0",
		}, result)
	end)

	it("rejects unresolved object-literal properties", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const readReason = (parameters) =>",
				"  parameters.reason;",
				"const value = readReason({",
				"  error,",
				"});",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const readReason = (parameters) =>",
				"  parameters.reason;",
				"const value = readReason({",
				"  error,",
				"});",
			},
			cursor = { 1, 6 },
			error = "Refactor: Inline function could not resolve property 'reason' from object argument for parameter 'parameters'",
		}, result)
	end)

	it("rejects wrong-arity call sites", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const add = (a, b) => a + b;",
				"const total = add(1);",
			},
			cursor = { 1, 6 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const add = (a, b) => a + b;",
				"const total = add(1);",
			},
			cursor = { 1, 6 },
			error = "Refactor: Inline function expected 2 arguments but found 1",
		}, result)
	end)
end)

describe("public api", function()
	it("exposes the refactor from the root and language namespaces", function()
		assert.equal(TypescriptRefactor.inline_function, Refactor.typescript.inline_function)
	end)
end)
