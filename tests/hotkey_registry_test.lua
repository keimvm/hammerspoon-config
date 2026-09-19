local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

test.test("Hotkey Registry は重複した modifier も同じ Hotkey Identity として扱う", function()
  local hs = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")
  local registry = require("modules.hotkey_registry").new()
  registry:bind({ id = "first", mods = { "ctrl", "control" }, key = "r" }, function() end)
  local ok, err = pcall(function()
    registry:bind({ id = "second", mods = { "ctrl" }, key = "r" }, function() end)
  end)
  test.equal(false, ok)
  test.contains(err, "duplicate hotkey ctrl+r")
end)

test.test("Hotkey Registry は hs.hotkey が無視する fn modifier を拒否する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")
  local registry = require("modules.hotkey_registry").new()
  local ok, err = pcall(function()
    registry:bind({ id = "fn-key", mods = { "fn" }, key = "r" }, function() end)
  end)
  test.equal(false, ok)
  test.contains(err, "not supported by hs.hotkey: fn")
  test.equal(0, #state.hotkeys)
end)

test.test("Hotkey Registry は登録失敗を報告し再試行を妨げない", function()
  for _, method in ipairs({ "bind", "create" }) do
    local hs = fakeHs.new()
    _G.hs = hs
    test.resetModule("modules.hotkey_registry")
    local registry = require("modules.hotkey_registry").new()
    local api = method == "bind" and "bind" or "new"
    local original = hs.hotkey[api]
    local definition = { id = "retry", mods = { "ctrl" }, key = "r" }
    for _, failure in ipairs({ function() return nil end, function() error("OS failure") end }) do
      hs.hotkey[api] = failure
      local ok, err = pcall(registry[method], registry, definition, function() end)
      test.equal(false, ok)
      test.contains(err, "retry")
      test.equal(nil, next(registry.hotkeys))
    end
    hs.hotkey[api] = original
    test.truthy(registry[method](registry, definition, function() end))
  end
end)

test.test("Hotkey Registry は description なしの Desired Hotkey を登録する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")

  local registry = require("modules.hotkey_registry").new()
  registry:bind({
    id = "reload.config",
    mods = {},
    key = "F5",
  }, function() end)

  test.equal(1, #state.hotkeys)
  test.equal("F5", state.hotkeys[1].key)
end)

test.test("Hotkey Registry は同じ Hotkey Identity の重複を拒否する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")

  local registry = require("modules.hotkey_registry").new()
  registry:bind({
    id = "first",
    description = "最初の Hotkey",
    mods = { "control", "shift" },
    key = "R",
  }, function() end)

  local ok, err = pcall(function()
    registry:bind({
      id = "second",
      description = "重複する Hotkey",
      mods = { "shift", "ctrl" },
      key = "r",
    }, function() end)
  end)

  test.equal(false, ok)
  test.contains(err, "duplicate hotkey ctrl+shift+r")
  test.equal(1, #state.hotkeys)
end)

test.test("Hotkey Registry は preflight と bind で同じ metadata rule を使う", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")

  local hotkeyRegistry = require("modules.hotkey_registry")
  local definition = {
    id = "missing-mods",
    description = "mods がない Hotkey",
    key = "r",
  }

  local errors = hotkeyRegistry.validationErrors({
    { path = "config.reload", value = definition },
  })
  test.contains(errors[1], "config.reload.mods must be a table")

  local registry = hotkeyRegistry.new()
  local ok, err = pcall(function()
    registry:bind(definition, function() end)
  end)

  test.equal(false, ok)
  test.contains(err, "mods must be a table")
  test.equal(0, #state.hotkeys)
end)

test.test("Hotkey Registry は無効状態で作る Hotkey も重複検出の対象にする", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")

  local registry = require("modules.hotkey_registry").new()
  registry:create({
    id = "app-hotkey-blocker.chrome-cmd-d",
    description = "Google Chrome で cmd+d を無効化",
    mods = { "cmd" },
    key = "d",
  }, function() end)

  local ok, err = pcall(function()
    registry:bind({
      id = "duplicate",
      description = "重複する Hotkey",
      mods = { "command" },
      key = "D",
    }, function() end)
  end)

  test.equal(false, ok)
  test.contains(err, "duplicate hotkey cmd+d")
  test.equal(1, #state.hotkeys)
  test.equal(false, state.hotkeys[1].enabled)
end)
