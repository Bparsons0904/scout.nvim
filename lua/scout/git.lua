local M = {}

-- Pure parser — separated for unit-testability without running git.
-- Handles: M, A, D (single path) and R<score> (two paths, take second).
function M.parse_name_status(output)
  local files = {}
  for line in output:gmatch("[^\n]+") do
    if line:match("^R%d+") then
      local new_path = line:match("^R%d+\t[^\t]+\t(.+)$")
      if new_path then
        table.insert(files, { status = "R", path = new_path })
      end
    else
      local status, path = line:match("^([AMD])\t(.+)$")
      if status and path then
        table.insert(files, { status = status, path = path })
      end
    end
  end
  return files
end

-- Returns "origin/main" style ref for the repo default branch, or nil.
function M.default_branch()
  local ref = vim.fn.system("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null"):gsub("\n", "")
  if vim.v.shell_error == 0 and ref ~= "" then
    local short = ref:match("refs/remotes/(.+)$")
    if short then return short end
  end
  for _, candidate in ipairs({ "origin/main", "origin/master" }) do
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
  local output = vim.fn.system(
    "git diff --name-status " .. vim.fn.shellescape(base_sha) .. " HEAD 2>/dev/null"
  )
  if vim.v.shell_error ~= 0 then return {} end
  return M.parse_name_status(output)
end

return M
