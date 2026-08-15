local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

test.test("Reload Hotkey は frontmost app に cmd+r を送信する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")
  test.resetModule("modules.reload")

  local registry = require("modules.hotkey_registry").new()
  require("modules.reload").bind({
    key = "F5",
  }, registry)

  state.hotkeys[1].pressedFn()

  test.equal(1, #state.hotkeys)
  test.equal("F5", state.hotkeys[1].key)
  test.equal(0, #state.hotkeys[1].mods)
  test.equal(1, #state.keyStrokes)
  test.equal("cmd", state.keyStrokes[1].mods[1])
  test.equal("r", state.keyStrokes[1].key)
end)

test.test("Reload Hotkey は明示した mods を既定より優先する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")
  test.resetModule("modules.reload")

  local registry = require("modules.hotkey_registry").new()
  require("modules.reload").bind({
    mods = { "cmd" },
    key = "F5",
  }, registry)

  test.equal(1, #state.hotkeys[1].mods)
  test.equal("cmd", state.hotkeys[1].mods[1])
end)
