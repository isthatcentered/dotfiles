local Array = require("scoped.Array")

describe("Array", function()
  describe("is_duplicate", function()
    it("No duplicates", function()
      assert.same(
        false,
        Array.is_duplicate("A", function(a, b)
          return a == b
        end, { "A", "B" })
      )
    end)
    it("Item not in list", function()
      assert.same(
        false,
        Array.is_duplicate("C", function(a, b)
          return a == b
        end, { "A", "B" })
      )
    end)
    it("Has duplicates", function()
      assert.same(
        true,
        Array.is_duplicate("A", function(a, b)
          return a == b
        end, { "A", "B", "A" })
      )
    end)
  end)
  describe("map", function()
    it("Empty array returns empty", function()
      assert.same({}, Array.map(function(x) return x * 2 end, {}))
    end)
    it("Transforms elements", function()
      assert.same({2, 4, 6}, Array.map(function(x) return x * 2 end, {1, 2, 3}))
    end)
    it("Passes correct index", function()
      local indices = {}
      Array.map(function(x, i) table.insert(indices, i) return x end, {"a", "b"})
      assert.same({1, 2}, indices)
    end)
  end)
end)
