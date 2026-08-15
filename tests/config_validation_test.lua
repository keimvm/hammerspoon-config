local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function validate(config)
  local hs = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.config_validation")
  return pcall(require("modules.config_validation").validate, config)
end

local function validConfig()
  return {
    hidRemap = {
      enabled = true,
      mappings = {
        { from = "caps_lock", to = "left_control" },
        { from = "left_control", to = "left_command" },
      },
    },
    commandKeys = {
      enabled = true,
      bindings = {
        { commandKey = "cmd", outputKeyCode = 0x66 },
        { commandKey = "rightcmd", outputKeyCode = 0x68 },
      },
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
      },
    },
    reload = {
      id = "reload.config",
      description = "Hammerspoon 設定を再読み込み",
      mods = {},
      key = "F5",
    },
    appSwitchers = {
      {
        id = "app-switcher.codex",
        description = "Codex を切り替える",
        appName = "Codex",
        mods = { "ctrl" },
        key = "r",
      },
    },
    appHotkeyBlocker = {
      id = "app-hotkey-blocker.chrome-cmd-d",
      description = "Google Chrome で cmd+d を無効化",
      appName = "Google Chrome",
      mods = { "cmd" },
      key = "d",
    },
    unicodeConverter = {
      id = "unicode-converter.toggle",
      description = "Unicode converter を切り替える",
      enabled = false,
      mods = { "cmd", "shift" },
      key = "u",
    },
  }
end

test.test("Config Preflight は複数の設定不備を field path 付きで集約する", function()
  local ok, err = validate({
    hidRemap = "invalid",
    commandKeys = false,
  })

  test.equal(false, ok)
  test.contains(err, "invalid Hammerspoon config:")
  test.contains(err, "config.hidRemap must be a table")
  test.contains(err, "config.commandKeys must be a table")
  test.contains(err, "config.controlLayer must be a table")
  test.contains(err, "config.reload must be a table")
  test.contains(err, "config.appSwitchers must be a table")
  test.contains(err, "config.appHotkeyBlocker must be a table")
  test.contains(err, "config.unicodeConverter must be a table")
end)

test.test("Config Preflight は feature の必須 field と型を検証する", function()
  local ok, err = validate({
    hidRemap = { enabled = "yes", mappings = false },
    commandKeys = { enabled = 1, bindings = "invalid" },
    controlLayer = { arrows = "invalid" },
    reload = { id = "", description = false, mods = "cmd" },
    appSwitchers = { false },
    appHotkeyBlocker = { appName = false },
    unicodeConverter = { enabled = "no" },
  })

  test.equal(false, ok)
  test.contains(err, "config.hidRemap.enabled must be a boolean")
  test.contains(err, "config.hidRemap.mappings must be a table")
  test.contains(err, "config.commandKeys.enabled must be a boolean")
  test.contains(err, "config.commandKeys.bindings must be a table")
  test.contains(err, "config.controlLayer.arrows must be a table")
  test.contains(err, "config.reload.description must be a non-empty string")
  test.contains(err, "config.reload.mods must be a table")
  test.contains(err, "config.reload.key must be a non-empty string")
  test.contains(err, "config.appSwitchers[1] must be a table")
  test.contains(err, "config.appHotkeyBlocker.id must be a non-empty string")
  test.contains(err, "config.appHotkeyBlocker.appName must be a non-empty string")
  test.contains(err, "config.unicodeConverter.enabled must be a boolean")
end)

test.test("Config Preflight は unknown key と modifier を検出する", function()
  local config = validConfig()
  config.reload.mods = { "hyper" }
  config.reload.key = "missing_key"
  config.commandKeys.bindings[1].commandKey = "left_magic"
  config.controlLayer.arrows[1].arrow = "north"

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(err, "config.reload.mods[1] is unknown: hyper")
  test.contains(err, "config.reload.key is unknown: missing_key")
  test.contains(err, "config.commandKeys.bindings[1].commandKey is unknown: left_magic")
  test.contains(err, "config.controlLayer.arrows[1].arrow is unknown: north")
end)

test.test("Config Preflight は Input Remap mapping の shape を検証する", function()
  local config = validConfig()
  config.hidRemap.mappings = {
    { from = "left_magic", to = "left_control" },
    { from = 1, to = "" },
    false,
  }
  config.controlLayer.sentinelCommand = {
    enabled = "yes",
    sentinelKey = "missing_key",
    virtualModifier = "hyper",
    syntheticEventSourceUserData = "invalid",
  }
  config.appSwitchers[1].appName = ""

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(err, "config.hidRemap.mappings[1].from is unknown: left_magic")
  test.contains(err, "config.hidRemap.mappings[2].from must be a non-empty string")
  test.contains(err, "config.hidRemap.mappings[2].to must be a non-empty string")
  test.contains(err, "config.hidRemap.mappings[3] must be a table")
  test.contains(err, "config.controlLayer.sentinelCommand.enabled must be a boolean")
  test.contains(err, "config.controlLayer.sentinelCommand.sentinelKey is unknown: missing_key")
  test.contains(err, "config.controlLayer.sentinelCommand.virtualModifier is unknown: hyper")
  test.contains(err, "config.controlLayer.sentinelCommand.syntheticEventSourceUserData must be a number")
  test.contains(err, "config.appSwitchers[1].appName must be a non-empty string")
end)

