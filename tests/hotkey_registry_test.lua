local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

test.test("Hotkey Registry は同じ Hotkey Identity の重複を拒否する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")

  local registry = require("modules.hotkey_registry").new()
  registry:bind({
    id = "first",
    description = "最初の Hotkey",
    mods = { "control", "shift" },
    key = "R",
  }, function() end)

  local ok, err = pcall(function()
    registry:bind({
      id = "second",
      description = "重複する Hotkey",
      mods = { "shift", "ctrl" },
      key = "r",
    }, function() end)
  end)

  test.equal(false, ok)
  test.contains(err, "duplicate hotkey ctrl+shift+r")
  test.equal(1, #state.hotkeys)
end)

test.test("Hotkey Registry は preflight と bind で同じ metadata rule を使う", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")

  local hotkeyRegistry = require("modules.hotkey_registry")
  local definition = {
    id = "missing-mods",
    description = "mods がない Hotkey",
    key = "r",
  }

  local errors = hotkeyRegistry.validationErrors({
    { path = "config.reload", value = definition },
  })
  test.contains(errors[1], "config.reload.mods must be a table")

  local registry = hotkeyRegistry.new()
  local ok, err = pcall(function()
    registry:bind(definition, function() end)
  end)

  test.equal(false, ok)
  test.contains(err, "mods must be a table")
  test.equal(0, #state.hotkeys)
end)
