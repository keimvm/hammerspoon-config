local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

test.test("App Switcher は未起動の app を launch する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs
  test.resetModule("modules.app_switcher")

  require("modules.app_switcher").toggleOrCycle("Codex")

  test.equal(1, #state.launchedApps)
  test.equal("Codex", state.launchedApps[1])
end)

test.test("App Switcher は frontmost app を hide する", function()
  local hs, state = fakeHs.new()
  local window = fakeHs.window(7)
  local app = fakeHs.app("Codex", {
    frontmost = true,
    windows = { window },
    focusedWindow = window,
  })
  state.applications.Codex = app
  _G.hs = hs
  test.resetModule("modules.app_switcher")

  require("modules.app_switcher").toggleOrCycle("Codex")

  test.equal(true, app.hidden)
end)

test.test("App Switcher は非 frontmost app の window を stable order で cycle する", function()
  local hs, state = fakeHs.new()
  local second = fakeHs.window(20)
  local first = fakeHs.window(10)
  local app = fakeHs.app("Codex", {
    windows = { second, first },
  })
  state.applications.Codex = app
  _G.hs = hs
  test.resetModule("modules.app_switcher")

  local appSwitcher = require("modules.app_switcher")
  appSwitcher.toggleOrCycle("Codex")

  test.equal(true, app.activated)
  test.equal(1, first.focusCount)
  test.equal(0, second.focusCount)

  app.frontmost = false
  appSwitcher.toggleOrCycle("Codex")

  test.equal(1, first.focusCount)
  test.equal(1, second.focusCount)
end)

test.test("App Switcher は window がない app を reopen する", function()
  local hs, state = fakeHs.new()
  local app = fakeHs.app("Codex", { windows = {} })
  state.applications.Codex = app
  _G.hs = hs
  test.resetModule("modules.app_switcher")

  require("modules.app_switcher").toggleOrCycle("Codex")

  test.equal(1, #state.appleScripts)
  test.contains(state.appleScripts[1], "to reopen")
  test.equal(1, #state.timers)

  local reopenedWindow = fakeHs.window(30)
  app.windows = { reopenedWindow }
  state.timers[1].callback()

  test.equal(1, reopenedWindow.focusCount)
end)

test.test("App Switcher は dirToOpen が利用できない場合に通常 launch へ fallback する", function()
  local hs, state = fakeHs.new()
  hs.fs.dir = function(dirPath)
    error("cannot open " .. dirPath)
  end
  _G.hs = hs
  test.resetModule("modules.app_switcher")

  require("modules.app_switcher").toggleOrCycle("MarkEdit", "/missing")

  test.equal(1, #state.alerts)
  test.contains(state.alerts[1], "/missing")
  test.equal("MarkEdit", state.launchedApps[1])
end)

test.test("App Switcher は dirToOpen が空の場合に通常 launch へ fallback する", function()
  local hs, state = fakeHs.new()
  local entries = { ".", ".." }
  local index = 0
  hs.fs.dir = function()
    return function()
      index = index + 1
      return entries[index]
    end
  end
  _G.hs = hs
  test.resetModule("modules.app_switcher")

  require("modules.app_switcher").toggleOrCycle("MarkEdit", "/empty")

  test.equal(0, #state.alerts)
  test.equal(1, #state.launchedApps)
  test.equal("MarkEdit", state.launchedApps[1])
end)
