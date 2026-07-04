# Repository Guidelines

## Project Structure & Module Organization

This repository is a Neovim plugin written in Lua. Runtime source lives in
`lua/scout/`, with `lua/scout/init.lua` exposing setup, commands, and keymaps.
Core behavior is split by concern: `git.lua`, `session.lua`, `panel.lua`,
`persist.lua`, `diff.lua`, `filter.lua`, `gutters.lua`, and `health.lua`.
Tests live in `tests/scout/` and mirror the module names with `*_spec.lua`
files. Test bootstrap code is in `tests/minimal_init.lua`, and the executable
test wrapper is `tests/run.sh`. User-facing help documentation is in
`doc/scout.txt`.

## Build, Test, and Development Commands

- `./tests/run.sh`: run the full Plenary/Busted test suite headlessly in
  Neovim.
- `./tests/run.sh tests/scout/session_spec.lua`: run one spec file while
  iterating on a focused change.
- `nvim --headless -u tests/minimal_init.lua -i NONE -c "checkhealth scout" -c "qa"`:
  smoke-check plugin health loading in a minimal runtime.

There is no separate build step; plugin files are loaded directly by Neovim.
Tests require Neovim 0.10+ and `plenary.nvim` available in a standard lazy.nvim
data path, as configured by `tests/minimal_init.lua`.

## Coding Style & Naming Conventions

Use idiomatic Lua with two-space indentation, `local` by default, and modules
returning tables. Keep module names lowercase and aligned with their file paths
under `lua/scout/`. Prefer clear function names such as `start`, `refresh`,
`set_config`, or `root_for_path`. Avoid introducing global state except where it
matches existing plugin lifecycle patterns.

## Testing Guidelines

Add or update Plenary specs in `tests/scout/*_spec.lua` for behavior changes.
Name specs after the module or workflow under test, for example
`filter_spec.lua` or `persist_spec.lua`. Use `tests/run.sh` before submitting
changes, and run targeted spec files during development when failures are
localized.

## Commit & Pull Request Guidelines

Git history uses short, imperative commit subjects, often prefixed with
`feat`, `fix`, `docs:`, or `refactor`, for example `feat return to previous
position after review`. Keep commits focused on one change. Pull requests
should describe the user-visible behavior, list test commands run, link related
issues when applicable, and include screenshots or recordings for panel or UI
changes.

## Agent-Specific Instructions

Do not overwrite generated session or log artifacts such as `nvim.log` unless
the task explicitly requires cleanup. Preserve optional integration behavior:
`gitsigns.nvim`, `diffview.nvim`, and `telescope.nvim` should continue to
degrade gracefully when unavailable.
