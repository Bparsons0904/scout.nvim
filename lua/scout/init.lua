local scout = {}

local defaults = {
  keys = {
    start = "<leader>rv",
    start_pick = "<leader>rV",
    quit = "<leader>rq",
    toggle_inline = "<leader>ri",
  },
  panel = {
    width = 45,
    position = "topleft",
  },
  integrations = {
    gitsigns = true,
    diffview = true,
    telescope = true,
  },
  exclude = {},
}

function scout._deep_merge(base, override)
  local merged_table = vim.deepcopy(base)
  for key, value in pairs(override or {}) do
    if type(value) == "table" and type(merged_table[key]) == "table" then
      merged_table[key] = scout._deep_merge(merged_table[key], value)
    else
      merged_table[key] = value
    end
  end
  return merged_table
end

local function start_branch_picker()
  local repository_root = require("scout.git").root_for_path(vim.api.nvim_buf_get_name(0))

  if require("scout.session").integration_enabled("telescope") then
    local builtin_loaded, telescope_builtin = pcall(require, "telescope.builtin")
    local actions_loaded, telescope_actions = pcall(require, "telescope.actions")
    local action_state_loaded, telescope_action_state = pcall(require, "telescope.actions.state")
    if builtin_loaded and actions_loaded and action_state_loaded then
      telescope_builtin.git_branches({
        cwd = repository_root,
        attach_mappings = function(prompt_buffer, set_mapping)
          local function select_branch()
            local selection = telescope_action_state.get_selected_entry()
            telescope_actions.close(prompt_buffer)
            if selection then
              require("scout.session").start(selection.value)
            end
          end
          set_mapping("i", "<CR>", select_branch)
          set_mapping("n", "<CR>", select_branch)
          return true
        end,
      })
      return
    end
  end
  vim.ui.input({ prompt = "Base branch: " }, function(input)
    if input and input ~= "" then
      require("scout.session").start(input)
    end
  end)
end

local registered_lhs = {}

function scout.setup(options)
  local configuration = scout._deep_merge(defaults, options or {})
  local session = require("scout.session")
  session.set_config(configuration)

  for _, lhs in ipairs(registered_lhs) do
    pcall(vim.keymap.del, "n", lhs)
  end
  registered_lhs = {}

  local keymaps = configuration.keys or {}

  local function register_key(lhs, callback, desc)
    vim.keymap.set("n", lhs, callback, { desc = desc })
    registered_lhs[#registered_lhs + 1] = lhs
  end

  if keymaps.start then
    register_key(keymaps.start, function()
      session.start()
    end, "Scout: start review (auto base)")
  end

  if keymaps.start_pick then
    register_key(keymaps.start_pick, function()
      start_branch_picker()
    end, "Scout: start review (pick base branch)")
  end

  if keymaps.toggle_inline then
    register_key(keymaps.toggle_inline, function()
      require("scout.gutters").toggle_inline()
    end, "Scout: toggle inline diff view")
  end

  if keymaps.quit then
    register_key(keymaps.quit, function()
      session.stop()
    end, "Scout: exit review")
  end

  vim.api.nvim_create_user_command("Scout", function(command)
    session.start(command.args ~= "" and command.args or nil)
  end, {
    nargs = "?",
    desc = "Start branch review (optional base branch argument)",
    force = true,
  })

  vim.api.nvim_create_user_command("ScoutQuit", function()
    session.stop()
  end, { desc = "Exit branch review mode", force = true })

  vim.api.nvim_create_user_command("ScoutRefresh", function()
    session.refresh()
  end, { desc = "Re-scan changed files for the active review", force = true })

  vim.api.nvim_create_user_command("ScoutInline", function()
    require("scout.gutters").toggle_inline()
  end, { desc = "Toggle the inline (unified) diff view", force = true })

  vim.api.nvim_create_user_command("ScoutDiffClose", function()
    require("scout.diff").close()
  end, { desc = "Close Scout diff and return to the panel", force = true })
end

return scout
