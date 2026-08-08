local Persistence = require("scoped.v2.Persistence")
local temp_dir = require("scoped.temp_dir")

describe("Persistence", function()
  after_each(function()
    temp_dir.cleanup_all()
  end)

  it("No saved data returns nil", function()
    local persistence = Persistence.new({
      path = temp_dir.create_dir(),
    })

    assert.same(nil, persistence:load("non-existent-id"))
  end)

  it("Loads back saved data", function()
    local data = { hello = "world" }
    local registry = {
      id = "my-registry-id",
      serialize = function()
        return data
      end,
    }
    local persistence = Persistence.new({
      path = temp_dir.create_dir(),
    })

    persistence:save(registry)

    assert.same(data, persistence:load(registry.id))
  end)
end)
