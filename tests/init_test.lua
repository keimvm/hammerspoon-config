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
  _G.hs = hs

  resetModules()

  local init = assert(loadfile("init.lua"))
  local ok, err = pcall(init, {})

  test.equal(false, ok)
  test.contains(err, "invalid Hammerspoon config:")
  test.equal(0, #state.hotkeys)
  test.equal(0, #state.eventtaps)
  test.equal(0, #state.tasks)
end)

test.test("既定の App Switcher は ctrl+b/g/r で Safari、Google Chrome、ChatGPT を起動する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  resetModules()

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)

  local expectedApps = {
    b = "Safari",
    g = "Google Chrome",
    r = "ChatGPT",
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
