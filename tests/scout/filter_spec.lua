local filter = require("scout.filter")

describe("filter.is_excluded", function()
  it("matches a glob across directories", function()
    assert.is_true(filter.is_excluded("pkg/foo_test.go", { "*_test.go" }))
  end)

  it("does not match non-test files", function()
    assert.is_false(filter.is_excluded("pkg/foo.go", { "*_test.go" }))
  end)

  it("matches when any pattern matches", function()
    assert.is_true(filter.is_excluded("a/b/spec.lua", { "*_test.go", "*spec.lua" }))
  end)

  it("returns false for empty or nil pattern lists", function()
    assert.is_false(filter.is_excluded("pkg/foo_test.go", {}))
    assert.is_false(filter.is_excluded("pkg/foo_test.go", nil))
  end)

  it("matches case-sensitively even when 'ignorecase' is set", function()
    local saved = vim.o.ignorecase
    vim.o.ignorecase = true
    local matched = filter.is_excluded("pkg/FOO_TEST.GO", { "*_test.go" })
    vim.o.ignorecase = saved
    assert.is_false(matched)
  end)
end)
