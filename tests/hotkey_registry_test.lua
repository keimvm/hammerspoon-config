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
