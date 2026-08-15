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
      bindings = {
        {
          id = "control-layer.up",
          description = "上矢印を送信",
          mods = { "ctrl" },
          key = "i",
          to = "up",
        },
      },
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
    appHotkeyBlockers = {
      {
        id = "app-hotkey-blocker.chrome-cmd-d",
        description = "Google Chrome で cmd+d を無効化",
        appName = "Google Chrome",
        mods = { "cmd" },
        key = "d",
      },
    },
    appInputSources = {
      bindings = {
        { appName = "Zed", source = "eisu" },
      },
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
  test.contains(err, "config.appSwitchers must be a table")
  test.contains(err, "config.appHotkeyBlockers must be a table")
  test.contains(err, "config.appInputSources must be a table")
  test.contains(err, "config.unicodeConverter must be a table")
end)

test.test("Config Preflight は feature の必須 field と型を検証する", function()
  local ok, err = validate({
    hidRemap = { enabled = "yes", mappings = false },
    commandKeys = { enabled = 1, bindings = "invalid" },
    controlLayer = { bindings = "invalid" },
    appSwitchers = { false },
    appHotkeyBlockers = { { appName = false } },
    appInputSources = { enabled = "yes", bindings = false },
    unicodeConverter = { description = false, mods = "cmd", enabled = "no" },
  })

  test.equal(false, ok)
  test.contains(err, "config.hidRemap.enabled must be a boolean")
  test.contains(err, "config.hidRemap.mappings must be a table")
  test.contains(err, "config.commandKeys.enabled must be a boolean")
  test.contains(err, "config.commandKeys.bindings must be a table")
  test.contains(err, "config.controlLayer.bindings must be a table")
  test.contains(err, "config.appSwitchers[1] must be a table")
  test.contains(err, "config.appHotkeyBlockers[1].id must be a non-empty string")
  test.contains(err, "config.appHotkeyBlockers[1].appName must be a non-empty string")
  test.contains(err, "config.appInputSources.enabled must be a boolean")
  test.contains(err, "config.appInputSources.bindings must be a table")
  test.contains(err, "config.unicodeConverter.description must be a non-empty string")
  test.contains(err, "config.unicodeConverter.mods must be a table")
  test.contains(err, "config.unicodeConverter.enabled must be a boolean")
end)

test.test("Config Preflight は unknown key と modifier を検出する", function()
  local config = validConfig()
  config.unicodeConverter.mods = { "hyper" }
  config.unicodeConverter.key = "missing_key"
  config.commandKeys.bindings[1].commandKey = "left_magic"
  config.controlLayer.bindings[1].to = "north"

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(err, "config.unicodeConverter.mods[1] is unknown: hyper")
  test.contains(err, "config.unicodeConverter.key is unknown: missing_key")
  test.contains(err, "config.commandKeys.bindings[1].commandKey is unknown: left_magic")
  test.contains(err, "config.controlLayer.bindings[1].to is unknown: north")
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

test.test("Config Preflight は compact な Control Layer を受け付け入力を mutate しない", function()
  local config = validConfig()
  config.controlLayer.bindings = {
    { key = "i", to = "up" },
    { key = "h", to = "delete" },
  }
  config.appHotkeyBlockers[1].description = nil
  config.unicodeConverter.description = nil

  local ok, result = validate(config)

  test.equal(true, ok, result)
  test.equal(nil, config.controlLayer.bindings[1].id)
  test.equal(nil, config.controlLayer.bindings[1].description)
  test.equal(nil, config.controlLayer.bindings[1].mods)
  test.equal("i", config.controlLayer.bindings[1].key)
  test.equal("up", config.controlLayer.bindings[1].to)
  test.equal("h", config.controlLayer.bindings[2].key)
  test.equal("delete", config.controlLayer.bindings[2].to)
end)

test.test("Config Preflight は Control Layer の chord 送り先を受け付け入力を mutate しない", function()
  local config = validConfig()
  config.controlLayer.bindings = {
    { mods = {}, key = "F5", to = { mods = { "cmd" }, key = "r" } },
  }

  local ok, result = validate(config)

  test.equal(true, ok, result)
  test.equal(nil, config.controlLayer.bindings[1].id)
  test.equal("F5", config.controlLayer.bindings[1].key)
  test.equal("cmd", config.controlLayer.bindings[1].to.mods[1])
  test.equal("r", config.controlLayer.bindings[1].to.key)
end)

test.test("Config Preflight は Control Layer の不正な chord 送り先を検出する", function()
  local config = validConfig()
  config.controlLayer.bindings = {
    { mods = {}, key = "F5", to = { mods = { "hyper" }, key = "missing_key" } },
    { mods = { "ctrl" }, key = "i", to = 12 },
  }

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(err, "config.controlLayer.bindings[1].to.mods[1] is unknown: hyper")
  test.contains(err, "config.controlLayer.bindings[1].to.key is unknown: missing_key")
  test.contains(err, "config.controlLayer.bindings[2].to must be a key name or chord table")
end)

test.test("Config Preflight は Control Layer の repeatable の型を検証する", function()
  local config = validConfig()
  config.controlLayer.bindings[1].repeatable = "no"

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(err, "config.controlLayer.bindings[1].repeatable must be a boolean")
end)

test.test("Config Preflight は compact な App Hotkey Blocker を受け付け入力を mutate しない", function()
  local config = validConfig()
  config.appHotkeyBlockers = {
    {
      appName = "Google Chrome",
      key = "d",
    },
  }

  local ok, result = validate(config)

  test.equal(true, ok, result)
  test.equal(nil, config.appHotkeyBlockers[1].id)
  test.equal(nil, config.appHotkeyBlockers[1].description)
  test.equal(nil, config.appHotkeyBlockers[1].mods)
  test.equal("Google Chrome", config.appHotkeyBlockers[1].appName)
  test.equal("d", config.appHotkeyBlockers[1].key)
end)

test.test("Config Preflight は単一の App Hotkey Blocker を list として拒否する", function()
  local config = validConfig()
  config.appHotkeyBlockers = {
    appName = "Google Chrome",
    key = "d",
  }

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(err, "config.appHotkeyBlockers must be a list")
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

test.test("Config Preflight は App Input Source の unknown source と重複 app を検出する", function()
  local config = validConfig()
  config.appInputSources.bindings = {
    { appName = "Zed", source = "english" },
    { appName = "Zed", source = "eisu" },
    { appName = "", source = false },
  }

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(err, "config.appInputSources.bindings[1].source is unknown: english")
  test.contains(
    err,
    "config.appInputSources.bindings[2].appName duplicates config.appInputSources.bindings[1].appName: Zed"
  )
  test.contains(err, "config.appInputSources.bindings[3].appName must be a non-empty string")
  test.contains(err, "config.appInputSources.bindings[3].source must be a non-empty string")
end)

test.test("Config Preflight は単一の App Input Source binding を list として拒否する", function()
  local config = validConfig()
  config.appInputSources.bindings = {
    appName = "Zed",
    source = "eisu",
  }

  local ok, err = validate(config)

  test.equal(false, ok)
  test.contains(err, "config.appInputSources.bindings must be a list")
end)
