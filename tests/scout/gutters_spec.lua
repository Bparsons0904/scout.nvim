local gutters = require("scout.gutters")

local function stub_gitsigns()
  local calls = {}
  package.loaded["gitsigns"] = {
    change_base = function(base) calls[#calls + 1] = { "change_base", base } end,
    toggle_deleted = function(value) calls[#calls + 1] = { "toggle_deleted", value } end,
    toggle_linehl = function(value) calls[#calls + 1] = { "toggle_linehl", value } end,
    toggle_word_diff = function(value) calls[#calls + 1] = { "toggle_word_diff", value } end,
  }
  return calls
end

local function values_for(calls, name)
  local found = {}
  for _, call in ipairs(calls) do
    if call[1] == name then
      found[#found + 1] = call[2]
    end
  end
  return found
end

describe("gutters inline diff", function()
  before_each(function()
    stub_gitsigns()
    gutters.set_inline(false)
  end)

  after_each(function()
    package.loaded["gitsigns"] = nil
  end)

  it("turns all three gitsigns diff renderings on and back off", function()
    local calls = stub_gitsigns()

    assert.is_true(gutters.toggle_inline())
    assert.is_true(gutters.inline_enabled())
    assert.same({ true }, values_for(calls, "toggle_deleted"))
    assert.same({ true }, values_for(calls, "toggle_linehl"))
    assert.same({ true }, values_for(calls, "toggle_word_diff"))

    assert.is_false(gutters.toggle_inline())
    assert.is_false(gutters.inline_enabled())
    assert.same({ true, false }, values_for(calls, "toggle_deleted"))
  end)

  it("clears inline mode when the session restores the base", function()
    gutters.set_inline(true)
    local calls = stub_gitsigns()

    gutters.restore()

    assert.is_false(gutters.inline_enabled())
    assert.same({ false }, values_for(calls, "toggle_deleted"))
    assert.same({ nil }, { values_for(calls, "change_base")[1] })
  end)
end)
