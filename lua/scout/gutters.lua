local gutters = {}

local inline_enabled = false

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

-- Unified inline diff: deleted lines as virtual lines, added lines highlighted,
-- word-level marks within changed lines — all relative to the base set by activate().
function gutters.set_inline(enabled)
  local loaded, gitsigns = pcall(require, "gitsigns")
  if not loaded then
    vim.notify(
      "scout: gitsigns not available — install lewis6991/gitsigns.nvim for the inline diff view",
      vim.log.levels.WARN
    )
    return inline_enabled
  end
  -- gitsigns toggles are global config, so this applies to every buffer until restore().
  pcall(gitsigns.toggle_deleted, enabled)
  pcall(gitsigns.toggle_linehl, enabled)
  pcall(gitsigns.toggle_word_diff, enabled)
  inline_enabled = enabled
  return inline_enabled
end

function gutters.toggle_inline()
  return gutters.set_inline(not inline_enabled)
end

function gutters.inline_enabled()
  return inline_enabled
end

function gutters.restore()
  local loaded, gitsigns = pcall(require, "gitsigns")
  if not loaded then
    inline_enabled = false
    return
  end
  gutters.set_inline(false)
  pcall(gitsigns.change_base, nil, true)
end

return gutters
