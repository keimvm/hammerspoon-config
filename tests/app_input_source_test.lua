local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function startSources(config)
  test.resetModule("modules.app_input_source")
  require("modules.app_input_source").start(config)
end

local function sourceConfig()
  return {
    bindings = {
      { appName = "Zed", source = "eisu" },
      { appName = "cmux", source = "eisu" },
      { appName = "Typora", source = "kana" },
    },
  }
end

test.test("App Input Source は起動時に対象 app が frontmost なら入力ソースを切り替える", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  state.frontmostApplication = fakeHs.app("Zed", {
    bundleID = "dev.zed.Zed",
    frontmost = true,
  })

  startSources(sourceConfig())

  test.equal(1, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)
  test.equal(1, #state.applicationWatchers)
  test.equal(true, state.applicationWatchers[1].started)
end)

test.test("App Input Source は対象 app の activate で入力ソースを切り替える", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  state.frontmostApplication = fakeHs.app("Safari", {
    bundleID = "com.apple.Safari",
    frontmost = true,
  })

  startSources(sourceConfig())

  test.equal(0, #state.keyStrokes)

  local watcher = state.applicationWatchers[1]
  watcher.callback("Zed", hs.application.watcher.activated, fakeHs.app("Zed", {
    bundleID = "dev.zed.Zed",
    frontmost = true,
  }))
  test.equal(1, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)

  watcher.callback("Typora", hs.application.watcher.activated, fakeHs.app("Typora", {
    bundleID = "abnerworks.Typora",
    frontmost = true,
  }))
  test.equal(2, #state.keyStrokes)
  test.equal(0x68, state.keyStrokes[2].key)

  watcher.callback("Safari", hs.application.watcher.activated, fakeHs.app("Safari", {
    bundleID = "com.apple.Safari",
    frontmost = true,
  }))
  test.equal(2, #state.keyStrokes)
end)

test.test("App Input Source は無効なら watcher を作らない", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  state.frontmostApplication = fakeHs.app("Zed", {
    bundleID = "dev.zed.Zed",
    frontmost = true,
  })

  local config = sourceConfig()
  config.enabled = false
  startSources(config)

  test.equal(0, #state.keyStrokes)
  test.equal(0, #state.applicationWatchers)
end)

test.test("App Input Source は無効な binding を無視する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  state.frontmostApplication = fakeHs.app("Zed", {
    bundleID = "dev.zed.Zed",
    frontmost = true,
  })

  startSources({
    bindings = {
      { appName = "Zed", source = "eisu", enabled = false },
    },
  })

  test.equal(0, #state.keyStrokes)
  test.equal(0, #state.applicationWatchers)
end)
