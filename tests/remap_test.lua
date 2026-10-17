local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function mappingsOf(state, index)
  return state.jsonValues[index or 1].UserKeyMapping
end

test.test("Input Remap は設定を hidutil の UserKeyMapping として名前順に適用する", function()
  local _, state = fakeHs.install()

  require("modules.remap").apply({
    caps_lock = "left_control",
    left_control = "left_command",
    left_command = "eisu",
    right_command = "kana",
  })

  test.equal(1, #state.tasks)
  test.equal("/usr/bin/hidutil", state.tasks[1].path)
  test.equal(true, state.tasks[1].started)
  test.equal("property", state.tasks[1].args[1])
  test.equal("--set", state.tasks[1].args[2])

  local mappings = mappingsOf(state)
  test.equal(4, #mappings)
  test.equal(0x700000039, mappings[1].HIDKeyboardModifierMappingSrc)
  test.equal(0x7000000E0, mappings[1].HIDKeyboardModifierMappingDst)
  test.equal(0x7000000E3, mappings[2].HIDKeyboardModifierMappingSrc)
  test.equal(0x700000091, mappings[2].HIDKeyboardModifierMappingDst)
  test.equal(0x7000000E0, mappings[3].HIDKeyboardModifierMappingSrc)
  test.equal(0x7000000E3, mappings[3].HIDKeyboardModifierMappingDst)
  test.equal(0x7000000E7, mappings[4].HIDKeyboardModifierMappingSrc)
  test.equal(0x700000090, mappings[4].HIDKeyboardModifierMappingDst)
end)

test.test("Input Remap は Escape や右 Option など修飾キー以外も変換できる", function()
  local _, state = fakeHs.install()

  require("modules.remap").apply({ caps_lock = "escape", right_option = "forwarddelete" })

  local mappings = mappingsOf(state)
  test.equal(0x700000029, mappings[1].HIDKeyboardModifierMappingDst)
  test.equal(0x7000000E6, mappings[2].HIDKeyboardModifierMappingSrc)
  test.equal(0x70000004C, mappings[2].HIDKeyboardModifierMappingDst)
end)

test.test("Input Remap は設定がなければ触らず、空なら変換を解除する", function()
  local _, state = fakeHs.install()
  local remap = require("modules.remap")

  remap.apply(nil)
  test.equal(0, #state.tasks)

  remap.apply({})
  test.equal(1, #state.tasks)
  test.equal(0, #mappingsOf(state))
end)

test.test("Input Remap の一時解除は空の変換を適用して知らせる", function()
  local _, state = fakeHs.install()

  require("modules.remap").clear()

  test.equal(0, #mappingsOf(state))
  test.contains(state.alerts[1], "キー変換を解除しました")
end)

test.test("Input Remap は hidutil の失敗を記録する", function()
  local _, state = fakeHs.install()

  require("modules.remap").apply({ caps_lock = "left_control" })
  state.tasks[1].callback(1, "", "permission denied")

  test.contains(state.logs[1].message, "hidutil failed: permission denied")
end)
