local bindings = require("modules.bindings")
local appHotkeyBlocker = require("modules.app_hotkey_blocker")
local appInputSource = require("modules.app_input_source")
local commandKeys = require("modules.command_keys")
local configValidation = require("modules.config_validation")
local controlLayer = require("modules.control_layer")
local hidRemap = require("modules.hid_remap")
local hotkeyRegistry = require("modules.hotkey_registry").new()

local configOverride = ...

local config = configOverride or {
  -- 物理キーの remap。
  hidRemap = {
    mappings = {
      { from = "caps_lock", to = "left_control" },
      { from = "left_control", to = "left_command" },
    },
  },
  -- ctrl+i/j/k/l → 矢印、ctrl+h → 後方削除、ctrl+d → 前方削除、F5 → cmd+r
  controlLayer = {
    bindings = {
      { mods = { "ctrl" }, key = "i", to = "up" },
      { mods = { "ctrl" }, key = "j", to = "left" },
      { mods = { "ctrl" }, key = "k", to = "down" },
      { mods = { "ctrl" }, key = "l", to = "right" },
      { mods = { "ctrl" }, key = "h", to = "delete" },
      { mods = { "ctrl" }, key = "d", to = "forwarddelete" },
      { mods = {}, key = "F5", to = { mods = { "cmd" }, key = "r" }, repeatable = false },
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
  appHotkeyBlockers = {
    { appName = "Google Chrome", mods = { "cmd" }, key = "d" },
  },
  -- 未起動なら起動、frontmost なら hide、それ以外は focus / cycle。
  appSwitchers = {
    { appName = "Typora", mods = { "ctrl" }, key = "m" },
    { appName = "Finder", mods = { "ctrl" }, key = "f" },
    { appName = "Microsoft Outlook", mods = { "ctrl" }, key = "o" },
    { appName = "cmux", mods = { "ctrl" }, key = "t" },
    { appName = "Zed", mods = { "ctrl" }, key = "r" },
    { appName = "Google Chrome", mods = { "ctrl" }, key = "g" },
    -- { appName = "Notion", mods = { "ctrl" }, key = "n" },
  },
  -- 対象 app が frontmost になったら入力ソースを切り替える。
  appInputSources = {
    bindings = {
      { appName = "Zed", source = "eisu" },
      { appName = "cmux", source = "eisu" },
      { appName = "Visual Studio Code", source = "eisu" },
    },
  },
  -- cmd+shift+u で文字と code point を相互変換。
  unicodeConverter = { enabled = false, mods = { "cmd", "shift" }, key = "u" },  -- 現時点で無効
  -- one-shot countdown。メニューバーに残り時間を表示。
  timer = { enabled = true, mods = { "ctrl" }, key = "p" },
}

configValidation.validate(config)

hs.window.animationDuration = 0

hidRemap.apply(config.hidRemap)
controlLayer.bind(config.controlLayer, hotkeyRegistry)
commandKeys.bind(config.commandKeys)
appHotkeyBlocker.start(config.appHotkeyBlockers, hotkeyRegistry)
appInputSource.start(config.appInputSources)
bindings.bind(config, hotkeyRegistry)
