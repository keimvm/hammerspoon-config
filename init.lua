local bindings = require("modules.bindings")

local home = os.getenv("HOME")

require("modules.reload").bind()

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
