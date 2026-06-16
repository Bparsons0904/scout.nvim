local panel = require("scout.panel")

describe("panel.file_at_line", function()
  after_each(function()
    panel.close()
  end)

  it("maps rows to files and nil to the blank/separator rows", function()
    panel.open(
      {
        { status = "M", path = "src/foo.lua" },
        { status = "A", path = "src/bar.lua" },
      },
      { ["src/bar.lua"] = "h1" },
      { integration_enabled = function() return false end },
      {},
      vim.fn.getcwd()
    )

    -- Row 1: the lone unreviewed file. Rows 2-3: blank + "reviewed" separator.
    -- Row 4: the reviewed file.
    assert.equals("src/foo.lua", panel.file_at_line(1).path)
    assert.is_nil(panel.file_at_line(2))
    assert.is_nil(panel.file_at_line(3))
    assert.equals("src/bar.lua", panel.file_at_line(4).path)
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
      { integration_enabled = function() return false end },
      {},
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
      { integration_enabled = function() return false end },
      {},
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
