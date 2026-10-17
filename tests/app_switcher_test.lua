local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function loadAppSwitcher(hs)
  _G.hs = hs
  test.resetModules()
  return require("modules.app_switcher")
end

local function registerRunningApp(state, appName, options)
  local app = fakeHs.app(appName, options)
  state.applications[appName] = app
  return app
end

test.test("App Switcher は候補が1つでも所属 Space があれば移動する", function()
  local hs, state = fakeHs.new()
  local window = fakeHs.window(10, { spaces = { 2 } })
  registerRunningApp(state, "Finder", { windows = { window } })
  loadAppSwitcher(hs).toggleOrCycle("Finder")
  test.equal(1, window.focusCount)
  test.equal(0, #state.logs)
end)

test.test("App Switcher は window 一覧の順番を変更しない", function()
  local hs, state = fakeHs.new()
  local second = fakeHs.window(20, { standard = false })
  local first = fakeHs.window(10, { standard = false })
  local app = registerRunningApp(state, "Finder", { windows = { second, first } })
  function app:mainWindow() return nil end
  loadAppSwitcher(hs).toggleOrCycle("Finder")
  test.equal(1, first.focusCount)
  test.equal(second, app.windows[1])
end)

test.test("App Switcher は sort の比較ごとに window ID を取得し直さない", function()
  local hs, state = fakeHs.new()
  local windows = {}
  local idReads = 0
  for id = 64, 1, -1 do
    local window = fakeHs.window(id)
    function window:id()
      idReads = idReads + 1
      return id
    end
    table.insert(windows, window)
  end
  registerRunningApp(state, "Finder", { windows = windows })
  loadAppSwitcher(hs).toggleOrCycle("Finder")
  test.equal(1, windows[64].focusCount)
  test.truthy(idReads <= 65, "window ID の取得回数: " .. idReads)
end)

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

test.test("App Switcher は別 Space の直前の window を activate せず対象を再表示する", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(10, { spaces = { 2 } })
  local pressedSpace = fakeHs.window(20, { spaces = { 1 } })
  local app = registerRunningApp(state, "Finder", {
    windows = { otherSpace, pressedSpace },
    focusedWindow = otherSpace,
    onActivate = function()
      state.activeSpaces = { main = 2 }
      error("直前の window を activate すると別 Space へ移動する")
    end,
  })
  app.hidden = true
  function app:unhide()
    test.equal(pressedSpace, self:mainWindow(), "再表示前に対象の window を main にする")
    self.hidden = false
  end
  state.activeSpaces = { main = 1 }

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(0, otherSpace.focusCount)
  test.equal(1, pressedSpace.focusCount)
  test.equal(1, state.activeSpaces.main)
  test.equal(false, app.hidden)
end)

test.test("App Switcher は Finder の非 standard window も全候補から Space で選ぶ", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(10, { standard = false, spaces = { 2 } })
  local currentSpace = fakeHs.window(20, { standard = false, spaces = { 1 } })
  local desktop = fakeHs.window(0, { standard = false, role = "AXScrollArea", spaces = {} })
  registerRunningApp(state, "Finder", {
    windows = { otherSpace, currentSpace, desktop },
    focusedWindow = otherSpace,
  })

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(1, currentSpace.focusCount)
  test.equal(0, otherSpace.focusCount)
  test.equal(0, desktop.focusCount)
  test.equal(0, #state.logs)
end)

test.test("App Switcher は別 Space の standard window より現在の非 standard window を優先する", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(10, { spaces = { 2 } })
  local currentSpace = fakeHs.window(20, { standard = false, spaces = { 1 } })
  registerRunningApp(state, "Finder", { windows = { otherSpace, currentSpace } })

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(1, currentSpace.focusCount)
  test.equal(0, otherSpace.focusCount)
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

test.test("App Switcher は active Space の取得失敗時に別 Space へ移動しない", function()
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

  test.equal(0, otherSpace.focusCount)
  test.equal(0, currentSpace.focusCount)
  test.equal(0, #state.appleScripts)
  test.equal(1, #state.alerts)
  test.contains(state.logs[1].message, "active space lookup failed")
end)

test.test("App Switcher は所在不明の window があれば別 Space へ移動しない", function()
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

  test.equal(0, otherSpace.focusCount)
  test.equal(0, currentSpace.focusCount)
  test.equal(0, #state.appleScripts)
  test.contains(state.logs[1].message, "window space lookup failed for 20")
end)

test.test("App Switcher は一部の Space 取得が失敗しても現在と確認できた window を使う", function()
  local hs, state = fakeHs.new()
  local unknownSpace = fakeHs.window(10, { spaces = {} })
  local currentSpace = fakeHs.window(20, { spaces = { 1 } })
  registerRunningApp(state, "Finder", { windows = { unknownSpace, currentSpace } })

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(0, unknownSpace.focusCount)
  test.equal(1, currentSpace.focusCount)
  test.equal(0, #state.alerts)
end)

test.test("App Switcher は表示中の Space または全候補の所属が空なら移動しない", function()
  for _, emptyActiveSpaces in ipairs({ true, false }) do
    local hs, state = fakeHs.new()
    local first = fakeHs.window(10, { spaces = emptyActiveSpaces and { 2 } or {} })
    local second = fakeHs.window(20, { spaces = {} })
    registerRunningApp(state, "Finder", { windows = { first, second } })
    if emptyActiveSpaces then state.activeSpaces = {} end

    loadAppSwitcher(hs).toggleOrCycle("Finder")

    test.equal(0, first.focusCount)
    test.equal(0, second.focusCount)
    test.equal(0, #state.appleScripts)
    test.equal(1, #state.alerts)
  end
end)

test.test("App Switcher は所属のない補助要素が混ざっても別 Space の実ウィンドウへ移動する", function()
  local hs, state = fakeHs.new()
  local otherSpace = fakeHs.window(517, { spaces = { 2 } })
  local noId = fakeHs.window(0, { standard = false, spaces = {} })
  local helper = fakeHs.window(518, { standard = false, spaces = {} })
  local unknownRole = fakeHs.window(5, { standard = false, subrole = "AXUnknown", spaces = { 1 } })
  registerRunningApp(state, "cmux", { windows = { noId, unknownRole, otherSpace, helper } })
  local windowSpaces = hs.spaces.windowSpaces
  hs.spaces.windowSpaces = function(win)
    test.truthy(win:id() > 0, "無効な window ID で Space を照会しない")
    return windowSpaces(win)
  end

  loadAppSwitcher(hs).toggleOrCycle("cmux")

  test.equal(1, otherSpace.focusCount)
  test.equal(0, noId.focusCount)
  test.equal(0, helper.focusCount)
  test.equal(0, unknownRole.focusCount)
  test.equal(0, #state.alerts)
  test.equal(0, #state.logs)
end)

test.test("App Switcher は候補が1つでも所属のない要素へフォーカスしない", function()
  local hs, state = fakeHs.new()
  local helper = fakeHs.window(10, { standard = false, spaces = {} })
  registerRunningApp(state, "cmux", { windows = { helper } })

  loadAppSwitcher(hs).toggleOrCycle("cmux")

  test.equal(0, helper.focusCount)
  test.equal(0, #state.appleScripts)
  test.equal(1, #state.alerts)
end)

test.test("App Switcher は Finder のデスクトップが最前面でも別 Space のウィンドウへ移動する", function()
  for _, focusOnDesktop in ipairs({ true, false }) do
    local hs, state = fakeHs.new()
    local otherSpace = fakeHs.window(20, { standard = false, spaces = { 2 } })
    local desktop = fakeHs.window(0, { standard = false, role = "AXScrollArea", spaces = {} })
    local app = registerRunningApp(state, "Finder", {
      frontmost = true,
      windows = { otherSpace, desktop },
      focusedWindow = focusOnDesktop and desktop or otherSpace,
    })

    loadAppSwitcher(hs).toggleOrCycle("Finder")

    test.equal(false, app.hidden)
    test.equal(1, otherSpace.focusCount)
    test.equal(0, desktop.focusCount)
  end
end)

test.test("App Switcher は最前面でも対象ウィンドウが最小化されていれば復帰する", function()
  local hs, state = fakeHs.new()
  local window = fakeHs.window(10, { minimized = true })
  local app = registerRunningApp(state, "Finder", {
    frontmost = true, windows = { window }, focusedWindow = window,
  })

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(false, app.hidden)
  test.equal(false, window.minimized)
  test.equal(1, window.focusCount)
end)

test.test("App Switcher は一覧が空でも mainWindow があれば新規表示せず既存へ移動する", function()
  local hs, state = fakeHs.new()
  local window = fakeHs.window(20, { spaces = { 2 } })
  local app = registerRunningApp(state, "Zed", { windows = {} })
  app.main = window

  loadAppSwitcher(hs).toggleOrCycle("Zed")

  test.equal(1, window.focusCount)
  test.equal(0, #state.appleScripts)
end)

test.test("App Switcher は Finder が最前面でもデスクトップしかなければ reopen する", function()
  local hs, state = fakeHs.new()
  local desktop = fakeHs.window(0, { standard = false, role = "AXScrollArea" })
  local app = registerRunningApp(state, "Finder", {
    frontmost = true,
    windows = { desktop },
    focusedWindow = desktop,
  })

  loadAppSwitcher(hs).toggleOrCycle("Finder")

  test.equal(false, app.hidden)
  test.equal(0, desktop.focusCount)
  test.equal(1, #state.appleScripts)
  test.contains(state.appleScripts[1], "to reopen")
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
