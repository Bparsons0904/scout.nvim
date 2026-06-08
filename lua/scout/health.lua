local M = {}

local function module_available(name)
  if package.loaded[name] then return true end
  local path = "lua/" .. name:gsub("%.", "/")
  return #vim.api.nvim_get_runtime_file(path .. ".lua", false) > 0
      or #vim.api.nvim_get_runtime_file(path .. "/init.lua", false) > 0
end

function M.check()
  vim.health.start("scout.nvim")

  if vim.fn.executable("git") == 1 then
    vim.health.ok("git is available")
  else
    vim.health.error("git is required but was not found")
  end

  for _, integration in ipairs({ "gitsigns", "diffview", "telescope" }) do
    if module_available(integration) then
      vim.health.ok(integration .. " is available")
    else
      vim.health.info(integration .. " is not installed (optional)")
    end
  end
end

return M
