# scout.nvim

Structured branch review mode for Neovim. Scout gives you a file panel for the current branch's changes, per-file reviewed tracking, auto-preview on hover, and session persistence — so you can work through a PR diff methodically without losing your place.

## Features

- Side panel listing all changed files (M/A/D/R) split into unreviewed / reviewed sections
- Mark files as reviewed with `r`; progress persists across restarts
- Auto-preview: hovering a file opens it in the main window and jumps to the first changed hunk
- `d` opens a full side-by-side diff via diffview.nvim
- Gitsigns gutters show diffs relative to the merge-base, not HEAD
- Telescope branch picker for choosing the base branch
- All integrations are optional and degrade gracefully

## Installation

```lua
-- lazy.nvim
{
  "bobparsons/scout.nvim",
  dependencies = {
    "lewis6991/gitsigns.nvim",        -- optional: hunk gutters
    "sindrets/diffview.nvim",         -- optional: side-by-side diff
    "nvim-telescope/telescope.nvim",  -- optional: branch picker
  },
  opts = {},
}
```

## Configuration

All options are optional. Defaults shown:

```lua
require("scout").setup({
  keys = {
    start      = "<leader>rv",   -- start review (auto-detect base)
    start_pick = "<leader>rV",   -- start review (pick base branch)
    quit       = "<leader>rq",   -- exit review mode
  },
  panel = {
    width    = 45,
    position = "topleft",        -- "topleft" | "botright"
  },
  integrations = {
    gitsigns  = true,
    diffview  = true,
    telescope = true,
  },
})
```

Set a keymap to `false` to disable it.

## Usage

1. `:Scout` — start a session (auto-detects `origin/main` or `origin/master`)
2. `:Scout my-base-branch` — start against a specific base
3. `<leader>rV` — open a Telescope branch picker to choose the base
4. In the panel: `<CR>` open · `d` diff · `r` toggle reviewed · `q` close · `?` help
5. `:ScoutQuit` or `<leader>rq` — exit review mode

## Panel

```
  M  src/components/Button.tsx
  A  src/utils/api.ts

── reviewed ─────────────────────────
✓ M  src/store.ts
✓ D  src/old-file.js
```

## Recommended diffview.nvim settings

Scout opens diffview with `:DiffviewOpen` but can't control diffview's global layout or highlight settings. For the best experience, configure diffview like this in your own diffview spec:

```lua
{
  "sindrets/diffview.nvim",
  opts = {
    enhanced_diff_hl = true,
    view = {
      default = { layout = "diff2_horizontal" },
    },
    file_panel = {
      win_config = { width = 35 },
    },
  },
}
```

These are user preferences (horizontal vs vertical split, panel width, highlight intensity) so they intentionally live in your config rather than being forced by scout.

## License

MIT
