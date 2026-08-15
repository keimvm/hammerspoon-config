local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function loadAppSwitcher(hs)
  _G.hs = hs
  test.resetModule("modules.app_switcher")
  return require("modules.app_switcher")
end

local function registerRunningApp(state, appName, options)
  local app = fakeHs.app(appName, options)
  state.applications[appName] = app
  return app
end

test.test("App Switcher は未起動の app を launch する", function()
  local hs, state = fakeHs.new()

  loadAppSwitcher(hs).toggleOrCycle("Codex")

  test.equal(1, #state.launchedApps)
  test.equal("Codex", state.launchedApps[1])
end)

test.test("App Switcher は frontmost app を hide する", function()
  local hs, state = fakeHs.new()
  local window = fakeHs.window(7)
  local app = registerRunningApp(state, "Codex", {
    frontmost = true,
    windows = { window },
    focusedWindow = window,
  })

  loadAppSwitcher(hs).toggleOrCycle("Codex")

  test.equal(true, app.hidden)
end)

test.test("App Switcher は非 frontmost app の window を stable order で cycle する", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(5, { spaces = { 2 } })
  local second = fakeHs.window(20, { spaces = { 1 } })
  local first = fakeHs.window(10, { spaces = { 1 } })
  local app = registerRunningApp(state, "Codex", {
    windows = { second, otherSpace, first },
  })
  state.activeSpaces = { main = 1 }

  local appSwitcher = loadAppSwitcher(hs)
  appSwitcher.toggleOrCycle("Codex")

  test.equal(true, app.activated)
  test.equal(1, first.focusCount)
  test.equal(0, second.focusCount)
  test.equal(0, otherSpace.focusCount)

  app.frontmost = false
  appSwitcher.toggleOrCycle("Codex")

  test.equal(1, first.focusCount)
  test.equal(1, second.focusCount)
  test.equal(0, otherSpace.focusCount)
end)

test.test("App Switcher は各 display で現在表示中の Space にある window を優先する", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(10, { spaces = { 2 } })
  local currentSpace = fakeHs.window(20, { spaces = { 3 } })
  registerRunningApp(state, "Finder", {
    windows = { otherSpace, currentSpace },
  })
  state.activeSpaces = { main = 1, secondary = 3 }

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(0, otherSpace.focusCount)
  test.equal(1, currentSpace.focusCount)
end)

test.test("App Switcher は app の activate 前に Hotkey を押した Space の候補を確定する", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(10, { spaces = { 2 } })
  local pressedSpace = fakeHs.window(20, { spaces = { 1 } })
  registerRunningApp(state, "Finder", {
    windows = { otherSpace, pressedSpace },
    onActivate = function()
      state.activeSpaces = { main = 2 }
    end,
  })
  state.activeSpaces = { main = 1 }

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(0, otherSpace.focusCount)
  test.equal(1, pressedSpace.focusCount)
end)

test.test("App Switcher は現在表示中の Space に window がなければ全 Space の cycle へ fallback する", function()
  local hs, state = fakeHs.new()
  local second = fakeHs.window(20, { spaces = { 2 } })
  local first = fakeHs.window(10, { spaces = { 2 } })
  registerRunningApp(state, "Finder", {
    windows = { second, first },
  })
  state.activeSpaces = { main = 1 }

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(1, first.focusCount)
  test.equal(0, second.focusCount)
end)

test.test("App Switcher は app 全体を hide した後も Hotkey を押した Space の window を表示する", function()
  local hs, state = fakeHs.new()
  local firstSpace = fakeHs.window(10, { spaces = { 1 } })
  local secondSpace = fakeHs.window(20, { spaces = { 2 } })
  local app = registerRunningApp(state, "Finder", {
    frontmost = true,
    windows = { firstSpace, secondSpace },
    focusedWindow = firstSpace,
  })
  state.activeSpaces = { main = 1 }

  local appSwitcher = loadAppSwitcher(hs)
  appSwitcher.toggleOrCycle("Finder")
  test.equal(true, app.hidden)

  state.activeSpaces = { main = 2 }
  appSwitcher.toggleOrCycle("Finder")

  test.equal(false, app.hidden)
  test.equal(0, firstSpace.focusCount)
  test.equal(1, secondSpace.focusCount)
end)

test.test("App Switcher は現在表示中の Space にある minimized window を優先して復帰する", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(10, { spaces = { 2 } })
  local currentSpace = fakeHs.window(20, { minimized = true, spaces = { 1 } })
  registerRunningApp(state, "Finder", {
    windows = { otherSpace, currentSpace },
  })
  state.activeSpaces = { main = 1 }

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(false, currentSpace.minimized)
  test.equal(1, currentSpace.focusCount)
  test.equal(0, otherSpace.focusCount)
end)

test.test("App Switcher は active Space の取得失敗時に全 Space の cycle へ fallback する", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(10, { spaces = { 2 } })
  local currentSpace = fakeHs.window(20, { spaces = { 1 } })
  registerRunningApp(state, "Finder", {
    windows = { otherSpace, currentSpace },
  })
  hs.spaces.activeSpaces = function()
    error("active space unavailable")
  end

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(1, otherSpace.focusCount)
  test.equal(0, currentSpace.focusCount)
  test.contains(state.logs[1].message, "active space lookup failed")
end)

test.test("App Switcher は window の Space 取得失敗時に部分的な候補を使わず fallback する", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(10, { spaces = { 2 } })
  local currentSpace = fakeHs.window(20, { spaces = { 1 } })
  registerRunningApp(state, "Finder", {
    windows = { otherSpace, currentSpace },
  })
  hs.spaces.windowSpaces = function(window)
    if window:id() == 20 then error("window space unavailable") end
    return window.spaces
  end
  state.activeSpaces = { main = 1 }

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(1, otherSpace.focusCount)
  test.equal(0, currentSpace.focusCount)
  test.contains(state.logs[1].message, "window space lookup failed for 20")
end)

test.test("App Switcher は window がない app を reopen する", function()
  local hs, state = fakeHs.new()
  local app = registerRunningApp(state, "Codex", { windows = {} })

  loadAppSwitcher(hs).toggleOrCycle("Codex")

  test.equal(1, #state.appleScripts)
  test.contains(state.appleScripts[1], "to reopen")
  test.equal(1, #state.timers)

  local reopenedWindow = fakeHs.window(30)
  app.windows = { reopenedWindow }
  state.timers[1].callback()

  test.equal(1, reopenedWindow.focusCount)
end)

test.test("App Switcher は compact な Desired Hotkey を既定の ctrl+key で登録する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")
  local registry = require("modules.hotkey_registry").new()
  local binding = {
    appName = "Safari",
    key = "b",
  }

  loadAppSwitcher(hs).bindToggle(binding, registry)

  test.equal(1, #state.hotkeys)
  test.equal("b", state.hotkeys[1].key)
  test.equal(1, #state.hotkeys[1].mods)
  test.equal("ctrl", state.hotkeys[1].mods[1])
  state.hotkeys[1].pressedFn()
  test.equal("Safari", state.launchedApps[1])
  test.equal(nil, binding.id)
  test.equal(nil, binding.description)
  test.equal(nil, binding.mods)
end)

test.test("App Switcher は明示した mods を既定より優先する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.hotkey_registry")
  local registry = require("modules.hotkey_registry").new()

  loadAppSwitcher(hs).bindToggle({
    appName = "Safari",
    mods = { "cmd" },
    key = "b",
  }, registry)

  test.equal(1, #state.hotkeys[1].mods)
  test.equal("cmd", state.hotkeys[1].mods[1])
end)

