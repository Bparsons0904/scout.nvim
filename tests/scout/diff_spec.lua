local diff = require("scout.diff")

describe("diffview integration", function()
  local original_cmd
  local original_diffview
  local open_command

  before_each(function()
    original_cmd = vim.cmd
    original_diffview = package.loaded.diffview
    package.loaded.diffview = {}
    diff.close(false)
    open_command = nil

    vim.cmd = function(command)
      if command:match("^DiffviewOpen") then
        open_command = command
        original_cmd("tabnew")
      elseif command == "DiffviewClose" then
        original_cmd("tabclose")
      else
        original_cmd(command)
      end
    end
  end)

  after_each(function()
    diff.close(false)
    vim.cmd = original_cmd
    package.loaded.diffview = original_diffview
  end)

  it("maps q to close the diff tab and return to the source tab", function()
    local source_tab = vim.api.nvim_get_current_tabpage()
    local tab_count = #vim.api.nvim_list_tabpages()
    local returned = false

    diff.open_file("abc123", "README.md", "/tmp/repo with spaces", function() returned = true end)

    assert.equals(tab_count + 1, #vim.api.nvim_list_tabpages())
    assert.equals([[DiffviewOpen -C/tmp/repo\ with\ spaces abc123...HEAD -- README.md]], open_command)
    local mapping = vim.fn.maparg("q", "n", false, true)
    assert.is_function(mapping.callback)
    mapping.callback()

    assert.equals(tab_count, #vim.api.nvim_list_tabpages())
    assert.equals(source_tab, vim.api.nvim_get_current_tabpage())
    assert.is_true(returned)
  end)
end)
