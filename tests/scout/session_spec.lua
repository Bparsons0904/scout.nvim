local session = require("scout.session")
local git = require("scout.git")

describe("session._make_key", function()
  it("changes when HEAD changes", function()
    local first = session._make_key("/repo", "feature", "main", "base", "head-one")
    local second = session._make_key("/repo", "feature", "main", "base", "head-two")

    assert.not_equals(first, second)
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
