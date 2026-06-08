local M = {}

local git = require("scout.git")
local persist = require("scout.persist")
local gutters = require("scout.gutters")
local panel = require("scout.panel")
local diff = require("scout.diff")

local active = nil
local _config = {}

-- An integration is on unless the user explicitly set it to false.
function M.integration_enabled(name)
  return not _config.integrations or _config.integrations[name] ~= false
end

-- Exposed (underscore-prefixed) for unit testing; not part of the public API.
function M._make_key(root, branch, base_ref, base_sha, head_sha)
  return table.concat({ root, branch, base_ref, base_sha, head_sha }, "|")
end

local function persist_reviewed()
  if not active then return end
  local list = {}
  for path in pairs(active.reviewed) do
    table.insert(list, path)
  end
  persist.save(active.key, { reviewed = list })
end

function M.set_config(cfg)
  _config = cfg or {}
end

-- Opens the panel for the current `active` session, wiring its callbacks.
-- Shared by a fresh start and by reopening the panel after it was closed.
local function open_panel()
  panel.open(active.files, active.reviewed, {
    integration_enabled = M.integration_enabled,
    on_select = function(path)
      vim.cmd("edit " .. vim.fn.fnameescape(active.root .. "/" .. path))
    end,
    on_diff = function(path)
      if M.integration_enabled("diffview") then
        diff.open_file(active.base_sha, path, panel.focus)
      end
    end,
    on_reviewed = function(path, is_reviewed)
      if is_reviewed then
        active.reviewed[path] = true
      else
        active.reviewed[path] = nil
      end
      persist_reviewed()
    end,
  }, _config, active.root)
end

function M.start(base_override)
  if active then
    -- A session is already running. Closing the panel with `q` keeps the
    -- session alive, so re-running start just reopens (or focuses) the panel
    -- rather than erroring. Switching to a different base must quit first.
    if base_override and base_override ~= active.base_ref then
      vim.notify(
        "scout: already reviewing " .. active.base_ref .. " — use <leader>rq to exit before switching base",
        vim.log.levels.WARN
      )
      return
    end
    if panel.is_open() then
      panel.focus()
    else
      open_panel()
    end
    return
  end

  local base_ref = base_override or git.default_branch()
  if not base_ref then
    vim.notify("scout: could not determine default branch", vim.log.levels.ERROR)
    return
  end

  local base_sha = git.merge_base(base_ref)
  if not base_sha then
    vim.notify("scout: could not compute merge-base with " .. base_ref, vim.log.levels.ERROR)
    return
  end

  local files, files_err = git.changed_files(base_sha)
  if not files then
    vim.notify("scout: could not list changed files: " .. (files_err or "unknown Git error"), vim.log.levels.ERROR)
    return
  end
  if #files == 0 then
    vim.notify("scout: no changes vs " .. base_ref, vim.log.levels.INFO)
    return
  end

  local root = git.root()
  if not root then
    vim.notify("scout: could not determine repository root", vim.log.levels.ERROR)
    return
  end
  local head_sha = git.head()
  if not head_sha then
    vim.notify("scout: could not determine current HEAD", vim.log.levels.ERROR)
    return
  end
  local branch = git.current_branch()
  if not branch then
    vim.notify("scout: could not determine current branch", vim.log.levels.ERROR)
    return
  end
  local key = M._make_key(root, branch, base_ref, base_sha, head_sha)
  local saved = persist.load(key)
  local reviewed = {}
  for _, path in ipairs(saved.reviewed or {}) do
    reviewed[path] = true
  end

  active = {
    base_ref = base_ref,
    base_sha = base_sha,
    files = files,
    reviewed = reviewed,
    key = key,
    root = root,
    head_sha = head_sha,
  }

  if M.integration_enabled("gitsigns") then
    gutters.activate(base_sha)
  end

  open_panel()

  local done = 0
  for _ in pairs(reviewed) do done = done + 1 end
  vim.notify(
    string.format(
      "scout: %s (%s) — %d files, %d reviewed",
      base_ref,
      base_sha:sub(1, 7),
      #files,
      done
    ),
    vim.log.levels.INFO
  )
end

function M.stop()
  if not active then
    vim.notify("scout: no active session", vim.log.levels.INFO)
    return
  end
  diff.close(false)
  panel.close()
  if M.integration_enabled("gitsigns") then
    gutters.restore()
  end
  active = nil
  vim.notify("scout: exited", vim.log.levels.INFO)
end

function M.is_active()
  return active ~= nil
end

return M
