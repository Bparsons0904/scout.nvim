local M = {}

local git = require("scout.git")
local persist = require("scout.persist")
local gutters = require("scout.gutters")
local panel = require("scout.panel")
local diff = require("scout.diff")

local active = nil
local _config = {}

local function make_key(base_ref, base_sha)
  local root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("[\n\r]", "")
  local branch = vim.fn.system("git rev-parse --abbrev-ref HEAD 2>/dev/null"):gsub("[\n\r]", "")
  return root .. "|" .. branch .. "|" .. base_ref .. "|" .. base_sha
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

function M.start(base_override)
  if active then
    vim.notify("scout: already active — use <leader>rq to exit first", vim.log.levels.WARN)
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

  local files = git.changed_files(base_sha)
  if #files == 0 then
    vim.notify("scout: no changes vs " .. base_ref, vim.log.levels.INFO)
    return
  end

  local key = make_key(base_ref, base_sha)
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
  }

  if not _config.integrations or _config.integrations.gitsigns ~= false then
    gutters.activate(base_sha)
  end

  panel.open(files, reviewed, {
    on_select = function(path)
      local root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("[\n\r]", "")
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. path))
    end,
    on_diff = function(path)
      if not _config.integrations or _config.integrations.diffview ~= false then
        diff.open_file(active.base_sha, path)
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
  }, _config)

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
  panel.close()
  if not _config.integrations or _config.integrations.gitsigns ~= false then
    gutters.restore()
  end
  active = nil
  vim.notify("scout: exited", vim.log.levels.INFO)
end

function M.is_active()
  return active ~= nil
end

return M
