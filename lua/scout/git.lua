local M = {}

local function split_nul(output)
  local fields = {}
  local start = 1
  while true do
    local finish = output:find("\0", start, true)
    if not finish then break end
    table.insert(fields, output:sub(start, finish - 1))
    start = finish + 1
  end
  return fields
end

local function trim_newlines(value)
  return value:gsub("[\r\n]+$", "")
end

local function run(args)
  local result = vim.system(args, { text = true }):wait()
  if result.code ~= 0 then
    return nil, trim_newlines(result.stderr or "")
  end
  return trim_newlines(result.stdout or "")
end

-- Pure parser for `git diff --name-status -z` output.
-- Handles A, D, M, T (single path) and R<score> (two paths, take second).
function M.parse_name_status(output)
  local files = {}
  local fields = split_nul(output)

  local i = 1
  while i <= #fields do
    local raw_status = fields[i]
    local status = raw_status and raw_status:sub(1, 1)
    if status == "R" then
      local new_path = fields[i + 2]
      if new_path then table.insert(files, { status = status, path = new_path }) end
      i = i + 3
    elseif status and status:match("[ADMT]") then
      local path = fields[i + 1]
      if path then table.insert(files, { status = status, path = path }) end
      i = i + 2
    else
      i = i + 1
    end
  end
  return files
end

-- Pure parser for `git diff --numstat -z` output. Returns a map of
-- path -> { added = N, deleted = N }. Binary files (git prints `-`) yield
-- nil counts. Renames carry NUL-separated old/new paths; keyed by the new
-- path to match parse_name_status.
function M.parse_numstat(output)
  local fields = split_nul(output)

  local stats = {}
  local i = 1
  while i <= #fields do
    local added, deleted, path = fields[i]:match("^(%S+)\t(%S+)\t(.*)$")
    if added then
      local entry = { added = tonumber(added), deleted = tonumber(deleted) }
      if path == "" then
        -- rename: fields[i+1] = old path, fields[i+2] = new path
        local new_path = fields[i + 2]
        if new_path then stats[new_path] = entry end
        i = i + 3
      else
        stats[path] = entry
        i = i + 1
      end
    else
      i = i + 1
    end
  end
  return stats
end

-- Returns the repo root (absolute path), or nil and an error on failure.
function M.root()
  return run({ "git", "rev-parse", "--show-toplevel" })
end

-- Returns the current HEAD SHA, or nil and an error on failure.
function M.head()
  return run({ "git", "rev-parse", "HEAD" })
end

-- Returns the current branch name, or "HEAD" when detached.
function M.current_branch()
  return run({ "git", "rev-parse", "--abbrev-ref", "HEAD" })
end

-- Returns "origin/main" style ref for the repo default branch, or nil.
-- Prefers the remote default; falls back to local main/master for repos
-- without an origin remote.
function M.default_branch()
  local ref = run({ "git", "symbolic-ref", "refs/remotes/origin/HEAD" })
  if ref then
    local short = ref:match("refs/remotes/(.+)$")
    if short then return short end
  end
  for _, candidate in ipairs({ "origin/main", "origin/master", "main", "master" }) do
    if run({ "git", "rev-parse", "--verify", candidate }) then return candidate end
  end
  return nil
end

-- Returns merge-base SHA between base_ref and HEAD, or nil and an error.
function M.merge_base(base_ref)
  return run({ "git", "merge-base", base_ref, "HEAD" })
end

-- Returns list of {status, path, added, deleted} for files changed between
-- base_sha and HEAD. added/deleted are nil for binary files (or when numstat
-- is unavailable). Returns nil and an error when the name-status diff fails.
function M.changed_files(base_sha)
  local result = vim.system(
    { "git", "diff", "--no-ext-diff", "--name-status", "-z", base_sha, "HEAD", "--" },
    { text = false }
  ):wait()
  if result.code ~= 0 then return nil, trim_newlines(result.stderr or "") end
  local files = M.parse_name_status(result.stdout or "")

  local numstat = vim.system(
    { "git", "diff", "--no-ext-diff", "--numstat", "-z", base_sha, "HEAD", "--" },
    { text = false }
  ):wait()
  if numstat.code == 0 then
    local stats = M.parse_numstat(numstat.stdout or "")
    for _, f in ipairs(files) do
      local s = stats[f.path]
      if s then
        f.added = s.added
        f.deleted = s.deleted
      end
    end
  end
  return files
end

return M
