local bindings = require("modules.bindings")
local appHotkeyBlocker = require("modules.app_hotkey_blocker")
local commandKeys = require("modules.command_keys")
local configValidation = require("modules.config_validation")
local controlLayer = require("modules.control_layer")
local hidRemap = require("modules.hid_remap")
local reload = require("modules.reload")
local hotkeyRegistry = require("modules.hotkey_registry").new()

hs.window.animationDuration = 0

local home = os.getenv("HOME")
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
  reload = { key = "F5" },
  -- ctrl+i/j/k/l → 矢印
  controlLayer = {
    arrows = {
      { key = "i", arrow = "up" },
      { key = "j", arrow = "left" },
      { key = "k", arrow = "down" },
      { key = "l", arrow = "right" },
    },
  },
  -- Command 単体押しで入力ソースを切り替える。（JIS keyboard: 0x66 = 英数, 0x68 = かな）
  commandKeys = {
    bindings = {
      { commandKey = "cmd", outputKeyCode = 0x66 },
      { commandKey = "rightcmd", outputKeyCode = 0x68 },
    },
  },
  -- Google Chrome が frontmost の間だけ cmd+d を無効化。既定 mods は cmd。
  appHotkeyBlocker = { appName = "Google Chrome", key = "d" },
  -- 既定 mods は ctrl。未起動なら起動、frontmost なら hide、それ以外は focus / cycle。
  appSwitchers = {
    { appName = "Typora", key = "m", dirToOpen = home .. "/Desktop/memo" },  -- 未起動時は ~/Desktop/memo 直下の file を開く。
    { appName = "Finder", key = "f" },
    { appName = "メール", key = "o" },
    { appName = "cmux", key = "t" },
    { appName = "Zed", key = "r" },
    { appName = "Google Chrome", key = "g" },
    { appName = "Notion", key = "n" },
  },
  -- cmd+shift+u で文字と code point を相互変換。
  unicodeConverter = { enabled = false },  -- 現時点で無効
}

configValidation.validate(config)

hidRemap.apply(config.hidRemap)
reload.bind(config.reload, hotkeyRegistry)
controlLayer.bind(config.controlLayer, hotkeyRegistry)
commandKeys.bind(config.commandKeys)
appHotkeyBlocker.start(config.appHotkeyBlocker, hotkeyRegistry)
bindings.bind(config, hotkeyRegistry)
