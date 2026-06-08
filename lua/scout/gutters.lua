local gutters = {}

function gutters.activate(base_commit)
  local loaded, gitsigns = pcall(require, "gitsigns")
  if not loaded then
    vim.notify(
      "scout: gitsigns not available — install lewis6991/gitsigns.nvim for hunk gutters",
      vim.log.levels.WARN
    )
    return
  end
  local changed_base, error_message = pcall(gitsigns.change_base, base_commit, true)
  if not changed_base then
    vim.notify("scout: change_base failed: " .. tostring(error_message), vim.log.levels.ERROR)
  end
end

function gutters.restore()
  local loaded, gitsigns = pcall(require, "gitsigns")
  if not loaded then
    return
  end
  pcall(gitsigns.change_base, nil, true)
end

return gutters
