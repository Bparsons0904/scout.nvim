local filter = {}

local compiled_cache = {}

local function compile(pattern)
  local compiled = compiled_cache[pattern]
  if compiled == nil then
    compiled = "\\C" .. vim.fn.glob2regpat(pattern)
    compiled_cache[pattern] = compiled
  end
  return compiled
end

function filter.is_excluded(path, patterns)
  if not patterns then
    return false
  end
  for _, pattern in ipairs(patterns) do
    if vim.fn.match(path, compile(pattern)) >= 0 then
      return true
    end
  end
  return false
end

return filter
