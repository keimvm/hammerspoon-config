local bindings = require("modules.bindings")
local commandKeys = require("modules.command_keys")
local controlLayer = require("modules.control_layer")
local hidRemap = require("modules.hid_remap")
local hotkeyRegistry = require("modules.hotkey_registry").new()

local home = os.getenv("HOME")

hidRemap.apply({
  enabled = true,
  mappings = {
    { from = "caps_lock", to = "left_control" },
    { from = "left_control", to = "left_command" },
  },
})

require("modules.reload").bind({
  id = "reload.config",
  description = "Hammerspoon 設定を再読み込み",
  mods = {},
  key = "F5",
}, hotkeyRegistry)

controlLayer.bind({
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
}, hotkeyRegistry)

commandKeys.bind({
  enabled = true,
  bindings = {
    -- JIS keyboard: 0x66 = 英数, 0x68 = かな。
    { commandKey = "cmd", outputKeyCode = 0x66 },
    { commandKey = "rightcmd", outputKeyCode = 0x68 },
  },
})

bindings.bind({
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
      id = "app-switcher.google-chrome",
      description = "Google Chrome を切り替える",
      appName = "Google Chrome",
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
      id = "app-switcher.codex",
      description = "Codex を切り替える",
      appName = "Codex",
      mods = { "ctrl" },
      key = "r",
    },
    --{ appName = "Zed", mods = { "ctrl" }, key = "r", enabled = false },
    {
      id = "app-switcher.chatgpt-atlas",
      description = "ChatGPT Atlas を切り替える",
      appName = "ChatGPT Atlas",
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
}, hotkeyRegistry)
