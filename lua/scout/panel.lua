local panel = {}

local namespace = vim.api.nvim_create_namespace("scout_panel")

local STATUS_HIGHLIGHTS = {
  A = "ScoutStatusAdded",
  M = "ScoutStatusModified",
  D = "ScoutStatusDeleted",
  R = "ScoutStatusRenamed",
  T = "ScoutStatusTypeChanged",
}

local function setup_highlights()
  local set_highlight = function(name, link)
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
  set_highlight("ScoutStatusAdded", "Added")
  set_highlight("ScoutStatusModified", "Changed")
  set_highlight("ScoutStatusDeleted", "Removed")
  set_highlight("ScoutStatusRenamed", "Changed")
  set_highlight("ScoutStatusTypeChanged", "Changed")
  set_highlight("ScoutAdded", "Added")
  set_highlight("ScoutDeleted", "Removed")
end

local highlight_group = vim.api.nvim_create_augroup("scout_panel_highlights", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = highlight_group,
  callback = setup_highlights,
})

local state = {
  buffer = nil,
  window = nil,
  main_window = nil,
  preview_path = nil,
  preview_timer = nil,
  repository_root = nil,
  changed_files = {},
  files_by_line = {},
  reviewed_paths = {},
  callback_handlers = {},
  configuration = {},
  exclude_patterns = {},
  show_excluded = false,
}

