local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function resetUnicodeModules()
  test.resetModule("modules.app_switcher")
  test.resetModule("modules.bindings")
  test.resetModule("modules.hotkey_registry")
  test.resetModule("modules.unicode_converter")
end

test.test("Unicode Converter は enabled 設定で Hotkey 登録を切り替える", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  resetUnicodeModules()

  local registry = require("modules.hotkey_registry").new()
  require("modules.bindings").bind({
    unicodeConverter = {
      enabled = false,
    },
  }, registry)

  test.equal(0, #state.hotkeys)

  hs, state = fakeHs.new()
  _G.hs = hs
  resetUnicodeModules()
  registry = require("modules.hotkey_registry").new()
  local converter = {
    enabled = true,
  }
  require("modules.bindings").bind({
    unicodeConverter = converter,
  }, registry)

  test.equal(1, #state.hotkeys)
  test.equal("u", state.hotkeys[1].key)
  test.equal(2, #state.hotkeys[1].mods)
  test.equal("cmd", state.hotkeys[1].mods[1])
  test.equal("shift", state.hotkeys[1].mods[2])
  test.equal(nil, converter.id)
  test.equal(nil, converter.mods)
  test.equal(nil, converter.key)
  state.hotkeys[1].pressedFn()
  test.equal(true, state.choosers[1].visible)
end)

test.test("Unicode Converter は明示した mods と key を既定より優先する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  resetUnicodeModules()

  local registry = require("modules.hotkey_registry").new()
  require("modules.bindings").bind({
    unicodeConverter = {
      enabled = true,
      mods = { "ctrl" },
      key = "b",
    },
  }, registry)

  test.equal("b", state.hotkeys[1].key)
  test.equal(1, #state.hotkeys[1].mods)
  test.equal("ctrl", state.hotkeys[1].mods[1])
end)

test.test("Unicode Converter は code point を文字へ変換する", function()
  local hs, state = fakeHs.new()
  state.pasteboardText = "U+3042"
  _G.hs = hs
  resetUnicodeModules()

  require("modules.unicode_converter").show()

  local chooser = state.choosers[1]
  test.equal("あ", chooser.currentChoices[1].text)
  chooser.callback(chooser.currentChoices[1])
  test.equal("あ", state.pasteboardText)
end)

test.test("Unicode Converter は文字を code point へ変換する", function()
  local hs, state = fakeHs.new()
  state.pasteboardText = "あ"
  _G.hs = hs
  resetUnicodeModules()

  require("modules.unicode_converter").show()

  test.equal("U+3042", state.choosers[1].currentChoices[1].text)
end)
