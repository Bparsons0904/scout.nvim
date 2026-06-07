local session = require("scout.session")

describe("session._make_key", function()
  it("changes when HEAD changes", function()
    local first = session._make_key("/repo", "feature", "main", "base", "head-one")
    local second = session._make_key("/repo", "feature", "main", "base", "head-two")

    assert.not_equals(first, second)
  end)
end)