test.test("Config Preflight は Hotkey Identity と id の重複を検出する", function()
  local config = validConfig()
  table.insert(config.appSwitchers, {
    id = "app-switcher.codex",
    description = "disabled duplicate id",
    enabled = false,
    appName = "Browser",
    mods = { "ctrl" },
    key = "b",
  })
  table.insert(config.appSwitchers, {
    id = "app-switcher.other",
    description = "duplicate identity",
    appName = "Other",
    mods = { "control" },
    key = "R",
  })

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(
    err,
    "config.appSwitchers[2].id duplicates config.appSwitchers[1].id: app-switcher.codex"
  )
  test.contains(
    err,
    "config.appSwitchers[3] duplicates Hotkey Identity ctrl+r from config.appSwitchers[1]"
  )
end)

test.test("Config Preflight は config を変更せず環境依存の存在確認を行わない", function()
  local config = validConfig()
  config.appSwitchers[1].mods = { "control" }
  config.appSwitchers[1].key = "R"

  local ok, result = validate(config)

  test.equal(true, ok, result)
  test.equal(true, result)
  test.equal("control", config.appSwitchers[1].mods[1])
  test.equal("R", config.appSwitchers[1].key)
end)

test.test("Config Preflight は compact な App Switcher を受け付け入力を mutate しない", function()
  local config = validConfig()
  config.appSwitchers = {
    {
      appName = "Safari",
      key = "b",
    },
    {
      appName = "MarkEdit",
      key = "m",
    },
  }

  local ok, result = validate(config)

  test.equal(true, ok, result)
  test.equal(nil, config.appSwitchers[1].id)
  test.equal(nil, config.appSwitchers[1].description)
  test.equal(nil, config.appSwitchers[1].mods)
  test.equal("Safari", config.appSwitchers[1].appName)
  test.equal("b", config.appSwitchers[1].key)
  test.equal("MarkEdit", config.appSwitchers[2].appName)
  test.equal("m", config.appSwitchers[2].key)
end)

test.test("Config Preflight は compact な App Switcher の Hotkey Identity 重複を検出する", function()
  local config = validConfig()
  config.appSwitchers = {
    { appName = "Safari", key = "b" },
    { appName = "Google Chrome", key = "b" },
  }

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(
    err,
    "config.appSwitchers[2] duplicates Hotkey Identity ctrl+b from config.appSwitchers[1]"
  )
end)

test.test("Config Preflight は compact な Control arrow を受け付け入力を mutate しない", function()
  local config = validConfig()
  config.controlLayer.arrows = {
    { key = "i", arrow = "up" },
    { key = "j", arrow = "left" },
  }
  config.reload.description = nil
  config.appHotkeyBlocker.description = nil
  config.unicodeConverter.description = nil

  local ok, result = validate(config)

  test.equal(true, ok, result)
  test.equal(nil, config.controlLayer.arrows[1].id)
  test.equal(nil, config.controlLayer.arrows[1].description)
  test.equal(nil, config.controlLayer.arrows[1].mods)
  test.equal("i", config.controlLayer.arrows[1].key)
  test.equal("up", config.controlLayer.arrows[1].arrow)
  test.equal(nil, config.reload.description)
end)

test.test("Config Preflight は compact な App Hotkey Blocker を受け付け入力を mutate しない", function()
  local config = validConfig()
  config.appHotkeyBlocker = {
    appName = "Google Chrome",
    key = "d",
  }

  local ok, result = validate(config)

  test.equal(true, ok, result)
  test.equal(nil, config.appHotkeyBlocker.id)
  test.equal(nil, config.appHotkeyBlocker.description)
  test.equal(nil, config.appHotkeyBlocker.mods)
  test.equal("Google Chrome", config.appHotkeyBlocker.appName)
  test.equal("d", config.appHotkeyBlocker.key)
end)

test.test("Config Preflight は compact な Reload を受け付け入力を mutate しない", function()
  local config = validConfig()
  config.reload = { key = "F5" }

  local ok, result = validate(config)

  test.equal(true, ok, result)
  test.equal(nil, config.reload.id)
  test.equal(nil, config.reload.mods)
  test.equal("F5", config.reload.key)
end)

test.test("Config Preflight は compact な Unicode Converter を受け付け入力を mutate しない", function()
  local config = validConfig()
  config.unicodeConverter = { enabled = false }

  local ok, result = validate(config)

  test.equal(true, ok, result)
  test.equal(nil, config.unicodeConverter.id)
  test.equal(nil, config.unicodeConverter.mods)
  test.equal(nil, config.unicodeConverter.key)
  test.equal(false, config.unicodeConverter.enabled)
end)
