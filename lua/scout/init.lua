local M = {}

local defaults = {
  keys = {
    start      = "<leader>rv",
    start_pick = "<leader>rV",
    quit       = "<leader>rq",
  },
  panel = {
    width    = 45,
    position = "topleft",
  },
  integrations = {
    gitsigns  = true,
    diffview  = true,
    telescope = true,
  },
}

local function deep_merge(base, override)
  local result = vim.deepcopy(base)
  for k, v in pairs(override or {}) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

local function start_pick(cfg)
  local use_telescope = cfg.integrations and cfg.integrations.telescope ~= false
  if use_telescope then
    local ok_tel, builtin     = pcall(require, "telescope.builtin")
    local ok_act, actions     = pcall(require, "telescope.actions")
    local ok_state, act_state = pcall(require, "telescope.actions.state")
    if ok_tel and ok_act and ok_state then
      builtin.git_branches({
        attach_mappings = function(prompt_bufnr, map)
          local function pick()
            local sel = act_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if sel then require("scout.session").start(sel.value) end
          end
          map("i", "<CR>", pick)
          map("n", "<CR>", pick)
          return true
        end,
      })
      return
    end
  end
  vim.ui.input({ prompt = "Base branch: " }, function(input)
    if input and input ~= "" then require("scout.session").start(input) end
  end)
end

function M.setup(opts)
  local cfg = deep_merge(defaults, opts or {})
  local session = require("scout.session")
  session.set_config(cfg)

  local keys = cfg.keys or {}

  if keys.start then
    vim.keymap.set("n", keys.start, function() session.start() end,
      { desc = "Scout: start review (auto base)" })
  end

  if keys.start_pick then
    vim.keymap.set("n", keys.start_pick, function() start_pick(cfg) end,
      { desc = "Scout: start review (pick base branch)" })
  end

  if keys.quit then
    vim.keymap.set("n", keys.quit, function() session.stop() end,
      { desc = "Scout: exit review" })
  end

  vim.api.nvim_create_user_command("Scout", function(args)
    session.start(args.args ~= "" and args.args or nil)
  end, {
    nargs = "?",
    desc = "Start branch review (optional base branch arg)",
  })

  vim.api.nvim_create_user_command("ScoutQuit", function()
    session.stop()
  end, { desc = "Exit branch review mode" })
end

return M
