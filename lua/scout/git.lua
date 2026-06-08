local git = {}

local function split_nul(output)
  local fields = {}
  local start_index = 1
  while true do
    local finish_index = output:find("\0", start_index, true)
    if not finish_index then
      break
    end
    table.insert(fields, output:sub(start_index, finish_index - 1))
    start_index = finish_index + 1
  end
  return fields
end

local function trim_newlines(value)
  return value:gsub("[\r\n]+$", "")
end

local function command(arguments, repository_root)
  local result = { "git" }
  if repository_root then
    vim.list_extend(result, { "-C", repository_root })
  end
  vim.list_extend(result, arguments)
  return result
end

local function run(arguments, repository_root)
  local command_result = vim.system(command(arguments, repository_root), { text = true }):wait()
  if command_result.code ~= 0 then
    return nil, trim_newlines(command_result.stderr or "")
  end
  return trim_newlines(command_result.stdout or "")
end

function git.parse_name_status(output)
  local parsed_files = {}
  local fields = split_nul(output)

  local field_index = 1
  while field_index <= #fields do
    local raw_status = fields[field_index]
    local status = raw_status and raw_status:sub(1, 1)
    if status == "R" then
      local new_path = fields[field_index + 2]
      if new_path then
        table.insert(parsed_files, { status = status, path = new_path })
      end
      field_index = field_index + 3
    elseif status and status:match("[ADMT]") then
      local path = fields[field_index + 1]
      if path then
        table.insert(parsed_files, { status = status, path = path })
      end
      field_index = field_index + 2
    else
      field_index = field_index + 1
    end
  end
  return parsed_files
end

function git.parse_numstat(output)
  local fields = split_nul(output)

  local statistics = {}
  local field_index = 1
  while field_index <= #fields do
    local added_lines, deleted_lines, path = fields[field_index]:match("^(%S+)\t(%S+)\t(.*)$")
    if added_lines then
      local statistics_entry = { added = tonumber(added_lines), deleted = tonumber(deleted_lines) }
      if path == "" then
        -- Rename records store the path in the second following NUL field.
        local new_path = fields[field_index + 2]
        if new_path then
          statistics[new_path] = statistics_entry
        end
        field_index = field_index + 3
      else
        statistics[path] = statistics_entry
        field_index = field_index + 1
      end
    else
      field_index = field_index + 1
    end
  end
  return statistics
end

function git.root(start_directory)
  return run({ "rev-parse", "--show-toplevel" }, start_directory)
end

function git.root_for_path(path)
  if path and path ~= "" then
    local start_directory = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
    local repository_root = git.root(start_directory)
    if repository_root then
      return repository_root
    end
  end
  return git.root()
end

function git.head(repository_root)
  return run({ "rev-parse", "HEAD" }, repository_root)
end

function git.current_branch(repository_root)
  return run({ "rev-parse", "--abbrev-ref", "HEAD" }, repository_root)
end

function git.default_branch(repository_root)
  local reference = run({ "symbolic-ref", "refs/remotes/origin/HEAD" }, repository_root)
  if reference then
    local short_reference = reference:match("refs/remotes/(.+)$")
    if short_reference then
      return short_reference
    end
  end
  for _, candidate in ipairs({ "origin/main", "origin/master", "main", "master" }) do
    if run({ "rev-parse", "--verify", candidate }, repository_root) then
      return candidate
    end
  end
  return nil
end

function git.merge_base(base_reference, repository_root)
  return run({ "merge-base", base_reference, "HEAD" }, repository_root)
end

function git.changed_files(base_commit, repository_root)
  local name_status_result = vim
    .system(
      command({ "diff", "--no-ext-diff", "--name-status", "-z", base_commit, "HEAD", "--" }, repository_root),
      { text = false }
    )
    :wait()
  if name_status_result.code ~= 0 then
    return nil, trim_newlines(name_status_result.stderr or "")
  end
  local changed_files = git.parse_name_status(name_status_result.stdout or "")

  local numstat_result = vim
    .system(
      command({ "diff", "--no-ext-diff", "--numstat", "-z", base_commit, "HEAD", "--" }, repository_root),
      { text = false }
    )
    :wait()
  if numstat_result.code == 0 then
    local statistics = git.parse_numstat(numstat_result.stdout or "")
    for _, file in ipairs(changed_files) do
      local file_statistics = statistics[file.path]
      if file_statistics then
        file.added = file_statistics.added
        file.deleted = file_statistics.deleted
      end
    end
  end
  return changed_files
end

return git
