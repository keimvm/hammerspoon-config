local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local ICON = { x = 100, y = 1000 }
local OUTSIDE = { x = 500, y = 300 }

-- Dock に1つのアイコンを置き、Dock Toggle を開始する。
local function start(options)
  options = options or {}
  local _, state = fakeHs.install()
  state.applications["com.apple.dock"] = fakeHs.app("Dock", { pid = options.dockPid or 10 })
  state.dockItems = {
    {
      x = 80, y = 980, w = 40, h = 40,
      subrole = options.subrole,
      url = options.url or "file:///Applications/Zed.app/",
    },
  }
  state.frontmostApplication = options.frontmost
  require("modules.dock_toggle").start(options.enabled ~= false)
  return state, state.eventtaps[1]
end

local function zed(windowOptions)
  local win = windowOptions ~= false and fakeHs.window(1, windowOptions) or nil
  return fakeHs.app("Zed", { frontmost = true, windows = { win }, focusedWindow = win })
end

local function click(tap, point, flags)
  local down = tap:send("leftMouseDown", point, flags)
  local up = tap:send("leftMouseUp", point, flags)
  return down, up
end

local function runTimers(state)
  for _, timer in ipairs(state.timers) do timer.callback() end
end

test.test("Dock Toggle は最前面アプリのアイコンのクリックを止めて、そのアプリを隠す", function()
  local app = zed()
  local state, tap = start({ frontmost = app })

  test.equal("leftMouseDown", tap.watchedTypes[1])
  test.equal("leftMouseUp", tap.watchedTypes[2])
  test.equal(2, #tap.watchedTypes)
  test.equal(true, tap.started)

  local down, up = click(tap, ICON)

  test.equal(true, down, "押下を Dock に渡さない")
  test.equal(true, up, "対応する離しも Dock に渡さない")
  test.equal(false, app.hidden, "隠すのは eventtap のコールバックを抜けてから")
  runTimers(state)
  test.equal(true, app.hidden)
end)

test.test("Dock Toggle は次のクリックの離しまでは止めない", function()
  local app = zed()
  local _, tap = start({ frontmost = app })

  click(tap, ICON)
  local down, up = click(tap, OUTSIDE)

  test.equal(false, down)
  test.equal(false, up)
end)

test.test("Dock Toggle は名前が表示名と違うアプリもバンドルのパスで見分ける", function()
  local win = fakeHs.window(1)
  local app = fakeHs.app("Code", {
    frontmost = true,
    path = "/Applications/Visual Studio Code.app",
    windows = { win },
    focusedWindow = win,
  })
  local state, tap = start({ frontmost = app, url = { url = "file:///Applications/Visual%20Studio%20Code.app/" } })

  test.equal(true, (click(tap, ICON)))
  runTimers(state)
  test.equal(true, app.hidden)
end)

test.test("Dock Toggle は最前面でないアプリのアイコンでは Dock 本来の動きに任せる", function()
  local win = fakeHs.window(1)
  local safari = fakeHs.app("Safari", { frontmost = true, windows = { win }, focusedWindow = win })
  local state, tap = start({ frontmost = safari })

  local down, up = click(tap, ICON)

  test.equal(false, down)
  test.equal(false, up)
  test.equal(0, #state.timers)
end)

test.test("Dock Toggle は修飾キーつきのクリックと Dock 以外のクリックを通す", function()
  local app = zed()
  local state, tap = start({ frontmost = app })

  for _, flag in ipairs({ "cmd", "alt", "ctrl", "shift" }) do
    test.equal(false, (click(tap, ICON, { [flag] = true })), flag)
  end
  test.equal(false, (click(tap, OUTSIDE)))
  test.equal(0, #state.timers)
end)

test.test("Dock Toggle はアプリ以外の Dock 項目では隠さない", function()
  local app = zed()
  local _, tap = start({ frontmost = app, subrole = "AXFolderDockItem" })

  test.equal(false, (click(tap, ICON)))
end)

test.test("Dock Toggle はウィンドウがない・最小化中・補助パネルだけのときは隠さない", function()
  local cases = {
    { name = "ウィンドウなし", app = zed(false) },
    { name = "最小化", app = zed({ minimized = true }) },
    { name = "補助パネル", app = zed({ subrole = "AXFloatingWindow" }) },
  }
  for _, case in ipairs(cases) do
    local _, tap = start({ frontmost = case.app })
    test.equal(false, (click(tap, ICON)), case.name)
  end
end)

test.test("Dock Toggle は Dock が再起動したら要素を取り直す", function()
  local app = zed()
  local state, tap = start({ frontmost = app })
  local function dockElements()
    local elements = {}
    for _, element in ipairs(state.axElements) do
      if element.kind == "dock" then table.insert(elements, element) end
    end
    return elements
  end

  click(tap, ICON)
  click(tap, ICON)
  test.equal(1, #dockElements(), "同じ Dock には要素を作り直さない")

  state.applications["com.apple.dock"] = fakeHs.app("Dock", { pid = 11 })
  test.equal(true, (click(tap, ICON)))
  test.equal(2, #dockElements())
  test.equal(11, dockElements()[2].pid)
end)

test.test("Dock Toggle は Dock・アイコン・最前面アプリ・ウィンドウの各問い合わせ前に上限を付ける", function()
  local app = zed()
  local state, tap = start({ frontmost = app })
  function app:focusedWindow() error("上限のない hs.application の問い合わせは使わない") end

  test.equal(true, (click(tap, ICON)))
  local queried = {}
  for _, element in ipairs(state.axElements) do
    for _, query in ipairs(element.queries) do
      test.equal(0.05, query.timeout, element.kind .. "." .. query.name)
      queried[element.kind] = true
    end
  end
  for _, kind in ipairs({ "dock", "item", "app", "window" }) do
    test.equal(true, queried[kind], kind)
  end
end)

test.test("Dock Toggle は上限の設定や AX の取得に失敗したら押下と離しを通し、次のクリックで再試行する", function()
  local failures = {
    "dock.setTimeout", "item.setTimeout", "app.setTimeout", "window.setTimeout",
    "dock.elementAtPosition", "item.AXRole", "item.AXSubrole", "item.AXURL",
    "app.AXFocusedWindow", "window.AXMinimized", "window.AXSubrole",
  }
  for _, failure in ipairs(failures) do
    local app = zed()
    local state, tap = start({ frontmost = app })
    state.axErrors = { [failure] = true }

    local down, up = click(tap, ICON)

    test.equal(false, down, failure .. " の押下")
    test.equal(false, up, failure .. " の離し")
    test.equal(0, #state.timers, failure .. " で隠す処理を予約しない")
    for _, element in ipairs(state.axElements) do
      if not element.timeout then
        test.equal(0, #element.queries, failure .. " で上限を設定できない要素には問い合わせない")
      end
    end

    state.axErrors = nil
    down, up = click(tap, ICON)
    test.equal(true, down, failure .. " から復旧後の押下")
    test.equal(true, up, failure .. " から復旧後の離し")
    runTimers(state)
    test.equal(true, app.hidden, failure .. " から復旧後は隠す")
  end
end)

test.test("Dock Toggle は設定がなければ eventtap を作らない", function()
  local state = start({ enabled = false })

  test.equal(0, #state.eventtaps)
end)

test.test("Dock Toggle の設定は true か false だけを受け付ける", function()
  fakeHs.install()
  local preflight = require("modules.preflight")

  test.equal(0, #preflight.check({ dockToggle = true }))
  test.equal(0, #preflight.check({ dockToggle = false }))
  local problems = preflight.check({ dockToggle = "yes" })
  test.equal(1, #problems)
  test.equal("dockToggle: true か false を指定してください", problems[1])
end)
