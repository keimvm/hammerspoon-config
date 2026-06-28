local bindings = require("modules.bindings")
local commandKeys = require("modules.command_keys")
local controlLayer = require("modules.control_layer")
local hidRemap = require("modules.hid_remap")

local home = os.getenv("HOME")

hidRemap.apply({
  enabled = true,
  mappings = {
    { from = "caps_lock", to = "left_control" },
    { from = "left_control", to = "left_command" },
  },
})

require("modules.reload").bind()

controlLayer.bind({
  arrows = {
    { mods = { "ctrl" }, key = "i", arrow = "up" },
    { mods = { "ctrl" }, key = "j", arrow = "left" },
    { mods = { "ctrl" }, key = "k", arrow = "down" },
    { mods = { "ctrl" }, key = "l", arrow = "right" },
  },
})

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
    { appName = "MarkEdit", mods = { "ctrl" }, key = "m", dirToOpen = home .. "/Desktop/memo" },
    { appName = "Finder", mods = { "ctrl" }, key = "f" },
    { appName = "メール", mods = { "ctrl" }, key = "o" },
    { appName = "Google Chrome", mods = { "ctrl" }, key = "b" },
    { appName = "cmux", mods = { "ctrl" }, key = "t" },
    --{ appName = "Ghostty", mods = { "ctrl" }, key = "t", enabled = false },
    { appName = "Codex", mods = { "ctrl" }, key = "r" },
    --{ appName = "Zed", mods = { "ctrl" }, key = "r", enabled = false },
    { appName = "ChatGPT Atlas", mods = { "ctrl" }, key = "g" },
    { appName = "Obsidian", mods = { "ctrl" }, key = "n" },
    --{ appName = "iA Writer", mods = { "ctrl" }, key = "n", enabled = false },
    --{ appName = "YouTube", mods = { "ctrl" }, key = "y", enabled = false },
  },
  unicodeConverter = {
    enabled = false,
    mods = { "cmd", "shift" },
    key = "u",
  },
})
