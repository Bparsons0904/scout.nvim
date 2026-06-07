local scout = require("scout")

describe("scout._deep_merge", function()
  it("overlays scalar overrides onto the base", function()
    local result = scout._deep_merge({ a = 1, b = 2 }, { b = 3 })
    assert.same({ a = 1, b = 3 }, result)
  end)

  it("merges nested tables instead of replacing them", function()
    local result = scout._deep_merge(
      { keys = { start = "x", quit = "y" } },
      { keys = { quit = "z" } }
    )
    assert.same({ keys = { start = "x", quit = "z" } }, result)
  end)

  it("lets a value of false override a default", function()
    local result = scout._deep_merge({ keys = { start_pick = "x" } }, { keys = { start_pick = false } })
    assert.is_false(result.keys.start_pick)
  end)

  it("adds keys that are absent from the base", function()
    local result = scout._deep_merge({ a = 1 }, { b = 2 })
    assert.same({ a = 1, b = 2 }, result)
  end)

  it("does not mutate the base table", function()
    local base = { keys = { start = "x" } }
    scout._deep_merge(base, { keys = { start = "y" } })
    assert.equals("x", base.keys.start)
  end)

  it("treats a nil override as an empty override", function()
    assert.same({ a = 1 }, scout._deep_merge({ a = 1 }, nil))
  end)
end)
