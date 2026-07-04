local session = require("scout.session")
local git = require("scout.git")
local panel = require("scout.panel")

describe("session._make_key", function()
  it("ignores commit identity so state survives new commits", function()
    local key = session._make_key("/repo", "feature", "main")
    assert.equals("/repo|feature|main", key)
  end)

  it("changes when branch or base reference changes", function()
    local base = session._make_key("/repo", "feature", "main")
    assert.not_equals(base, session._make_key("/repo", "other", "main"))
    assert.not_equals(base, session._make_key("/repo", "feature", "develop"))
  end)
end)

describe("session.start failures", function()
  local originals
  local notifications

  before_each(function()
    originals = {
      default_branch = git.default_branch,
      merge_base = git.merge_base,
      changed_files = git.changed_files,
      root = git.root,
      root_for_path = git.root_for_path,
      notify = vim.notify,
    }
    notifications = {}
    vim.notify = function(message, level)
      table.insert(notifications, { message = message, level = level })
    end
    git.default_branch = function() return "main" end
    git.merge_base = function() return "base-sha" end
    git.root_for_path = function() return "/repo" end
  end)

  after_each(function()
    git.default_branch = originals.default_branch
    git.merge_base = originals.merge_base
    git.changed_files = originals.changed_files
    git.root = originals.root
    git.root_for_path = originals.root_for_path
    vim.notify = originals.notify
  end)

  it("reports a changed-files Git failure instead of no changes", function()
    git.changed_files = function() return nil, "bad revision" end

    session.start()

    assert.equals("scout: could not list changed files: bad revision", notifications[1].message)
    assert.equals(vim.log.levels.ERROR, notifications[1].level)
    assert.is_false(session.is_active())
  end)

  it("rejects an unavailable repository root", function()
    git.changed_files = function() return { { status = "M", path = "README.md" } } end
    git.root_for_path = function() return nil, "not a repository" end

    session.start()

    assert.equals("scout: could not determine repository root", notifications[1].message)
    assert.equals(vim.log.levels.ERROR, notifications[1].level)
    assert.is_false(session.is_active())
  end)
end)

describe("session.refresh", function()
  local originals
  local changed_file_bases
  local panel_updates

  before_each(function()
    originals = {
      default_branch = git.default_branch,
      merge_base = git.merge_base,
      changed_files = git.changed_files,
      root_for_path = git.root_for_path,
      head = git.head,
      current_branch = git.current_branch,
      blob_hashes = git.blob_hashes,
      panel_open = panel.open,
      panel_is_open = panel.is_open,
      panel_set_files = panel.set_files,
      panel_close = panel.close,
      notify = vim.notify,
    }
    changed_file_bases = {}
    panel_updates = {}

    session.set_config({ integrations = { gitsigns = false } })
    git.default_branch = function() return "develop" end
    git.root_for_path = function() return "/repo" end
    git.head = function() return "head-sha" end
    git.current_branch = function() return "feature" end
    git.blob_hashes = function() return {} end
    panel.open = function() end
    panel.is_open = function() return true end
    panel.set_files = function(files)
      table.insert(panel_updates, files)
    end
    panel.close = function() end
    vim.notify = function() end
  end)

  after_each(function()
    if session.is_active() then
      session.stop()
    end
    git.default_branch = originals.default_branch
    git.merge_base = originals.merge_base
    git.changed_files = originals.changed_files
    git.root_for_path = originals.root_for_path
    git.head = originals.head
    git.current_branch = originals.current_branch
    git.blob_hashes = originals.blob_hashes
    panel.open = originals.panel_open
    panel.is_open = originals.panel_is_open
    panel.set_files = originals.panel_set_files
    panel.close = originals.panel_close
    vim.notify = originals.notify
  end)

  it("recomputes merge-base so upstream merges drop out of the review", function()
    local merge_bases = { "old-base", "new-base" }
    git.merge_base = function()
      return table.remove(merge_bases, 1)
    end
    git.changed_files = function(base_commit)
      table.insert(changed_file_bases, base_commit)
      if base_commit == "old-base" then
        return {
          { status = "M", path = "ours.lua" },
          { status = "M", path = "upstream.lua" },
        }
      end
      return { { status = "M", path = "ours.lua" } }
    end

    session.start()
    session.refresh()

    assert.same({ "old-base", "new-base" }, changed_file_bases)
    assert.same({ { status = "M", path = "ours.lua" } }, panel_updates[1])
  end)
end)

describe("session._reconcile_reviewed", function()
  local changed = {
    { status = "M", path = "kept.lua" },
    { status = "M", path = "changed.lua" },
    { status = "D", path = "gone.lua" },
  }

  local function hash_for(map)
    return function(path)
      return map[path]
    end
  end

  it("keeps files whose hash still matches", function()
    local result = session._reconcile_reviewed(
      { ["kept.lua"] = "h1" },
      changed,
      hash_for({ ["kept.lua"] = "h1" })
    )
    assert.same({ ["kept.lua"] = "h1" }, result)
  end)

  it("drops files whose hash changed", function()
    local result = session._reconcile_reviewed(
      { ["changed.lua"] = "old" },
      changed,
      hash_for({ ["changed.lua"] = "new" })
    )
    assert.same({}, result)
  end)

  it("prunes paths no longer in the diff", function()
    local result = session._reconcile_reviewed(
      { ["kept.lua"] = "h1", ["vanished.lua"] = "h9" },
      changed,
      hash_for({ ["kept.lua"] = "h1" })
    )
    assert.same({ ["kept.lua"] = "h1" }, result)
  end)

  it("migrates a legacy array, backfilling current hashes", function()
    local result = session._reconcile_reviewed(
      { "kept.lua" },
      changed,
      hash_for({ ["kept.lua"] = "current" })
    )
    assert.same({ ["kept.lua"] = "current" }, result)
  end)

  it("keeps a still-deleted file via the deleted sentinel", function()
    local result = session._reconcile_reviewed(
      { ["gone.lua"] = "__deleted__" },
      changed,
      hash_for({})
    )
    assert.same({ ["gone.lua"] = "__deleted__" }, result)
  end)
end)
