local panel = require("scout.panel")

describe("panel.path_from_line", function()
  it("parses an unreviewed line", function()
    local path, status = panel.path_from_line("  M  src/foo.lua")
    assert.equals("src/foo.lua", path)
    assert.equals("M", status)
  end)

  it("parses a reviewed line with the ✓ prefix", function()
    local path, status = panel.path_from_line("\xE2\x9C\x93 M  src/store.ts")
    assert.equals("src/store.ts", path)
    assert.equals("M", status)
  end)

  it("parses each status letter", function()
    for _, s in ipairs({ "A", "D", "R" }) do
      local path, status = panel.path_from_line("  " .. s .. "  a/b.lua")
      assert.equals("a/b.lua", path)
      assert.equals(s, status)
    end
  end)

  it("keeps spaces inside the path", function()
    local path = panel.path_from_line("  M  my dir/my file.lua")
    assert.equals("my dir/my file.lua", path)
  end)

  it("returns nil for the reviewed separator", function()
    assert.is_nil(panel.path_from_line("── reviewed ─────────────────────────"))
  end)

  it("returns nil for a blank line", function()
    assert.is_nil(panel.path_from_line(""))
  end)
end)

describe("panel rendering", function()
  after_each(function()
    panel.close()
    package.loaded.gitsigns = nil
    package.preload.gitsigns = nil
  end)

  it("escapes control characters in displayed paths", function()
    panel.open(
      { { status = "M", path = "dir/a\tb\nc.lua" } },
      {},
      {},
      { integrations = { gitsigns = false } },
      vim.fn.getcwd()
    )

    assert.same({ "  M  dir/a^Ib^@c.lua" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it("previews the captured row without loading disabled gitsigns", function()
    local gitsigns_loaded = false
    package.preload.gitsigns = function()
      gitsigns_loaded = true
      return {}
    end

    panel.open(
      {
        { status = "M", path = "README.md" },
        { status = "M", path = "doc/scout.txt" },
      },
      {},
      {},
      { integrations = { gitsigns = false } },
      vim.fn.getcwd()
    )

    local panel_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = panel_buf })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.wait(300)

    local main_name
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
      if name ~= "Scout" then main_name = name end
    end

    assert.equals(vim.fn.getcwd() .. "/README.md", main_name)
    assert.is_false(gitsigns_loaded)
  end)
end)
