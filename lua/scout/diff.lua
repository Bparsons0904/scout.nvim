local diff = {}

local active_diff = nil
local autocommand_group = vim.api.nvim_create_augroup("scout_diffview", { clear = true })

local function map_close(buffer)
  vim.keymap.set("n", "q", function()
    diff.close()
  end, {
    buffer = buffer,
    desc = "Scout: close diff and return to panel",
    nowait = true,
    silent = true,
  })
end

local function map_tabpage(tabpage)
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    map_close(vim.api.nvim_win_get_buf(window))
  end
end

function diff.open_file(base_commit, file_path, repository_root, on_close)
  if not pcall(require, "diffview") then
    vim.notify(
      "scout: diffview.nvim not available — install sindrets/diffview.nvim for side-by-side diffs",
      vim.log.levels.WARN
    )
    return
  end

  diff.close(false)
  local source_tabpage = vim.api.nvim_get_current_tabpage()
  local opened, error_message = pcall(function()
    vim.cmd(
      "DiffviewOpen "
        .. vim.fn.fnameescape("-C" .. repository_root)
        .. " "
        .. base_commit
        .. "...HEAD -- "
        .. vim.fn.fnameescape(file_path)
    )
  end)
  if not opened then
    vim.notify("scout: could not open diffview: " .. tostring(error_message), vim.log.levels.ERROR)
    return
  end

  local diff_tabpage = vim.api.nvim_get_current_tabpage()
  if diff_tabpage == source_tabpage then
    vim.notify("scout: diffview did not open a new tab", vim.log.levels.ERROR)
    return
  end
  active_diff = { tabpage = diff_tabpage, source_tabpage = source_tabpage, on_close = on_close }

  map_tabpage(diff_tabpage)
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = autocommand_group,
    callback = function(event)
      if active_diff and vim.api.nvim_get_current_tabpage() == active_diff.tabpage then
        map_close(event.buf)
      end
    end,
  })
end

function diff.close(return_to_source)
  if not active_diff then
    return
  end
  local closing_diff = active_diff
  active_diff = nil
  vim.api.nvim_clear_autocmds({ group = autocommand_group })

  if vim.api.nvim_tabpage_is_valid(closing_diff.tabpage) then
    vim.api.nvim_set_current_tabpage(closing_diff.tabpage)
    pcall(function()
      vim.cmd("DiffviewClose")
    end)
  end

  if return_to_source ~= false and vim.api.nvim_tabpage_is_valid(closing_diff.source_tabpage) then
    vim.api.nvim_set_current_tabpage(closing_diff.source_tabpage)
    if closing_diff.on_close then
      closing_diff.on_close()
    end
  end
end

return diff
