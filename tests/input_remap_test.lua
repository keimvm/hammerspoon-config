local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

test.test("HID mapping は現在の modifier remap を hidutil に適用する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hid_remap")

  require("modules.hid_remap").apply({
    enabled = true,
    mappings = {
      { from = "caps_lock", to = "left_control" },
      { from = "left_control", to = "left_command" },
    },
  })

  test.equal(1, #state.tasks)
  test.equal("/usr/bin/hidutil", state.tasks[1].path)
  test.equal(true, state.tasks[1].started)

  local mappings = state.jsonValues[1].UserKeyMapping
  test.equal(0x700000039, mappings[1].HIDKeyboardModifierMappingSrc)
  test.equal(0x7000000E0, mappings[1].HIDKeyboardModifierMappingDst)
  test.equal(0x7000000E0, mappings[2].HIDKeyboardModifierMappingSrc)
  test.equal(0x7000000E3, mappings[2].HIDKeyboardModifierMappingDst)
end)

test.test("HID mapping は無効化時に残存する modifier remap を解除する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hid_remap")

  require("modules.hid_remap").apply({
    enabled = false,
    mappings = {
      { from = "caps_lock", to = "left_control" },
      { from = "left_control", to = "left_command" },
    },
  })

  test.equal(1, #state.tasks)
  test.equal(true, state.tasks[1].started)
  test.equal(0, #state.jsonValues[1].UserKeyMapping)
end)

test.test("HID mapping は hidutil task の生成失敗を記録する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hid_remap")
  hs.task.new = function() return nil end

  require("modules.hid_remap").apply({ enabled = true, mappings = {} })

  test.equal(1, #state.logs)
  test.equal("failed to create hidutil task", state.logs[1].message)
end)

test.test("HID mapping は hidutil task の開始失敗を記録する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hid_remap")
  local newTask = hs.task.new
  hs.task.new = function(...)
    local task = newTask(...)
    function task:start() return false end
    return task
  end

  require("modules.hid_remap").apply({ enabled = true, mappings = {} })

  test.equal(1, #state.logs)
  test.equal("failed to start hidutil task", state.logs[1].message)
end)

test.test("HID mapping は hidutil の非ゼロ終了を記録する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hid_remap")

  require("modules.hid_remap").apply({ enabled = true, mappings = {} })
  state.tasks[1].callback(1, "", "permission denied")

  test.equal(1, #state.logs)
  test.equal("hidutil failed: permission denied", state.logs[1].message)
end)

test.test("Command key は単体押しだけを入力切替に変換する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.command_keys")

  require("modules.command_keys").bind({
    enabled = true,
    bindings = {
      { commandKey = "cmd", outputKeyCode = 0x66 },
      { commandKey = "rightcmd", outputKeyCode = 0x68 },
    },
  })

  local tap = state.eventtaps[1]
  test.equal(true, tap.started)
  local types = hs.eventtap.event.types
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = true }))
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = false }))

  test.equal(1, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)

  state.keyStrokes = {}
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = true }))
  tap.callback(fakeHs.event(types.keyDown, 0, { cmd = true }))
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = false }))

  test.equal(0, #state.keyStrokes)

  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.rightcmd, { cmd = true }))
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.rightcmd, { cmd = false }))

  test.equal(1, #state.keyStrokes)
  test.equal(0x68, state.keyStrokes[1].key)
end)

test.test("Command key は左右同時押しを chord として扱い単体押しへ復旧する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.command_keys")

  require("modules.command_keys").bind({
    enabled = true,
    bindings = {
      { commandKey = "cmd", outputKeyCode = 0x66 },
      { commandKey = "rightcmd", outputKeyCode = 0x68 },
    },
  })

  local tap = state.eventtaps[1]
  local types = hs.eventtap.event.types
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = true }))
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.rightcmd, { cmd = true }))
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = true }))
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.rightcmd, { cmd = false }))

  test.equal(0, #state.keyStrokes)

  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = true }))

  test.equal(0, #state.keyStrokes)

  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = false }))

  test.equal(1, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)
end)

test.test("Command key は eventtap 開始時の unmatched release を無視する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.command_keys")

  require("modules.command_keys").bind({
    enabled = true,
    bindings = {
      { commandKey = "cmd", outputKeyCode = 0x66 },
    },
  })

  local tap = state.eventtaps[1]
  local types = hs.eventtap.event.types
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = false }))
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = true }))

  test.equal(0, #state.keyStrokes)

  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = false }))

  test.equal(1, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)
end)

test.test("Command key は bind 時の押下状態を全解除後に同期する", function()
  local hs, state = fakeHs.new()
  state.keyboardModifiers = { cmd = true }
  _G.hs = hs
  test.resetModule("modules.command_keys")

  require("modules.command_keys").bind({
    enabled = true,
    bindings = {
      { commandKey = "cmd", outputKeyCode = 0x66 },
      { commandKey = "rightcmd", outputKeyCode = 0x68 },
    },
  })

  local tap = state.eventtaps[1]
  local types = hs.eventtap.event.types
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = true }))
  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.rightcmd, { cmd = false }))

  test.equal(0, #state.keyStrokes)

  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = true }))

  test.equal(0, #state.keyStrokes)

  tap.callback(fakeHs.event(types.flagsChanged, hs.keycodes.map.cmd, { cmd = false }))

  test.equal(1, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)
end)

test.test("Command key は無効時に eventtap を開始しない", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.command_keys")

  require("modules.command_keys").bind({
    enabled = false,
    bindings = {
      { commandKey = "cmd", outputKeyCode = 0x66 },
    },
  })

  test.equal(0, #state.eventtaps)
end)

test.test("Control arrow は押下と長押し repeat で同じ arrow を送信する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")
  test.resetModule("modules.control_layer")

  local registry = require("modules.hotkey_registry").new()
  require("modules.control_layer").bind({
    arrows = {
      {
        id = "control-layer.up",
        description = "上矢印を送信",
        mods = { "ctrl" },
        key = "i",
        arrow = "up",
      },
      {
        id = "control-layer.left",
        description = "左矢印を送信",
        mods = { "ctrl" },
        key = "j",
        arrow = "left",
      },
      {
        id = "control-layer.down",
        description = "下矢印を送信",
        mods = { "ctrl" },
        key = "k",
        arrow = "down",
      },
      {
        id = "control-layer.right",
        description = "右矢印を送信",
        mods = { "ctrl" },
        key = "l",
        arrow = "right",
      },
    },
  }, registry)

  for _, hotkey in ipairs(state.hotkeys) do
    hotkey.pressedFn()
    hotkey.repeatFn()
  end

  test.equal(8, #state.keyStrokes)
  test.equal("up", state.keyStrokes[1].key)
  test.equal("up", state.keyStrokes[2].key)
  test.equal("left", state.keyStrokes[3].key)
  test.equal("left", state.keyStrokes[4].key)
  test.equal("down", state.keyStrokes[5].key)
  test.equal("down", state.keyStrokes[6].key)
  test.equal("right", state.keyStrokes[7].key)
  test.equal("right", state.keyStrokes[8].key)
  test.equal(0, #state.eventtaps)
end)
