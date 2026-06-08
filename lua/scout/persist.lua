local persistence = {}

local function state_directory()
  local directory = vim.fn.stdpath("state") .. "/scout"
  vim.fn.mkdir(directory, "p")
  return directory
end

local function state_path(persistence_key)
  return state_directory() .. "/" .. vim.fn.sha256(persistence_key) .. ".json"
end

local function replace_file(source, target)
  if os.rename(source, target) then
    return true
  end

  -- Windows does not replace an existing target with rename. The fallback is
  -- not atomic, but still avoids leaving a partial JSON file behind.
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
  local decoded, saved_state = pcall(vim.fn.json_decode, file_content)
  if decoded and type(saved_state) == "table" then
    return saved_state
  end
  return {}
end

function persistence.save(persistence_key, state_data)
  local persistence_path = state_path(persistence_key)
  local temporary_path = persistence_path .. ".tmp." .. tostring(vim.uv.hrtime())
  local file = io.open(temporary_path, "w")
  if not file then
    vim.notify("scout: could not write state to " .. persistence_path, vim.log.levels.WARN)
    return
  end
  local write_succeeded = file:write(vim.fn.json_encode(state_data)) ~= nil
  local close_succeeded = file:close()
  local replace_succeeded = write_succeeded and close_succeeded and replace_file(temporary_path, persistence_path)
  if not replace_succeeded then
    pcall(os.remove, temporary_path)
    vim.notify("scout: could not write state to " .. persistence_path, vim.log.levels.WARN)
  end
end

return persistence
