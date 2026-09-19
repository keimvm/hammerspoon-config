local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function resetModules()
  for name in pairs(package.loaded) do
    if name:match("^modules%.") then
      package.loaded[name] = nil
    end
  end
end

test.test("init.lua は Config Preflight 成功後に runtime side effect を開始する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  resetModules()

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)
  test.equal("keycode.lookup", state.operations[1])
end)

test.test("init.lua は Config Preflight 失敗時に runtime side effect を開始しない", function()
  local hs, state = fakeHs.new()
  hs.window.animationDuration = 0.2
  _G.hs = hs

  resetModules()

  local init = assert(loadfile("init.lua"))
  local ok, err = pcall(init, {})

  test.equal(false, ok)
  test.contains(err, "invalid Hammerspoon config:")
  test.equal(0.2, hs.window.animationDuration)
  test.equal(0, #state.hotkeys)
  test.equal(0, #state.applicationWatchers)
  test.equal(0, #state.eventtaps)
  test.equal(0, #state.tasks)
end)

test.test("既定の App Switcher は ctrl+g/r で Google Chrome、Zed を起動する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  resetModules()

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)

  local expectedApps = {
    g = "Google Chrome",
    r = "Zed",
  }

  for key, appName in pairs(expectedApps) do
    local matchingHotkey
    for _, hotkey in ipairs(state.hotkeys) do
      if hotkey.key == key and #hotkey.mods == 1 and hotkey.mods[1] == "ctrl" then
        matchingHotkey = hotkey
        break
      end
    end

    test.truthy(matchingHotkey, "ctrl+" .. key .. " が登録されていません")
    matchingHotkey.pressedFn()
    test.equal(appName, state.launchedApps[#state.launchedApps])
  end
end)

test.test("既定の Control Layer は ctrl+h/d で後方削除と前方削除を送信する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  resetModules()

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)

  local expectedKeys = {
    h = "delete",
    d = "forwarddelete",
  }

  for key, emitted in pairs(expectedKeys) do
    local matchingHotkey
    for _, hotkey in ipairs(state.hotkeys) do
      if hotkey.key == key and #hotkey.mods == 1 and hotkey.mods[1] == "ctrl" then
        matchingHotkey = hotkey
        break
      end
    end

    test.truthy(matchingHotkey, "ctrl+" .. key .. " が登録されていません")
    state.keyStrokes = {}
    matchingHotkey.pressedFn()
    matchingHotkey.repeatFn()
    test.equal(2, #state.keyStrokes)
    test.equal(emitted, state.keyStrokes[1].key)
    test.equal(emitted, state.keyStrokes[2].key)
  end
end)

test.test("既定の Control Layer は F5 で cmd+r を送信する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  resetModules()

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)

  local matchingHotkey
  for _, hotkey in ipairs(state.hotkeys) do
    if hotkey.key == "F5" and #hotkey.mods == 0 then
      matchingHotkey = hotkey
      break
    end
  end

  test.truthy(matchingHotkey, "F5 が登録されていません")
  test.equal(nil, matchingHotkey.repeatFn)
  matchingHotkey.pressedFn()
  test.equal(1, #state.keyStrokes)
  test.equal("cmd", state.keyStrokes[1].mods[1])
  test.equal("r", state.keyStrokes[1].key)
end)

test.test("既定の App Hotkey Blocker は Google Chrome の frontmost 中だけ cmd+d を無効化する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  state.frontmostApplication = fakeHs.app("Safari", {
    bundleID = "com.apple.Safari",
    frontmost = true,
  })

  resetModules()

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)

  local cmdD
  for _, hotkey in ipairs(state.hotkeys) do
    if hotkey.key == "d" and #hotkey.mods == 1 and hotkey.mods[1] == "cmd" then
      cmdD = hotkey
      break
    end
  end

  test.truthy(cmdD, "cmd+d が作成されていません")
  test.equal(false, cmdD.enabled)

  local watcher = state.applicationWatchers[1]
  test.truthy(watcher, "application watcher が作成されていません")
  watcher.callback("Google Chrome", hs.application.watcher.activated, fakeHs.app("Google Chrome", {
    bundleID = "com.google.Chrome",
    frontmost = true,
  }))
  test.equal(true, cmdD.enabled)
end)

test.test("既定の App Input Source は Zed が frontmost になると英数へ切り替える", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  state.frontmostApplication = fakeHs.app("Safari", {
    bundleID = "com.apple.Safari",
    frontmost = true,
  })

  resetModules()

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)
  test.equal(0, #state.keyStrokes)

  for _, watcher in ipairs(state.applicationWatchers) do
    watcher.callback("Zed", hs.application.watcher.activated, fakeHs.app("Zed", {
      bundleID = "dev.zed.Zed",
      frontmost = true,
    }))
  end

  test.equal(1, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)
end)

test.test("既定の Timer は ctrl+p で入力を開く", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  resetModules()

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)

  local matchingHotkey
  for _, hotkey in ipairs(state.hotkeys) do
    if hotkey.key == "p" and #hotkey.mods == 1 and hotkey.mods[1] == "ctrl" then
      matchingHotkey = hotkey
      break
    end
  end

  test.truthy(matchingHotkey, "ctrl+p が登録されていません")
  matchingHotkey.pressedFn()
  test.equal(true, state.choosers[1].visible)
  test.equal("分（1〜180）", state.choosers[1].placeholderTextValue)
end)
