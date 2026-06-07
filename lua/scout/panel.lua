local M = {}

local ns = vim.api.nvim_create_namespace("scout_panel")

local state = {
  buf = nil,
  win = nil,
  main_win = nil,
  preview_path = nil,
  preview_timer = nil,
  root = nil,
  files = {},
  line_files = {},
  reviewed = {},
  callbacks = {},
  config = {},
}

local function render()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

  vim.bo[state.buf].modifiable = true
  local lines = {}
  local line_files = {}
  local unreviewed, done = {}, {}

  for _, f in ipairs(state.files) do
    if state.reviewed[f.path] then
      table.insert(done, f)
    else
      table.insert(unreviewed, f)
    end
  end

  for _, f in ipairs(unreviewed) do
    table.insert(lines, string.format("  %s  %s", f.status, vim.fn.strtrans(f.path)))
    table.insert(line_files, f)
  end

  if #done > 0 then
    table.insert(lines, "")
    table.insert(line_files, false)
    table.insert(lines, "── reviewed ─────────────────────────")
    table.insert(line_files, false)
    for _, f in ipairs(done) do
      table.insert(lines, string.format("\xE2\x9C\x93 %s  %s", f.status, vim.fn.strtrans(f.path)))
      table.insert(line_files, f)
    end
  end

  state.line_files = line_files
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  local separator_idx = nil
  for i, l in ipairs(lines) do
    if l:match("^\xe2\x94\x80\xe2\x94\x80") then separator_idx = i break end
  end
  if separator_idx then
    for i = separator_idx, #lines do
      vim.hl.range(state.buf, ns, "Comment", { i - 1, 0 }, { i - 1, -1 })
    end
  end
end

-- Returns path, status parsed from a rendered panel line. Tolerant of both
-- "  M  path" (unreviewed) and "\xE2\x9C\x93 M  path" (reviewed; ✓ = 3 UTF-8
-- bytes). Returns nil for non-file lines (blank, separator). Exposed for tests.
function M.path_from_line(line)
  local status, path = line:match("^.-%s+([AMDR])%s+(.+)$")
  return path, status
end

local function current_file()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  return state.line_files[row] or nil
end