local function render()
  if not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then
    return
  end

  local filter = require("scout.filter")
  vim.bo[state.buffer].modifiable = true
  local lines = {}
  local files_by_line = {}
  local unreviewed_files, reviewed_files = {}, {}
  local separator_index = nil

  for _, file in ipairs(state.changed_files) do
    if not state.show_excluded and filter.is_excluded(file.path, state.exclude_patterns) then
      -- hidden
    elseif state.reviewed_paths[file.path] then
      table.insert(reviewed_files, file)
    else
      table.insert(unreviewed_files, file)
    end
  end

  local highlight_marks = {}

  for _, file in ipairs(unreviewed_files) do
    table.insert(lines, string.format("  %s  %s", file.status, vim.fn.strtrans(file.path)))
    table.insert(files_by_line, file)
    table.insert(highlight_marks, { line = #lines - 1, file = file, status_column = 2 })
  end

  if #reviewed_files > 0 then
    table.insert(lines, "")
    table.insert(files_by_line, false)
    table.insert(lines, "── reviewed ─────────────────────────")
    table.insert(files_by_line, false)
    separator_index = #lines
    for _, file in ipairs(reviewed_files) do
      table.insert(lines, string.format("\xE2\x9C\x93 %s  %s", file.status, vim.fn.strtrans(file.path)))
      table.insert(files_by_line, file)
      table.insert(highlight_marks, { line = #lines - 1, file = file, status_column = 4 })
    end
  end

  state.files_by_line = files_by_line
  vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
  vim.bo[state.buffer].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buffer, namespace, 0, -1)
  if separator_index then
    for line_index = separator_index, #lines do
      vim.api.nvim_buf_set_extmark(state.buffer, namespace, line_index - 1, 0, {
        end_col = #(lines[line_index] or ""),
        hl_group = "Comment",
      })
    end
  end

  for _, mark in ipairs(highlight_marks) do
    local highlight = STATUS_HIGHLIGHTS[mark.file.status]
    if highlight then
      vim.api.nvim_buf_set_extmark(state.buffer, namespace, mark.line, mark.status_column, {
        end_col = mark.status_column + 1,
        hl_group = highlight,
      })
    end
    local virtual_text = {}
    if mark.file.added then
      table.insert(virtual_text, { "+" .. mark.file.added, "ScoutAdded" })
    end
    if mark.file.deleted then
      if #virtual_text > 0 then
        table.insert(virtual_text, { " " })
      end
      table.insert(virtual_text, { "-" .. mark.file.deleted, "ScoutDeleted" })
    end
    if #virtual_text > 0 then
      table.insert(virtual_text, { " " })
      vim.api.nvim_buf_set_extmark(state.buffer, namespace, mark.line, 0, {
        virt_text = virtual_text,
        virt_text_pos = "right_align",
      })
    end
  end
end

function panel.file_at_line(line_number)
  return state.files_by_line[line_number] or nil
end

local function current_file()
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  return state.files_by_line[line_number] or nil
end

function panel.open(changed_files, reviewed_paths, callback_handlers, configuration, repository_root)
  if panel.is_open() then
    panel.close()
  end

  setup_highlights()

  state.changed_files = changed_files
  state.reviewed_paths = reviewed_paths or {}
  state.callback_handlers = callback_handlers or {}
  state.configuration = configuration or {}
  state.exclude_patterns = (configuration and configuration.exclude) or {}
  state.show_excluded = false
  state.repository_root = repository_root

  state.main_window = vim.api.nvim_get_current_win()
  local focused_path = vim.api.nvim_buf_get_name(0)

  state.buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buffer].buftype = "nofile"
  vim.bo[state.buffer].bufhidden = "wipe"
  vim.bo[state.buffer].swapfile = false

  local position = (state.configuration.panel and state.configuration.panel.position) or "topleft"
  vim.cmd(position .. " vsplit")
  state.window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.window, state.buffer)
  vim.api.nvim_win_set_width(state.window, (state.configuration.panel and state.configuration.panel.width) or 45)
  vim.wo[state.window].number = false
  vim.wo[state.window].relativenumber = false
  vim.wo[state.window].signcolumn = "no"
  vim.wo[state.window].wrap = false
  vim.wo[state.window].cursorline = true
  pcall(vim.api.nvim_buf_set_name, state.buffer, "Scout")

  render()

  local relative_path = require("scout.util").relative_to_root(focused_path, repository_root)
  if relative_path then
    for line_number, file in ipairs(state.files_by_line) do
      if file and file.path == relative_path then
        state.preview_path = relative_path
        pcall(vim.api.nvim_win_set_cursor, state.window, { line_number, 0 })
        break
      end
    end
  end

  local keymap_options = { buffer = state.buffer, noremap = true, silent = true }

  vim.keymap.set("n", "<CR>", function()
    local file = current_file()
    if not file then
      return
    end
    -- Deleted files have no working-tree copy to open.
    if file.status == "D" then
      if state.callback_handlers.on_diff then
        state.callback_handlers.on_diff(file.path)
      end
      return
    end
    if state.callback_handlers.on_select then
      if state.main_window and vim.api.nvim_win_is_valid(state.main_window) then
        vim.api.nvim_set_current_win(state.main_window)
      end
      state.callback_handlers.on_select(file.path)
    end
  end, keymap_options)

  vim.keymap.set("n", "d", function()
    local file = current_file()
    if file and state.callback_handlers.on_diff then
      state.callback_handlers.on_diff(file.path)
    end
  end, keymap_options)

  vim.keymap.set("n", "r", function()
    local file = current_file()
    if not file then
      return
    end
    local path = file.path
    local is_now_reviewed = not state.reviewed_paths[path]
    if is_now_reviewed then
      state.reviewed_paths[path] = true
    else
      state.reviewed_paths[path] = nil
    end
    if state.callback_handlers.on_reviewed then
      state.callback_handlers.on_reviewed(path, is_now_reviewed)
    end
    render()
    local buffer_lines = vim.api.nvim_buf_get_lines(state.buffer, 0, -1, false)
    for line_number = 1, #buffer_lines do
      if state.files_by_line[line_number] and state.files_by_line[line_number].path == path then
        pcall(vim.api.nvim_win_set_cursor, state.window, { line_number, 0 })
        break
      end
    end
  end, keymap_options)

  vim.keymap.set("n", "x", function()
    state.show_excluded = not state.show_excluded
    render()
  end, keymap_options)

  vim.keymap.set("n", "q", function()
    panel.close()
  end, keymap_options)
  vim.keymap.set("n", "?", function()
    vim.notify(
      "Scout panel:\n<CR> open file  d diff  r toggle reviewed  x toggle excluded  q close",
      vim.log.levels.INFO
    )
  end, keymap_options)

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = state.buffer,
    callback = function()
      local file = current_file()
      if state.preview_timer then
        state.preview_timer:stop()
        pcall(function()
          state.preview_timer:close()
        end)
        state.preview_timer = nil
      end
      if not file or file.status == "D" then
        return
      end
      local path = file.path
      local panel_buffer = state.buffer
      local preview_timer = vim.uv.new_timer()
      if not preview_timer then
        return
      end
      state.preview_timer = preview_timer
      preview_timer:start(
        150,
        0,
        vim.schedule_wrap(function()
          if state.preview_timer == preview_timer then
            state.preview_timer = nil
          end
          preview_timer:stop()
          pcall(function()
            preview_timer:close()
          end)

          if state.buffer ~= panel_buffer then
            return
          end
          if not (state.main_window and vim.api.nvim_win_is_valid(state.main_window)) then
            return
          end
          if path == state.preview_path then
            return
          end
          state.preview_path = path

          local absolute_path = vim.fs.normalize(state.repository_root .. "/" .. path)
          local current_buffer_name =
            vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(state.main_window)))

          vim.api.nvim_win_call(state.main_window, function()
            if current_buffer_name ~= absolute_path then
              -- Fails silently: a notify per cursor move would spam; keepjumps keeps the jumplist clean.
              pcall(vim.cmd, "keepjumps edit " .. vim.fn.fnameescape(absolute_path))
            end
          end)

          -- Direct cursor placement avoids gitsigns navigation firing after nvim_win_call exits.
          local integration_enabled = state.callback_handlers.integration_enabled
          local gitsigns_enabled = not integration_enabled or integration_enabled("gitsigns")
          if gitsigns_enabled then
            vim.defer_fn(function()
              if not (state.main_window and vim.api.nvim_win_is_valid(state.main_window)) then
                return
              end
              if state.preview_path ~= path then
                return
              end
              local loaded, gitsigns = pcall(require, "gitsigns")
              if not loaded or type(gitsigns.get_hunks) ~= "function" then
                return
              end
              local buffer = vim.api.nvim_win_get_buf(state.main_window)
              local hunks = gitsigns.get_hunks(buffer)
              if not hunks or #hunks == 0 then
                return
              end
              local first_hunk = hunks[1]
              local line_number = (first_hunk.added and first_hunk.added.start > 0 and first_hunk.added.start)
                or (first_hunk.removed and first_hunk.removed.start > 0 and first_hunk.removed.start)
                or 1
              local line_count = vim.api.nvim_buf_line_count(buffer)
              line_number = math.max(1, math.min(line_number, line_count))
              vim.api.nvim_win_set_cursor(state.main_window, { line_number, 0 })
              vim.api.nvim_win_call(state.main_window, function()
                vim.cmd("norm! zz")
              end)
            end, 80)
          end
        end)
      )
    end,
  })
end

function panel.close()
  if state.preview_timer then
    state.preview_timer:stop()
    pcall(function()
      state.preview_timer:close()
    end)
    state.preview_timer = nil
  end
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    vim.api.nvim_win_close(state.window, true)
  end
  state.window = nil
  state.buffer = nil
  state.main_window = nil
  state.preview_path = nil
  state.repository_root = nil
  state.changed_files = {}
  state.files_by_line = {}
  state.reviewed_paths = {}
  state.callback_handlers = {}
  state.configuration = {}
  state.exclude_patterns = {}
  state.show_excluded = false
end

function panel.is_open()
  return state.buffer ~= nil and vim.api.nvim_buf_is_valid(state.buffer)
end

function panel.focus()
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    vim.api.nvim_set_current_win(state.window)
  end
end

function panel.refresh()
  render()
end

function panel.set_files(changed_files, reviewed_paths)
  state.changed_files = changed_files or {}
  if reviewed_paths then
    state.reviewed_paths = reviewed_paths
  end
  render()
end

return panel
