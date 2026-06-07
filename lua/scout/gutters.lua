local M = {}

function M.activate(base_sha)
  local ok, gs = pcall(require, "gitsigns")
  if not ok then
    vim.notify("scout: gitsigns not available — install lewis6991/gitsigns.nvim for hunk gutters", vim.log.levels.WARN)
    return
  end
  local ok2, err = pcall(gs.change_base, base_sha, true)
  if not ok2 then
    vim.notify("scout: change_base failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.restore()
  local ok, gs = pcall(require, "gitsigns")
  if not ok then return end
  pcall(gs.change_base, nil, true)
end

return M
