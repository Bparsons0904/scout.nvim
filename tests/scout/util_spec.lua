local util = require("scout.util")

describe("util.relative_to_root", function()
  it("strips the root prefix from a forward-slash path", function()
    assert.equals("src/foo.lua", util.relative_to_root("/repo/src/foo.lua", "/repo"))
  end)

  it("normalizes redundant separators before comparing", function()
    -- On Windows vim.fs.normalize also folds backslashes to forward slashes,
    -- which is what makes the prefix check match git's output there.
    assert.equals("src/foo.lua", util.relative_to_root("/repo//src/./foo.lua", "/repo"))
  end)

  it("returns nil when the path is outside the root", function()
    assert.is_nil(util.relative_to_root("/other/foo.lua", "/repo"))
  end)

  it("returns nil for empty or missing input", function()
    assert.is_nil(util.relative_to_root("", "/repo"))
    assert.is_nil(util.relative_to_root("/repo/foo.lua", nil))
  end)
end)
