local bindings = require("modules.bindings")
local commandKeys = require("modules.command_keys")
local configValidation = require("modules.config_validation")
local controlLayer = require("modules.control_layer")
local hidRemap = require("modules.hid_remap")
local reload = require("modules.reload")
local hotkeyRegistry = require("modules.hotkey_registry").new()

local home = os.getenv("HOME")
local configOverride = ...

local config = configOverride or {
  hidRemap = {
    enabled = true,
    mappings = {
      { from = "caps_lock", to = "left_control" },
      { from = "left_control", to = "left_command" },
    },
  },
  reload = {
    id = "reload.config",
    description = "Hammerspoon 設定を再読み込み",
    mods = {},
    key = "F5",
  },
  controlLayer = {
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
  },
  commandKeys = {
    enabled = true,
    bindings = {
      -- JIS keyboard: 0x66 = 英数, 0x68 = かな。
      { commandKey = "cmd", outputKeyCode = 0x66 },
      { commandKey = "rightcmd", outputKeyCode = 0x68 },
    },
  },
  appSwitchers = {
    {
      id = "app-switcher.markedit",
      description = "MarkEdit を切り替える",
      appName = "MarkEdit",
      mods = { "ctrl" },
      key = "m",
      dirToOpen = home .. "/Desktop/memo",
    },
    {
      id = "app-switcher.finder",
      description = "Finder を切り替える",
      appName = "Finder",
      mods = { "ctrl" },
      key = "f",
    },
    {
      id = "app-switcher.mail",
      description = "メールを切り替える",
      appName = "メール",
      mods = { "ctrl" },
      key = "o",
    },
    {
      id = "app-switcher.safari",
      description = "Safari を切り替える",
      appName = "Safari",
      mods = { "ctrl" },
      key = "b",
    },
    {
      id = "app-switcher.cmux",
      description = "cmux を切り替える",
      appName = "cmux",
      mods = { "ctrl" },
      key = "t",
    },
    --{ appName = "Ghostty", mods = { "ctrl" }, key = "t", enabled = false },
    {
      id = "app-switcher.chatgpt",
      description = "ChatGPT を切り替える",
      appName = "ChatGPT",
      mods = { "ctrl" },
      key = "r",
    },
    --{ appName = "Zed", mods = { "ctrl" }, key = "r", enabled = false },
    {
      id = "app-switcher.google-chrome",
      description = "Google Chrome を切り替える",
      appName = "Google Chrome",
      mods = { "ctrl" },
      key = "g",
    },
    {
      id = "app-switcher.obsidian",
      description = "Obsidian を切り替える",
      appName = "Obsidian",
      mods = { "ctrl" },
      key = "n",
    },
    --{ appName = "iA Writer", mods = { "ctrl" }, key = "n", enabled = false },
    --{ appName = "YouTube", mods = { "ctrl" }, key = "y", enabled = false },
  },
  unicodeConverter = {
    id = "unicode-converter.toggle",
    description = "Unicode converter を切り替える",
    enabled = false,
    mods = { "cmd", "shift" },
    key = "u",
  },
}

configValidation.validate(config)

hidRemap.apply(config.hidRemap)
reload.bind(config.reload, hotkeyRegistry)
controlLayer.bind(config.controlLayer, hotkeyRegistry)
commandKeys.bind(config.commandKeys)
bindings.bind(config, hotkeyRegistry)
