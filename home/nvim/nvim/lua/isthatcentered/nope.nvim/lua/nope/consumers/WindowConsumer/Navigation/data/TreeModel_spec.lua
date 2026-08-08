local TreeModel = require("nope.consumers.WindowConsumer.Navigation.data.TreeModel")

describe("TreeModel", function()
  ---@return TestRunState
  local function make_state(overrides)
    return vim.tbl_deep_extend("force", {
      status = "done",
      duration_ms = 1000,
      summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
      files = {},
    }, overrides or {})
  end

  ---@return FileNode
  local function make_file(overrides)
    return vim.tbl_deep_extend("force", {
      id = "file-1",
      path = "/path/to/test.ts",
      status = "passed",
      suites = {},
      tests = {},
    }, overrides or {})
  end

  ---@return TestNode
  local function make_test(overrides)
    return vim.tbl_deep_extend("force", {
      id = "test-1",
      name = "should work",
      full_name = "suite > should work",
      status = "passed",
      duration_ms = 10,
      location = { line = 5, column = 1 },
    }, overrides or {})
  end

  ---@return SuiteNode
  local function make_suite(overrides)
    return vim.tbl_deep_extend("force", {
      id = "suite-1",
      name = "my suite",
      status = "passed",
      tests = {},
      suites = {},
    }, overrides or {})
  end

  describe("build", function()
    it("returns root node with header", function()
      local state = make_state()
      local root = TreeModel.build(state)

      assert.same("root", root.type)
      assert.same("__root__", root.id)
      assert.same(1, #root.children) -- just header
      assert.same("header", root.children[1].type)
    end)

    it("header node contains state data", function()
      local state = make_state({
        status = "pending",
        summary = { total = 5, passed = 2, failed = 0, skipped = 0 },
        duration_ms = 1234,
      })
      local root = TreeModel.build(state)
      local header = root.children[1]

      assert.same("pending", header.node.status)
      assert.same(5, header.node.summary.total)
      assert.same(1234, header.node.duration_ms)
    end)

    it("builds file nodes", function()
      local state = make_state({
        files = { make_file({ path = "/src/foo.test.ts" }) },
      })
      local root = TreeModel.build(state)

      assert.same(2, #root.children) -- header + file
      local file_node = root.children[2]
      assert.same("file", file_node.type)
      assert.same("file-1", file_node.id)
      assert.same("/src/foo.test.ts", file_node.node.path)
    end)

    it("builds test nodes as file children", function()
      local state = make_state({
        files = {
          make_file({
            tests = { make_test({ id = "t1", name = "test one" }) },
          }),
        },
      })
      local root = TreeModel.build(state)
      local file_node = root.children[2]

      assert.same(1, #file_node.children)
      local test_node = file_node.children[1]
      assert.same("test", test_node.type)
      assert.same("t1", test_node.id)
      assert.same("test one", test_node.node.name)
    end)

    it("builds suite nodes with nested tests", function()
      local state = make_state({
        files = {
          make_file({
            suites = {
              make_suite({
                id = "s1",
                name = "my suite",
                tests = { make_test({ id = "t1" }) },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)
      local file_node = root.children[2]
      local suite_node = file_node.children[1]

      assert.same("suite", suite_node.type)
      assert.same("s1", suite_node.id)
      assert.same("my suite", suite_node.node.name)
      assert.same(1, #suite_node.children)
      assert.same("test", suite_node.children[1].type)
    end)

    it("builds nested suites", function()
      local state = make_state({
        files = {
          make_file({
            suites = {
              make_suite({
                id = "s1",
                suites = {
                  make_suite({ id = "s2", name = "nested suite" }),
                },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)
      local outer_suite = root.children[2].children[1]
      local inner_suite = outer_suite.children[1]

      assert.same("suite", inner_suite.type)
      assert.same("s2", inner_suite.id)
      assert.same("nested suite", inner_suite.node.name)
    end)

    it("preserves failure data in test node", function()
      local state = make_state({
        files = {
          make_file({
            tests = {
              make_test({
                status = "failed",
                failure = {
                  message = "Expected true to be false",
                  diff = "- true\n+ false",
                  stack = "at test.ts:10",
                },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)
      local test_node = root.children[2].children[1]

      assert.same("failed", test_node.node.status)
      assert.is_table(test_node.node.failure)
      assert.same("Expected true to be false", test_node.node.failure.message)
    end)
  end)

  describe("find_by_id", function()
    it("finds root node", function()
      local state = make_state()
      local root = TreeModel.build(state)

      local found = TreeModel.find_by_id(root, "__root__")
      assert.same(root, found)
    end)

    it("finds header node", function()
      local state = make_state()
      local root = TreeModel.build(state)

      local found = TreeModel.find_by_id(root, "__header__")
      assert.same("header", found.type)
    end)

    it("finds nested test node", function()
      local state = make_state({
        files = {
          make_file({
            suites = {
              make_suite({
                tests = { make_test({ id = "deep-test" }) },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)

      local found = TreeModel.find_by_id(root, "deep-test")
      assert.is_not_nil(found)
      assert.same("test", found.type)
      assert.same("deep-test", found.id)
    end)

    it("returns nil for non-existent id", function()
      local state = make_state()
      local root = TreeModel.build(state)

      local found = TreeModel.find_by_id(root, "does-not-exist")
      assert.is_nil(found)
    end)
  end)

  describe("flatten", function()
    it("returns empty array for state with no files", function()
      local state = make_state()
      local root = TreeModel.build(state)
      local nodes, id_to_line = TreeModel.flatten(root)

      assert.same(1, #nodes) -- just header
      assert.same(1, id_to_line["__header__"])
    end)

    it("flattens tree in correct order", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            tests = { make_test({ id = "t1" }) },
            suites = {
              make_suite({
                id = "s1",
                tests = { make_test({ id = "t2" }) },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)
      local nodes, id_to_line = TreeModel.flatten(root)

      -- Order: header, file, test1, suite, test2
      assert.same(5, #nodes)
      assert.same("header", nodes[1].type)
      assert.same("file", nodes[2].type)
      assert.same("test", nodes[3].type)
      assert.same("suite", nodes[4].type)
      assert.same("test", nodes[5].type)

      assert.same(1, id_to_line["__header__"])
      assert.same(2, id_to_line["f1"])
      assert.same(3, id_to_line["t1"])
      assert.same(4, id_to_line["s1"])
      assert.same(5, id_to_line["t2"])
    end)

    it("sets correct depth on flattened nodes", function()
      local state = make_state({
        files = {
          make_file({
            suites = {
              make_suite({
                suites = {
                  make_suite({ id = "deep-suite" }),
                },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)
      local nodes, _ = TreeModel.flatten(root)

      assert.same(0, nodes[1]._depth) -- header
      assert.same(0, nodes[2]._depth) -- file
      assert.same(1, nodes[3]._depth) -- suite
      assert.same(2, nodes[4]._depth) -- nested suite
    end)
  end)

  describe("filter_failures", function()
    it("keeps header node", function()
      local state = make_state({
        files = { make_file({ status = "passed" }) },
      })
      local root = TreeModel.build(state)
      local filtered = TreeModel.filter_failures(root)

      assert.same(1, #filtered.children) -- only header remains
      assert.same("header", filtered.children[1].type)
    end)

    it("removes passing files with no failing tests", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            status = "passed",
            tests = { make_test({ id = "t1", status = "passed" }) },
          }),
        },
      })
      local root = TreeModel.build(state)
      local filtered = TreeModel.filter_failures(root)

      assert.same(1, #filtered.children) -- only header
    end)

    it("keeps files with failing tests", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            status = "failed",
            tests = { make_test({ id = "t1", status = "failed" }) },
          }),
        },
      })
      local root = TreeModel.build(state)
      local filtered = TreeModel.filter_failures(root)

      assert.same(2, #filtered.children) -- header + file
      assert.same("file", filtered.children[2].type)
      assert.same(1, #filtered.children[2].children)
      assert.same("failed", filtered.children[2].children[1].node.status)
    end)

    it("filters out passing tests in files with mixed results", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            status = "failed",
            tests = {
              make_test({ id = "t1", status = "passed" }),
              make_test({ id = "t2", status = "failed" }),
              make_test({ id = "t3", status = "passed" }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)
      local filtered = TreeModel.filter_failures(root)

      local file_node = filtered.children[2]
      assert.same(1, #file_node.children)
      assert.same("t2", file_node.children[1].id)
    end)

    it("keeps suites with failing tests", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            status = "failed",
            suites = {
              make_suite({
                id = "s1",
                status = "failed",
                tests = { make_test({ id = "t1", status = "failed" }) },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)
      local filtered = TreeModel.filter_failures(root)

      local file_node = filtered.children[2]
      assert.same(1, #file_node.children)
      assert.same("suite", file_node.children[1].type)
      assert.same(1, #file_node.children[1].children)
    end)

    it("removes suites with only passing tests", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            status = "failed",
            tests = { make_test({ id = "t1", status = "failed" }) },
            suites = {
              make_suite({
                id = "s1",
                status = "passed",
                tests = { make_test({ id = "t2", status = "passed" }) },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)
      local filtered = TreeModel.filter_failures(root)

      local file_node = filtered.children[2]
      -- Should only have the failing test, not the passing suite
      assert.same(1, #file_node.children)
      assert.same("test", file_node.children[1].type)
      assert.same("t1", file_node.children[1].id)
    end)

    it("handles deeply nested failing tests", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            status = "failed",
            suites = {
              make_suite({
                id = "s1",
                status = "failed",
                suites = {
                  make_suite({
                    id = "s2",
                    status = "failed",
                    tests = { make_test({ id = "t1", status = "failed" }) },
                  }),
                },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)
      local filtered = TreeModel.filter_failures(root)

      -- file -> suite s1 -> suite s2 -> test t1
      local file_node = filtered.children[2]
      assert.same(1, #file_node.children)
      local s1 = file_node.children[1]
      assert.same("s1", s1.id)
      assert.same(1, #s1.children)
      local s2 = s1.children[1]
      assert.same("s2", s2.id)
      assert.same(1, #s2.children)
      assert.same("t1", s2.children[1].id)
    end)
  end)

  describe("find_test_by_file_and_name", function()
    it("finds test by file path and short name", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            tests = { make_test({ id = "t1", name = "should work", full_name = "suite > should work" }) },
          }),
        },
      })
      local root = TreeModel.build(state)

      local test_node, ancestors = TreeModel.find_test_by_file_and_name(root, "src/foo.test.ts", "should work")

      assert.is_not_nil(test_node)
      assert.same("t1", test_node.id)
      assert.same({ "f1" }, ancestors)
    end)

    it("finds test by file path and full_name", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            tests = { make_test({ id = "t1", name = "should work", full_name = "suite > should work" }) },
          }),
        },
      })
      local root = TreeModel.build(state)

      local test_node, ancestors = TreeModel.find_test_by_file_and_name(root, "src/foo.test.ts", "suite > should work")

      assert.is_not_nil(test_node)
      assert.same("t1", test_node.id)
      assert.same({ "f1" }, ancestors)
    end)

    it("returns nil for non-matching file path", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            tests = { make_test({ id = "t1", name = "should work" }) },
          }),
        },
      })
      local root = TreeModel.build(state)

      local test_node, ancestors = TreeModel.find_test_by_file_and_name(root, "src/bar.test.ts", "should work")

      assert.is_nil(test_node)
      assert.is_nil(ancestors)
    end)

    it("returns nil for non-matching test name", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            tests = { make_test({ id = "t1", name = "should work" }) },
          }),
        },
      })
      local root = TreeModel.build(state)

      local test_node, ancestors = TreeModel.find_test_by_file_and_name(root, "src/foo.test.ts", "other test")

      assert.is_nil(test_node)
      assert.is_nil(ancestors)
    end)

    it("includes suite ancestors for nested tests", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            suites = {
              make_suite({
                id = "s1",
                name = "outer suite",
                suites = {
                  make_suite({
                    id = "s2",
                    name = "inner suite",
                    tests = { make_test({ id = "t1", name = "nested test" }) },
                  }),
                },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)

      local test_node, ancestors = TreeModel.find_test_by_file_and_name(root, "src/foo.test.ts", "nested test")

      assert.is_not_nil(test_node)
      assert.same("t1", test_node.id)
      assert.same({ "f1", "s1", "s2" }, ancestors)
    end)

    it("finds first matching test when multiple files exist", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            tests = { make_test({ id = "t1", name = "should work" }) },
          }),
          make_file({
            id = "f2",
            path = "src/bar.test.ts",
            tests = { make_test({ id = "t2", name = "should work" }) },
          }),
        },
      })
      local root = TreeModel.build(state)

      local test_node, ancestors = TreeModel.find_test_by_file_and_name(root, "src/bar.test.ts", "should work")

      assert.is_not_nil(test_node)
      assert.same("t2", test_node.id)
      assert.same({ "f2" }, ancestors)
    end)
  end)

  describe("filter_by_scope", function()
    it("returns nil for non-existent scope_id", function()
      local state = make_state()
      local root = TreeModel.build(state)

      local filtered = TreeModel.filter_by_scope(root, "does-not-exist")

      assert.is_nil(filtered)
    end)

    it("filters to file scope", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            tests = { make_test({ id = "t1" }) },
          }),
          make_file({
            id = "f2",
            path = "src/bar.test.ts",
            tests = { make_test({ id = "t2" }) },
          }),
        },
      })
      local root = TreeModel.build(state)

      local filtered = TreeModel.filter_by_scope(root, "f1")

      assert.is_not_nil(filtered)
      -- Should have header + file f1
      assert.same(2, #filtered.children)
      assert.same("header", filtered.children[1].type)
      assert.same("f1", filtered.children[2].id)
      -- f1 should still have its children
      assert.same(1, #filtered.children[2].children)
    end)

    it("filters to suite scope", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            suites = {
              make_suite({
                id = "s1",
                name = "my suite",
                tests = { make_test({ id = "t1" }) },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)

      local filtered = TreeModel.filter_by_scope(root, "s1")

      assert.is_not_nil(filtered)
      -- Should have header + suite s1 (no file ancestor)
      assert.same(2, #filtered.children)
      assert.same("header", filtered.children[1].type)
      assert.same("s1", filtered.children[2].id)
      assert.same("suite", filtered.children[2].type)
      -- Suite should keep its children
      assert.same(1, #filtered.children[2].children)
    end)

    it("filters to test scope", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            tests = {
              make_test({ id = "t1", name = "test one" }),
              make_test({ id = "t2", name = "test two" }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)

      local filtered = TreeModel.filter_by_scope(root, "t1")

      assert.is_not_nil(filtered)
      -- Should have header + test t1 (no file/suite ancestor)
      assert.same(2, #filtered.children)
      assert.same("header", filtered.children[1].type)
      assert.same("t1", filtered.children[2].id)
      assert.same("test", filtered.children[2].type)
    end)

    it("preserves nested children when filtering to file", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            tests = { make_test({ id = "t1" }) },
            suites = {
              make_suite({
                id = "s1",
                tests = { make_test({ id = "t2" }) },
                suites = {
                  make_suite({ id = "s2", tests = { make_test({ id = "t3" }) } }),
                },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)

      local filtered = TreeModel.filter_by_scope(root, "f1")

      -- Flatten and check all nodes are present
      local nodes = TreeModel.flatten(filtered)
      local ids = {}
      for _, node in ipairs(nodes) do
        ids[node.id] = true
      end

      assert.is_true(ids["t1"])
      assert.is_true(ids["s1"])
      assert.is_true(ids["t2"])
      assert.is_true(ids["s2"])
      assert.is_true(ids["t3"])
    end)

    it("does not mutate original tree", function()
      local state = make_state({
        files = {
          make_file({ id = "f1" }),
          make_file({ id = "f2" }),
        },
      })
      local root = TreeModel.build(state)
      local original_count = #root.children

      TreeModel.filter_by_scope(root, "f1")

      assert.same(original_count, #root.children)
    end)
  end)

  describe("get_breadcrumb", function()
    it("returns empty for non-existent target", function()
      local state = make_state()
      local root = TreeModel.build(state)

      local breadcrumb = TreeModel.get_breadcrumb(root, "does-not-exist")

      assert.same({}, breadcrumb)
    end)

    it("returns file name for file node", function()
      local state = make_state({
        files = {
          make_file({ id = "f1", path = "src/foo.test.ts" }),
        },
      })
      local root = TreeModel.build(state)

      local breadcrumb = TreeModel.get_breadcrumb(root, "f1")

      assert.same({ "foo.test.ts" }, breadcrumb)
    end)

    it("returns file and suite for nested suite", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            suites = {
              make_suite({ id = "s1", name = "my suite" }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)

      local breadcrumb = TreeModel.get_breadcrumb(root, "s1")

      assert.same({ "foo.test.ts", "my suite" }, breadcrumb)
    end)

    it("returns full path for deeply nested test", function()
      local state = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            suites = {
              make_suite({
                id = "s1",
                name = "outer",
                suites = {
                  make_suite({
                    id = "s2",
                    name = "inner",
                    tests = { make_test({ id = "t1", name = "my test" }) },
                  }),
                },
              }),
            },
          }),
        },
      })
      local root = TreeModel.build(state)

      local breadcrumb = TreeModel.get_breadcrumb(root, "t1")

      assert.same({ "foo.test.ts", "outer", "inner", "my test" }, breadcrumb)
    end)
  end)

end)
