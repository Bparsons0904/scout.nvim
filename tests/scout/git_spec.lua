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

  it("parses a typechange", function()
    local result = git.parse_name_status("T\0script.sh\0")
    assert.same({ { status = "T", path = "script.sh" } }, result)
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

describe("git commands", function()
  it("returns nil and an error outside a git repository", function()
    local previous = vim.fn.getcwd()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    vim.cmd.cd(tmp)

    local root, err = git.root()

    vim.cmd.cd(previous)
    vim.fn.delete(tmp, "rf")
    assert.is_nil(root)
    assert.is_string(err)
  end)

  it("runs against an explicit repository when cwd is elsewhere", function()
    local repository_root = assert(git.root())
    local expected_head = assert(git.head(repository_root))
    local previous = vim.fn.getcwd()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    vim.cmd.cd(tmp)

    local actual_root = git.root(repository_root)
    local actual_head = git.head(repository_root)

    vim.cmd.cd(previous)
    vim.fn.delete(tmp, "rf")
    assert.equals(repository_root, actual_root)
    assert.equals(expected_head, actual_head)
  end)

  it("resolves a repository from a file path when cwd is elsewhere", function()
    local repository_root = assert(git.root())
    local previous = vim.fn.getcwd()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    vim.cmd.cd(tmp)

    local actual_root = git.root_for_path(repository_root .. "/README.md")

    vim.cmd.cd(previous)
    vim.fn.delete(tmp, "rf")
    assert.equals(repository_root, actual_root)
  end)
end)

describe("git.parse_numstat", function()
  it("parses added/deleted counts for a file", function()
    assert.same(
      { ["src/foo.lua"] = { added = 12, deleted = 3 } },
      git.parse_numstat("12\t3\tsrc/foo.lua\0")
    )
  end)

  it("yields nil counts for binary files", function()
    assert.same({ ["bin.dat"] = {} }, git.parse_numstat("-\t-\tbin.dat\0"))
  end)

  it("keys a rename by its new path", function()
    assert.same(
      { ["new.lua"] = { added = 5, deleted = 2 } },
      git.parse_numstat("5\t2\t\0old.lua\0new.lua\0")
    )
  end)

  it("parses multiple files", function()
    local stats = git.parse_numstat("1\t0\ta.lua\0" .. "0\t4\tb.lua\0")
    assert.same({ added = 1, deleted = 0 }, stats["a.lua"])
    assert.same({ added = 0, deleted = 4 }, stats["b.lua"])
  end)

  it("preserves tabs in paths", function()
    local path = "dir/a\tb.lua"
    assert.same({ [path] = { added = 1, deleted = 1 } }, git.parse_numstat("1\t1\t" .. path .. "\0"))
  end)

  it("returns empty table for empty output", function()
    assert.same({}, git.parse_numstat(""))
  end)
end)

describe("git.blob_hash", function()
  local git = require("scout.git")
  local dir

  before_each(function()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
  end)

  after_each(function()
    vim.fn.delete(dir, "rf")
  end)

  it("returns a 40-char hash and is stable for identical content", function()
    vim.fn.writefile({ "hello" }, dir .. "/a.txt")
    local first = git.blob_hash("a.txt", dir)
    local second = git.blob_hash("a.txt", dir)
    assert.is_truthy(first)
    assert.equals(40, #first)
    assert.equals(first, second)
  end)

  it("changes when content changes", function()
    vim.fn.writefile({ "hello" }, dir .. "/a.txt")
    local before = git.blob_hash("a.txt", dir)
    vim.fn.writefile({ "hello world" }, dir .. "/a.txt")
    local after = git.blob_hash("a.txt", dir)
    assert.not_equals(before, after)
  end)

  it("returns nil for a missing file", function()
    assert.is_nil(git.blob_hash("missing.txt", dir))
  end)
end)

describe("git.blob_hashes", function()
  local git = require("scout.git")
  local dir

  before_each(function()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
  end)

  after_each(function()
    vim.fn.delete(dir, "rf")
  end)

  it("hashes many files in one batch and skips a missing one", function()
    vim.fn.writefile({ "hello" }, dir .. "/a.txt")
    vim.fn.writefile({ "world" }, dir .. "/b.txt")

    local hashes = git.blob_hashes({ "a.txt", "missing.txt", "b.txt" }, dir)

    assert.equals(git.blob_hash("a.txt", dir), hashes["a.txt"])
    assert.equals(git.blob_hash("b.txt", dir), hashes["b.txt"])
    assert.is_nil(hashes["missing.txt"])
  end)

  it("returns an empty map for no paths", function()
    assert.same({}, git.blob_hashes({}, dir))
  end)
end)
