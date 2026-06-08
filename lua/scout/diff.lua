local M = {}

local active = nil
local group = vim.api.nvim_create_augroup("scout_diffview", { clear = true })

local function map_close(buf)
  vim.keymap.set("n", "q", function() M.close() end, {
    buffer = buf,
    desc = "Scout: close diff and return to panel",
    nowait = true,
    silent = true,
  })
end

local function map_tab(tab)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    map_close(vim.api.nvim_win_get_buf(win))
  end
end

function M.open_file(base_sha, filepath, on_close)
  if not pcall(require, "diffview") then
    vim.notify("scout: diffview.nvim not available — install sindrets/diffview.nvim for side-by-side diffs", vim.log.levels.WARN)
    return
  end

  M.close(false)
  local source_tab = vim.api.nvim_get_current_tabpage()
  local ok, err = pcall(
    vim.cmd,
    "DiffviewOpen " .. vim.fn.shellescape(base_sha) .. "...HEAD -- " .. vim.fn.fnameescape(filepath)
  )
  if not ok then
    vim.notify("scout: could not open diffview: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  local diff_tab = vim.api.nvim_get_current_tabpage()
  if diff_tab == source_tab then
    vim.notify("scout: diffview did not open a new tab", vim.log.levels.ERROR)
    return
  end
  active = { tab = diff_tab, source_tab = source_tab, on_close = on_close }

  map_tab(diff_tab)
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
      if active and vim.api.nvim_get_current_tabpage() == active.tab then
        map_close(args.buf)
      end
    end,
  })
end

function M.close(return_to_source)
  if not active then return end
  local closing = active
  active = nil
  vim.api.nvim_clear_autocmds({ group = group })

  if vim.api.nvim_tabpage_is_valid(closing.tab) then
    vim.api.nvim_set_current_tabpage(closing.tab)
    pcall(vim.cmd, "DiffviewClose")
  end

  if return_to_source ~= false and vim.api.nvim_tabpage_is_valid(closing.source_tab) then
    vim.api.nvim_set_current_tabpage(closing.source_tab)
    if closing.on_close then closing.on_close() end
  end
end

return M
