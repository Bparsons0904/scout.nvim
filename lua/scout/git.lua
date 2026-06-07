local M = {}

-- Pure parser for `git diff --name-status -z` output.
-- Handles: M, A, D (single path) and R<score> (two paths, take second).
function M.parse_name_status(output)
  local files = {}
  local fields = {}
  local start = 1
  while true do
    local finish = output:find("\0", start, true)
    if not finish then break end
    table.insert(fields, output:sub(start, finish - 1))
    start = finish + 1
  end

  local i = 1
  while i <= #fields do
    local raw_status = fields[i]
    local status = raw_status and raw_status:sub(1, 1)
    if status == "R" then
      local new_path = fields[i + 2]
      if new_path then table.insert(files, { status = status, path = new_path }) end
      i = i + 3
    elseif status and status:match("[AMD]") then
      local path = fields[i + 1]
      if path then table.insert(files, { status = status, path = path }) end
      i = i + 2
    else
      i = i + 1
    end
  end
  return files
end

-- Returns the repo root (absolute path), or "" on failure.
function M.root()
  return vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("[\n\r]", "")
end

-- Returns the current HEAD SHA, or nil on failure.
function M.head()
  local sha = vim.fn.system("git rev-parse HEAD 2>/dev/null"):gsub("[\n\r]", "")
  if vim.v.shell_error ~= 0 or sha == "" then return nil end
  return sha
end

-- Returns "origin/main" style ref for the repo default branch, or nil.
-- Prefers the remote default; falls back to local main/master for repos
-- without an origin remote.
function M.default_branch()
  local ref = vim.fn.system("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null"):gsub("\n", "")
  if vim.v.shell_error == 0 and ref ~= "" then
    local short = ref:match("refs/remotes/(.+)$")
    if short then return short end
  end
  for _, candidate in ipairs({ "origin/main", "origin/master", "main", "master" }) do
    vim.fn.system("git rev-parse --verify " .. candidate .. " 2>/dev/null")
    if vim.v.shell_error == 0 then return candidate end
  end
  return nil
end

-- Returns merge-base SHA between base_ref and HEAD, or nil on failure.
function M.merge_base(base_ref)
  local sha = vim.fn.system("git merge-base " .. vim.fn.shellescape(base_ref) .. " HEAD 2>/dev/null"):gsub("\n", "")
  if vim.v.shell_error ~= 0 or sha == "" then return nil end
  return sha
end

-- Returns list of {status, path} for files changed between base_sha and HEAD.
function M.changed_files(base_sha)
  local result = vim.system(
    { "git", "diff", "--name-status", "-z", base_sha, "HEAD" },
    { text = false }
  ):wait()
  if result.code ~= 0 then return {} end
  return M.parse_name_status(result.stdout or "")
end

return M
