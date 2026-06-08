# scout.nvim

Structured branch review mode for Neovim. Scout gives you a file panel for the current branch's changes, per-file reviewed tracking, auto-preview on hover, and session persistence — so you can work through a PR diff methodically without losing your place.

## Features

- Side panel listing all changed files split into unreviewed / reviewed sections, with color-coded status letters and per-file +added/-deleted line counts
- Mark files as reviewed with `r`; progress persists across restarts until the branch receives a new commit
- Auto-preview: hovering a file opens it in the main window and, with gitsigns enabled, jumps to the first changed hunk
- `d` opens a full side-by-side diff via diffview.nvim
- Gitsigns gutters show diffs relative to the merge-base, not HEAD
- Telescope branch picker for choosing the base branch
- All integrations are optional and degrade gracefully

## Installation

Requires Neovim 0.10+ and Git.

```lua
-- lazy.nvim
{
  "Bparsons0904/scout.nvim",
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

1. `:Scout` — start a session in the current buffer's repository, falling back to cwd (auto-detects the default branch: origin's HEAD, `origin/main`/`origin/master`, or local `main`/`master`)
2. `:Scout my-base-branch` — start against a specific base
3. `<leader>rV` — open a Telescope branch picker to choose the base
4. In the panel: `<CR>` open · `d` diff · `r` toggle reviewed · `q` close · `?` help (for deleted files, `<CR>` opens the diff). `q` only closes the panel — the session stays alive, so `:Scout` (or `<leader>rv`) reopens it.
5. In a Scout-opened Diffview: `q` or `:ScoutDiffClose` closes the diff and returns to the Scout panel
6. `:ScoutQuit` or `<leader>rq` — exit review mode from either Scout or its Diffview

## Panel

```
  M  src/components/Button.tsx                 +24 -6
  A  src/utils/api.ts                          +58

── reviewed ─────────────────────────
✓ M  src/store.ts                              +3 -3
✓ D  src/old-file.js                           -41
```

The status letter is color-coded (A green, M/R/T orange, D red) and each file
shows its added/deleted line counts, right-aligned.

Run `:checkhealth scout` to verify Git and optional integrations.

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

## AI acknowledgement

This plugin was built with AI assistance (Claude Code and Codex). AI was used to accelerate
proof-of-concept exploration, write and refine the test suite, and help debug
edge cases. All code was reviewed, tested, and is maintained by a human; the
architecture, design decisions, and final shape of the project are my own.

## License

MIT
