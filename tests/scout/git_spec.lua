local git = require("scout.git")

describe("git.parse_name_status", function()
  it("parses modified file", function()
    local result = git.parse_name_status("M\0src/foo.lua\0")
    assert.same({ { status = "M", path = "src/foo.lua" } }, result)
  end)

  it("parses added file", function()
    local result = git.parse_name_status("A\0new/bar.go\0")
    assert.same({ { status = "A", path = "new/bar.go" } }, result)
  end)

  it("parses deleted file", function()
    local result = git.parse_name_status("D\0old/baz.py\0")
    assert.same({ { status = "D", path = "old/baz.py" } }, result)
  end)

  it("parses rename (R100) as R, takes new path", function()
    local result = git.parse_name_status("R100\0old.lua\0new.lua\0")
    assert.same({ { status = "R", path = "new.lua" } }, result)
  end)

  it("parses multiple files", function()
    local result = git.parse_name_status("M\0a.lua\0A\0b.lua\0D\0c.lua\0")
    assert.equals(3, #result)
    assert.equals("M", result[1].status)
    assert.equals("A", result[2].status)
    assert.equals("D", result[3].status)
  end)

  it("returns empty table for empty output", function()
    local result = git.parse_name_status("")
    assert.same({}, result)
  end)

  it("preserves tabs and newlines in paths", function()
    local path = "dir/a\tb\nc.lua"
    assert.same({ { status = "M", path = path } }, git.parse_name_status("M\0" .. path .. "\0"))
  end)
end)
