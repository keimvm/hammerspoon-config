local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function blockerConfig()
  return {
    appName = "Google Chrome",
    key = "d",
  }
end

test.test("App Hotkey Blocker は起動時に対象 app が frontmost なら Hotkey を有効にする", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  state.frontmostApplication = fakeHs.app("Google Chrome", {
    bundleID = "com.google.Chrome",
    frontmost = true,
  })

  test.resetModule("modules.app_hotkey_blocker")
  test.resetModule("modules.hotkey_registry")

  local registry = require("modules.hotkey_registry").new()
  require("modules.app_hotkey_blocker").start(blockerConfig(), registry)

  test.equal(1, #state.hotkeys)
  test.equal(true, state.hotkeys[1].enabled)
  test.equal(1, #state.applicationWatchers)
  test.equal(true, state.applicationWatchers[1].started)
end)

test.test("App Hotkey Blocker は対象 app の activate 中だけ Hotkey を有効にする", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  state.frontmostApplication = fakeHs.app("Safari", {
    bundleID = "com.apple.Safari",
    frontmost = true,
  })

  test.resetModule("modules.app_hotkey_blocker")
  test.resetModule("modules.hotkey_registry")

  local registry = require("modules.hotkey_registry").new()
  require("modules.app_hotkey_blocker").start(blockerConfig(), registry)

  local hotkey = state.hotkeys[1]
  local watcher = state.applicationWatchers[1]
  test.equal(false, hotkey.enabled)

  watcher.callback("Google Chrome", hs.application.watcher.activated, fakeHs.app("Google Chrome", {
    bundleID = "com.google.Chrome",
    frontmost = true,
  }))
  test.equal(true, hotkey.enabled)

  watcher.callback("Safari", hs.application.watcher.activated, fakeHs.app("Safari", {
    bundleID = "com.apple.Safari",
    frontmost = true,
  }))
  test.equal(false, hotkey.enabled)
end)

test.test("App Hotkey Blocker は compact な Desired Hotkey を既定の cmd+key で登録する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  state.frontmostApplication = fakeHs.app("Safari", {
    bundleID = "com.apple.Safari",
    frontmost = true,
  })

  test.resetModule("modules.app_hotkey_blocker")
  test.resetModule("modules.hotkey_registry")

  local config = blockerConfig()
  local registry = require("modules.hotkey_registry").new()
  require("modules.app_hotkey_blocker").start(config, registry)

  test.equal(1, #state.hotkeys)
  test.equal("d", state.hotkeys[1].key)
  test.equal(1, #state.hotkeys[1].mods)
  test.equal("cmd", state.hotkeys[1].mods[1])
  test.equal(false, state.hotkeys[1].enabled)
  test.equal(nil, config.id)
  test.equal(nil, config.mods)
end)

test.test("App Hotkey Blocker は明示した mods を既定より優先する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  test.resetModule("modules.app_hotkey_blocker")
  test.resetModule("modules.hotkey_registry")

  local registry = require("modules.hotkey_registry").new()
  require("modules.app_hotkey_blocker").start({
    appName = "Google Chrome",
    mods = { "ctrl" },
    key = "d",
  }, registry)

  test.equal(1, #state.hotkeys[1].mods)
  test.equal("ctrl", state.hotkeys[1].mods[1])
end)

test.test("App Hotkey Blocker は無効なら Hotkey と watcher を作らない", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  test.resetModule("modules.app_hotkey_blocker")
  test.resetModule("modules.hotkey_registry")

  local config = blockerConfig()
  config.enabled = false
  local registry = require("modules.hotkey_registry").new()
  require("modules.app_hotkey_blocker").start(config, registry)

  test.equal(0, #state.hotkeys)
  test.equal(0, #state.applicationWatchers)
end)