function M.open(files, reviewed, callbacks, config, root)
  if M.is_open() then M.close() end

  state.files = files
  state.reviewed = reviewed or {}
  state.callbacks = callbacks or {}
  state.config = config or {}
  state.root = root

  -- Capture the editing window before the panel split steals focus.
  -- Used by <CR> so files open in the main area, not inside the panel.
  state.main_win = vim.api.nvim_get_current_win()

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].swapfile = false

  local position = (state.config.panel and state.config.panel.position) or "topleft"
  vim.cmd(position .. " vsplit")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)
  vim.api.nvim_win_set_width(state.win, (state.config.panel and state.config.panel.width) or 45)
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"
  vim.wo[state.win].wrap = false
  vim.wo[state.win].cursorline = true
  pcall(vim.api.nvim_buf_set_name, state.buf, "Scout")

  render()

  local opts = { buffer = state.buf, noremap = true, silent = true }

  vim.keymap.set("n", "<CR>", function()
    local file = current_file()
    if not file then return end
    -- A deleted file has no working-tree copy to open; show its diff instead.
    if file.status == "D" then
      if state.callbacks.on_diff then state.callbacks.on_diff(file.path) end
      return
    end
    if state.callbacks.on_select then
      if state.main_win and vim.api.nvim_win_is_valid(state.main_win) then
        vim.api.nvim_set_current_win(state.main_win)
      end
      state.callbacks.on_select(file.path)
    end
  end, opts)

  vim.keymap.set("n", "d", function()
    local file = current_file()
    if file and state.callbacks.on_diff then
      state.callbacks.on_diff(file.path)
    end
  end, opts)

  vim.keymap.set("n", "r", function()
    local file = current_file()
    if not file then return end
    local path = file.path
    local now_reviewed = not state.reviewed[path]
    if now_reviewed then
      state.reviewed[path] = true
    else
      state.reviewed[path] = nil
    end
    if state.callbacks.on_reviewed then
      state.callbacks.on_reviewed(path, now_reviewed)
    end
    render()
    -- restore cursor to the toggled path's new position after re-render
    local buf_lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
    for i = 1, #buf_lines do
      if state.line_files[i] and state.line_files[i].path == path then
        pcall(vim.api.nvim_win_set_cursor, state.win, { i, 0 })
        break
      end
    end
  end, opts)

  vim.keymap.set("n", "q", function() M.close() end, opts)
  vim.keymap.set("n", "?", function()
    vim.notify(
      "Scout panel:\n<CR> open file  d diff  r toggle reviewed  q close",
      vim.log.levels.INFO
    )
  end, opts)

  -- Auto-preview: hover a file → open it in main window and jump to first hunk.
  -- Debounced so rapid cursor movement doesn't open every intermediate file.
  -- Two-phase: edit immediately, defer hunk jump to let gitsigns attach async.
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = state.buf,
    callback = function()
      local file = current_file()
      if state.preview_timer then
        state.preview_timer:stop()
        pcall(function() state.preview_timer:close() end)
        state.preview_timer = nil
      end
      if not file or file.status == "D" then return end
      local path = file.path
      local panel_buf = state.buf
      local t = vim.uv.new_timer()
      state.preview_timer = t
      t:start(150, 0, vim.schedule_wrap(function()
        if state.preview_timer == t then state.preview_timer = nil end
        t:stop()
        pcall(function() t:close() end)

        if state.buf ~= panel_buf then return end
        if not (state.main_win and vim.api.nvim_win_is_valid(state.main_win)) then return end
        if path == state.preview_path then return end
        state.preview_path = path

        local abs = state.root .. "/" .. path
        local cur_name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(state.main_win))

        -- Phase 1: open the file in main window without stealing panel focus
        vim.api.nvim_win_call(state.main_win, function()
          if cur_name ~= abs then
            vim.cmd("edit " .. vim.fn.fnameescape(abs))
          end
        end)

        -- Phase 2: jump to first hunk after gitsigns has had time to attach.
        -- Uses get_hunks() (sync) + direct cursor set to avoid gitsigns' async
        -- nav_hunk, which fires after nvim_win_call context is gone and errors.
        local use_gitsigns = not state.config.integrations or state.config.integrations.gitsigns ~= false
        if use_gitsigns then
          vim.defer_fn(function()
            if not (state.main_win and vim.api.nvim_win_is_valid(state.main_win)) then return end
            if state.preview_path ~= path then return end
            local ok, gs = pcall(require, "gitsigns")
            if not ok then return end
            local buf = vim.api.nvim_win_get_buf(state.main_win)
            local hunks = gs.get_hunks(buf)
            if not hunks or #hunks == 0 then return end
            local h = hunks[1]
            local lnum = (h.added and h.added.start > 0 and h.added.start)
                      or (h.removed and h.removed.start > 0 and h.removed.start)
                      or 1
            local line_count = vim.api.nvim_buf_line_count(buf)
            lnum = math.max(1, math.min(lnum, line_count))
            vim.api.nvim_win_set_cursor(state.main_win, { lnum, 0 })
            vim.api.nvim_win_call(state.main_win, function()
              vim.cmd("norm! zz")
            end)
          end, 80)
        end
      end))
    end,
  })
end

function M.close()
  if state.preview_timer then
    state.preview_timer:stop()
    pcall(function() state.preview_timer:close() end)
    state.preview_timer = nil
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.main_win = nil
  state.preview_path = nil
  state.root = nil
  state.files = {}
  state.line_files = {}
  state.reviewed = {}
  state.callbacks = {}
  state.config = {}
end

function M.is_open()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

function M.focus()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
  end
end

return M
