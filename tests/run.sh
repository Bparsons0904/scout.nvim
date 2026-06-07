#!/usr/bin/env bash

set -euo pipefail

test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT

export XDG_CACHE_HOME="$test_home/cache"
export XDG_STATE_HOME="$test_home/state"
export NVIM_LOG_FILE="$test_home/nvim.log"

if [[ $# -gt 0 ]]; then
  nvim --headless -u tests/minimal_init.lua -i NONE \
    -c "lua require('plenary.busted').run([[$1]])"
else
  nvim --headless -u tests/minimal_init.lua -i NONE \
    -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
fi
