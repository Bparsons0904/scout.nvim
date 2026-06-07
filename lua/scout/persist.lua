local M = {}

local function state_dir()
  local dir = vim.fn.stdpath("state") .. "/scout"
  vim.fn.mkdir(dir, "p")
  return dir
end

local function state_path(key)
  local safe = key:gsub("[/\\|:*?\"<>]", "_"):sub(1, 180)
  return state_dir() .. "/" .. safe .. ".json"
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
  local f = io.open(path, "w")
  if not f then
    vim.notify("scout: could not write state to " .. path, vim.log.levels.WARN)
    return
  end
  f:write(vim.fn.json_encode(data))
  f:close()
end

return M
