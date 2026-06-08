local session = {}

local git = require("scout.git")
local persistence = require("scout.persist")
local gutters = require("scout.gutters")
local panel = require("scout.panel")
local diff = require("scout.diff")

---@class ScoutSession
---@field base_reference string
---@field base_commit string
---@field changed_files table[]
---@field reviewed_paths table<string, boolean>
---@field persistence_key string
---@field repository_root string
---@field head_commit string

---@type ScoutSession?
local active_session = nil
local configuration = {}

function session.integration_enabled(name)
  return not configuration.integrations or configuration.integrations[name] ~= false
end

function session._make_key(repository_root, branch, base_reference, base_commit, head_commit)
  return table.concat({ repository_root, branch, base_reference, base_commit, head_commit }, "|")
end

local function persist_reviewed()
  if not active_session then
    return
  end
  local reviewed_paths = {}
  for path in pairs(active_session.reviewed_paths) do
    table.insert(reviewed_paths, path)
  end
  persistence.save(active_session.persistence_key, { reviewed = reviewed_paths })
end

function session.set_config(new_configuration)
  configuration = new_configuration or {}
end

local function open_panel()
  local current = active_session
  if not current then
    return
  end
  panel.open(current.changed_files, current.reviewed_paths, {
    integration_enabled = session.integration_enabled,
    on_select = function(path)
      vim.cmd("edit " .. vim.fn.fnameescape(current.repository_root .. "/" .. path))
    end,
    on_diff = function(path)
      if session.integration_enabled("diffview") then
        diff.open_file(current.base_commit, path, current.repository_root, panel.focus)
      end
    end,
    on_reviewed = function(path, is_reviewed)
      if is_reviewed then
        current.reviewed_paths[path] = true
      else
        current.reviewed_paths[path] = nil
      end
      persist_reviewed()
    end,
  }, configuration, current.repository_root)
end

function session.start(base_reference_override)
  if active_session then
    -- Closing the panel intentionally keeps the review session alive.
    if base_reference_override and base_reference_override ~= active_session.base_reference then
      vim.notify(
        "scout: already reviewing "
          .. active_session.base_reference
          .. " — use <leader>rq to exit before switching base",
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

  local repository_root = git.root_for_path(vim.api.nvim_buf_get_name(0))
  if not repository_root then
    vim.notify("scout: could not determine repository root", vim.log.levels.ERROR)
    return
  end

  local base_reference = base_reference_override or git.default_branch(repository_root)
  if not base_reference then
    vim.notify("scout: could not determine default branch", vim.log.levels.ERROR)
    return
  end

  local base_commit = git.merge_base(base_reference, repository_root)
  if not base_commit then
    vim.notify("scout: could not compute merge-base with " .. base_reference, vim.log.levels.ERROR)
    return
  end

  local changed_files, changed_files_error = git.changed_files(base_commit, repository_root)
  if not changed_files then
    vim.notify(
      "scout: could not list changed files: " .. (changed_files_error or "unknown Git error"),
      vim.log.levels.ERROR
    )
    return
  end
  if #changed_files == 0 then
    vim.notify("scout: no changes vs " .. base_reference, vim.log.levels.INFO)
    return
  end

  local head_commit = git.head(repository_root)
  if not head_commit then
    vim.notify("scout: could not determine current HEAD", vim.log.levels.ERROR)
    return
  end
  local branch = git.current_branch(repository_root)
  if not branch then
    vim.notify("scout: could not determine current branch", vim.log.levels.ERROR)
    return
  end
  local persistence_key = session._make_key(repository_root, branch, base_reference, base_commit, head_commit)
  local saved_state = persistence.load(persistence_key)
  local reviewed_paths = {}
  for _, path in ipairs(saved_state.reviewed or {}) do
    reviewed_paths[path] = true
  end

  active_session = {
    base_reference = base_reference,
    base_commit = base_commit,
    changed_files = changed_files,
    reviewed_paths = reviewed_paths,
    persistence_key = persistence_key,
    repository_root = repository_root,
    head_commit = head_commit,
  }

  if session.integration_enabled("gitsigns") then
    gutters.activate(base_commit)
  end

  open_panel()

  local reviewed_count = 0
  for _ in pairs(reviewed_paths) do
    reviewed_count = reviewed_count + 1
  end
  vim.notify(
    string.format(
      "scout: %s (%s) — %d files, %d reviewed",
      base_reference,
      base_commit:sub(1, 7),
      #changed_files,
      reviewed_count
    ),
    vim.log.levels.INFO
  )
end

function session.stop()
  if not active_session then
    vim.notify("scout: no active session", vim.log.levels.INFO)
    return
  end
  diff.close(false)
  panel.close()
  if session.integration_enabled("gitsigns") then
    gutters.restore()
  end
  active_session = nil
  vim.notify("scout: exited", vim.log.levels.INFO)
end

function session.is_active()
  return active_session ~= nil
end

return session
