local util = {}

function util.relative_to_root(absolute_path, repository_root)
  if not absolute_path or absolute_path == "" or not repository_root then
    return nil
  end
  local normalized = vim.fs.normalize(absolute_path)
  local root_prefix = vim.fs.normalize(repository_root) .. "/"
  if normalized:sub(1, #root_prefix) == root_prefix then
    return normalized:sub(#root_prefix + 1)
  end
  return nil
end

return util
