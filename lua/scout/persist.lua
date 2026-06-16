local persistence = {}

local PRUNE_AGE_SECONDS = 90 * 24 * 60 * 60
local pruned = false

local function state_directory()
  local directory = vim.fn.stdpath("state") .. "/scout"
  vim.fn.mkdir(directory, "p")
  return directory
end

local function prune_old_state(directory)
  if pruned then
    return
  end
  pruned = true
  pcall(function()
    local now = os.time()
    for name, entry_type in vim.fs.dir(directory) do
      if entry_type == "file" and name:match("%.json$") then
        local path = directory .. "/" .. name
        local stat = vim.uv.fs_stat(path)
        if stat and (now - stat.mtime.sec) > PRUNE_AGE_SECONDS then
          os.remove(path)
        end
      end
    end
  end)
end

local function state_path(persistence_key)
  return state_directory() .. "/" .. vim.fn.sha256(persistence_key) .. ".json"
end

local function replace_file(source, target)
  if os.rename(source, target) then
    return true
  end

  if vim.uv.os_uname().sysname == "Windows_NT" and vim.uv.fs_unlink(target) and os.rename(source, target) then
    return true
  end
  return false
end

function persistence.load(persistence_key)
  local persistence_path = state_path(persistence_key)
  local file = io.open(persistence_path, "r")
  if not file then
    return {}
  end
  local file_content = file:read("*a")
  file:close()
  local decoded, saved_state = pcall(vim.json.decode, file_content)
  if decoded and type(saved_state) == "table" then
    return saved_state
  end
  return {}
end

function persistence.save(persistence_key, state_data)
  local persistence_path = state_path(persistence_key)
  prune_old_state(state_directory())
  local temporary_path = persistence_path .. ".tmp." .. tostring(vim.uv.hrtime())
  local file = io.open(temporary_path, "w")
  if not file then
    vim.notify("scout: could not write state to " .. persistence_path, vim.log.levels.WARN)
    return
  end
  local encoded_ok, encoded = pcall(vim.json.encode, state_data)
  local write_succeeded = encoded_ok and file:write(encoded) ~= nil
  local close_succeeded = file:close()
  local replace_succeeded = write_succeeded and close_succeeded and replace_file(temporary_path, persistence_path)
  if not replace_succeeded then
    pcall(os.remove, temporary_path)
    vim.notify("scout: could not write state to " .. persistence_path, vim.log.levels.WARN)
  end
end

return persistence
