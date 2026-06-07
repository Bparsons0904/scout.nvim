local M = {}

function M.open_file(base_sha, filepath)
  if not pcall(require, "diffview") then
    vim.notify("scout: diffview.nvim not available — install sindrets/diffview.nvim for side-by-side diffs", vim.log.levels.WARN)
    return
  end
  vim.cmd("DiffviewOpen " .. vim.fn.shellescape(base_sha) .. "...HEAD -- " .. vim.fn.fnameescape(filepath))
end

return M
