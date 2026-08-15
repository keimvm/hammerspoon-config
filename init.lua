local bindings = require("modules.bindings")
local appHotkeyBlocker = require("modules.app_hotkey_blocker")
local commandKeys = require("modules.command_keys")
local configValidation = require("modules.config_validation")
local controlLayer = require("modules.control_layer")
local hidRemap = require("modules.hid_remap")
local reload = require("modules.reload")
local hotkeyRegistry = require("modules.hotkey_registry").new()

hs.window.animationDuration = 0

local configOverride = ...

local config = configOverride or {
  -- 物理キーの remap。
  hidRemap = {
    mappings = {
      { from = "caps_lock", to = "left_control" },
      { from = "left_control", to = "left_command" },
    },
  },
  -- F5: frontmost app に対して cmd+r。
  reload = { mods = {}, key = "F5" },
  -- ctrl+i/j/k/l → 矢印
  controlLayer = {
    arrows = {
      { mods = { "ctrl" }, key = "i", arrow = "up" },
      { mods = { "ctrl" }, key = "j", arrow = "left" },
      { mods = { "ctrl" }, key = "k", arrow = "down" },
      { mods = { "ctrl" }, key = "l", arrow = "right" },
    },
  },
  -- Command 単体押しで入力ソースを切り替える。（JIS keyboard: 0x66 = 英数, 0x68 = かな）
  commandKeys = {
    bindings = {
      { commandKey = "cmd", outputKeyCode = 0x66 },
      { commandKey = "rightcmd", outputKeyCode = 0x68 },
    },
  },
  -- Google Chrome が frontmost の間だけ cmd+d を無効化。
  appHotkeyBlocker = { appName = "Google Chrome", mods = { "cmd" }, key = "d" },
  -- 未起動なら起動、frontmost なら hide、それ以外は focus / cycle。
  appSwitchers = {
    { appName = "Typora", mods = { "ctrl" }, key = "m" },
    { appName = "Finder", mods = { "ctrl" }, key = "f" },
    { appName = "メール", mods = { "ctrl" }, key = "o" },
    { appName = "cmux", mods = { "ctrl" }, key = "t" },
    { appName = "Zed", mods = { "ctrl" }, key = "r" },
    { appName = "Google Chrome", mods = { "ctrl" }, key = "g" },
    { appName = "Notion", mods = { "ctrl" }, key = "n" },
  },
  -- cmd+shift+u で文字と code point を相互変換。
  unicodeConverter = { enabled = false, mods = { "cmd", "shift" }, key = "u" },  -- 現時点で無効
}

configValidation.validate(config)

hidRemap.apply(config.hidRemap)
reload.bind(config.reload, hotkeyRegistry)
controlLayer.bind(config.controlLayer, hotkeyRegistry)
commandKeys.bind(config.commandKeys)
appHotkeyBlocker.start(config.appHotkeyBlocker, hotkeyRegistry)
bindings.bind(config, hotkeyRegistry)
