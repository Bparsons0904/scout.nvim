local M = {}

local function state_dir()
  local dir = vim.fn.stdpath("state") .. "/scout"
  vim.fn.mkdir(dir, "p")
  return dir
end

local function state_path(key)
  return state_dir() .. "/" .. vim.fn.sha256(key) .. ".json"
end

local function replace_file(source, target)
  if os.rename(source, target) then return true end

  -- Windows does not replace an existing target with rename. The fallback is
  -- not atomic, but still avoids leaving a partial JSON file behind.
  if vim.uv.os_uname().sysname == "Windows_NT"
      and vim.uv.fs_unlink(target)
      and os.rename(source, target) then
    return true
  end
  return false
end

function M.load(key)
  local path = state_path(key)
  local f = io.open(path, "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.fn.json_decode, content)
  if ok and type(data) == "table" then return data end
  return {}
end

function M.save(key, data)
  local path = state_path(key)
  local tmp = path .. ".tmp." .. tostring(vim.uv.hrtime())
  local f = io.open(tmp, "w")
  if not f then
    vim.notify("scout: could not write state to " .. path, vim.log.levels.WARN)
    return
  end
  local write_ok = f:write(vim.fn.json_encode(data)) ~= nil
  local close_ok = f:close()
  local rename_ok = write_ok and close_ok and replace_file(tmp, path)
  if not rename_ok then
    pcall(os.remove, tmp)
    vim.notify("scout: could not write state to " .. path, vim.log.levels.WARN)
  end
end

return M
