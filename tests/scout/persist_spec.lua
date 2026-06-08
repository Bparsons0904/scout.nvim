local persist = require("scout.persist")

describe("persist", function()
  local orig_stdpath
  local tmp

  before_each(function()
    tmp = vim.fn.tempname()
    orig_stdpath = vim.fn.stdpath
    vim.fn.stdpath = function(what)
      if what == "state" then return tmp end
      return orig_stdpath(what)
    end
  end)

  after_each(function()
    vim.fn.stdpath = orig_stdpath
    vim.fn.delete(tmp, "rf")
  end)

  it("round-trips saved data", function()
    persist.save("repo|branch|origin/main|abc123", { reviewed = { "a.lua", "b.lua" } })
    local loaded = persist.load("repo|branch|origin/main|abc123")
    assert.same({ reviewed = { "a.lua", "b.lua" } }, loaded)
  end)

  it("replaces existing state", function()
    local key = "repo|branch|origin/main|abc123"
    persist.save(key, { reviewed = { "old.lua" } })
    persist.save(key, { reviewed = { "new.lua" } })

    assert.same({ reviewed = { "new.lua" } }, persist.load(key))
  end)

  it("returns an empty table when no state exists", function()
    assert.same({}, persist.load("does|not|exist"))
  end)

  it("supports filesystem-unsafe characters in the key", function()
    local key = "/repo:with*weird?<chars>|main|sha"
    persist.save(key, { reviewed = { "x.lua" } })
    assert.same({ reviewed = { "x.lua" } }, persist.load(key))
  end)

  it("does not collide when long keys share the same prefix", function()
    local prefix = string.rep("a", 200)
    persist.save(prefix .. "one", { reviewed = { "one.lua" } })
    persist.save(prefix .. "two", { reviewed = { "two.lua" } })

    assert.same({ reviewed = { "one.lua" } }, persist.load(prefix .. "one"))
    assert.same({ reviewed = { "two.lua" } }, persist.load(prefix .. "two"))
  end)
end)
