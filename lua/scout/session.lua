local session = {}

local git = require("scout.git")
local persistence = require("scout.persist")
local gutters = require("scout.gutters")
local panel = require("scout.panel")
local diff = require("scout.diff")
local util = require("scout.util")

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

local DELETED_SENTINEL = "__deleted__"

function session._reconcile_reviewed(saved_reviewed, changed_files, blob_hash)
  local status_by_path = {}
  for _, file in ipairs(changed_files) do
    status_by_path[file.path] = file.status
  end

  local is_legacy = type(saved_reviewed[1]) == "string"
  local stored = {}
  if is_legacy then
    for _, path in ipairs(saved_reviewed) do
      stored[path] = true
    end
  else
    for path, hash in pairs(saved_reviewed) do
      stored[path] = hash
    end
  end

  local function current_hash(path)
    if status_by_path[path] == "D" then
      return DELETED_SENTINEL
    end
    return blob_hash(path)
  end

  local reviewed = {}
  for path, stored_hash in pairs(stored) do
    if status_by_path[path] then
      local now = current_hash(path)
      if stored_hash == true then
        -- Legacy entry without a hash: keep it and backfill the current hash.
        if now then
          reviewed[path] = now
        end
      elseif now and now == stored_hash then
        reviewed[path] = now
      end
    end
  end
  return reviewed
end

local function reconcile_batched(saved_reviewed, changed_files, repository_root)
  local stored_paths = {}
  if type(saved_reviewed[1]) == "string" then
    for _, path in ipairs(saved_reviewed) do
      stored_paths[#stored_paths + 1] = path
    end
  else
    for path in pairs(saved_reviewed) do
      stored_paths[#stored_paths + 1] = path
    end
  end
  local hashes = git.blob_hashes(stored_paths, repository_root)
  return session._reconcile_reviewed(saved_reviewed, changed_files, function(path)
    return hashes[path]
  end)
end

function session.integration_enabled(name)
  return not configuration.integrations or configuration.integrations[name] ~= false
end

function session._make_key(repository_root, branch, base_reference)
  return table.concat({ repository_root, branch, base_reference }, "|")
end

local function fingerprint_for(current, path)
  for _, file in ipairs(current.changed_files) do
    if file.path == path and file.status == "D" then
      return DELETED_SENTINEL
    end
  end
  return git.blob_hash(path, current.repository_root)
end

local function persist_reviewed()
  if not active_session then
    return
  end
  persistence.save(active_session.persistence_key, { reviewed = active_session.reviewed_paths })
end

local live_group = vim.api.nvim_create_augroup("scout_live_review", { clear = true })

local function setup_live_tracking()
  vim.api.nvim_clear_autocmds({ group = live_group })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = live_group,
    callback = function(event)
      if not active_session then
        return
      end
      local saved_path = event.file
      local relative_path = util.relative_to_root(saved_path, active_session.repository_root)
      if not relative_path then
        return
      end
      local stored_hash = active_session.reviewed_paths[relative_path]
      if not stored_hash then
        return
      end
      local current = git.blob_hash(relative_path, active_session.repository_root)
      if current and current ~= stored_hash then
        active_session.reviewed_paths[relative_path] = nil
        persist_reviewed()
        if panel.is_open() then
          panel.refresh()
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = live_group,
    callback = function()
      if not active_session then
        return
      end
      local head = git.head(active_session.repository_root)
      if head and head ~= active_session.head_commit then
        session.refresh()
      end
    end,
  })
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
      local target = vim.fs.normalize(current.repository_root .. "/" .. path)
      local opened, error_message = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(target))
      if not opened then
        vim.notify("scout: could not open " .. path .. ": " .. tostring(error_message), vim.log.levels.WARN)
      end
    end,
    on_diff = function(path)
      if session.integration_enabled("diffview") then
        diff.open_file(current.base_commit, path, current.repository_root, panel.focus)
      end
    end,
    on_reviewed = function(path, is_reviewed)
      if is_reviewed then
        local fingerprint = fingerprint_for(current, path)
        if fingerprint then
          current.reviewed_paths[path] = fingerprint
        else
          current.reviewed_paths[path] = nil
          vim.notify("scout: could not fingerprint " .. path .. "; not marked reviewed", vim.log.levels.WARN)
        end
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

  local base_reference = git.preferred_base_reference(base_reference_override or git.default_branch(repository_root), repository_root)
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
  local persistence_key = session._make_key(repository_root, branch, base_reference)
  local saved_state = persistence.load(persistence_key)
  local reviewed_paths = reconcile_batched(saved_state.reviewed or {}, changed_files, repository_root)

  active_session = {
    base_reference = base_reference,
    base_commit = base_commit,
    changed_files = changed_files,
    reviewed_paths = reviewed_paths,
    persistence_key = persistence_key,
    repository_root = repository_root,
    head_commit = head_commit,
  }

  persist_reviewed()
  setup_live_tracking()

  if session.integration_enabled("gitsigns") then
    gutters.activate(base_commit)
  end

  open_panel()

  local filter = require("scout.filter")
  local exclude_patterns = configuration.exclude or {}
  local visible_count = 0
  for _, file in ipairs(changed_files) do
    if not filter.is_excluded(file.path, exclude_patterns) then
      visible_count = visible_count + 1
    end
  end
  local reviewed_count = 0
  for path in pairs(reviewed_paths) do
    if not filter.is_excluded(path, exclude_patterns) then
      reviewed_count = reviewed_count + 1
    end
  end
  vim.notify(
    string.format(
      "scout: %s (%s) — %d files, %d reviewed",
      base_reference,
      base_commit:sub(1, 7),
      visible_count,
      reviewed_count
    ),
    vim.log.levels.INFO
  )
end

function session.refresh()
  local current = active_session
  if not current then
    vim.notify("scout: no active session", vim.log.levels.INFO)
    return
  end
  local base_reference = git.preferred_base_reference(current.base_reference, current.repository_root)
  local base_commit = git.merge_base(base_reference, current.repository_root)
  if not base_commit then
    vim.notify("scout: could not refresh merge-base with " .. base_reference, vim.log.levels.ERROR)
    return
  end

  local changed_files, changed_files_error = git.changed_files(base_commit, current.repository_root)
  if not changed_files then
    vim.notify("scout: could not refresh: " .. (changed_files_error or "unknown Git error"), vim.log.levels.ERROR)
    return
  end
  local reviewed_paths = reconcile_batched(current.reviewed_paths, changed_files, current.repository_root)
  current.base_reference = base_reference
  current.base_commit = base_commit
  current.changed_files = changed_files
  current.reviewed_paths = reviewed_paths
  current.head_commit = git.head(current.repository_root) or current.head_commit
  persist_reviewed()
  if session.integration_enabled("gitsigns") then
    gutters.activate(base_commit)
  end
  if panel.is_open() then
    panel.set_files(changed_files, reviewed_paths)
  end
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
  vim.api.nvim_clear_autocmds({ group = live_group })
  vim.notify("scout: exited", vim.log.levels.INFO)
end

function session.is_active()
  return active_session ~= nil
end

return session
