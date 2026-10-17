local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function start(list)
  local hs, state = fakeHs.install()
  local bound, failures = require("modules.hotkeys").start(list)
  require("modules.frontmost").start()
  return bound, failures, state, hs
end

test.test("Hotkey は send で修飾キーつきの入力を送り、once なら長押しで繰り返さない", function()
  local _, _, state = start({
    { "ctrl+b", send = "fn+left" },
    { "Command+Shift+U", send = "cmd+r", once = true },
  })

  local back, reload = state.hotkeys[1], state.hotkeys[2]
  test.equal("ctrl", back.mods[1])
  test.equal("b", back.key)
  back.repeatFn()
  test.equal("fn", state.keyStrokes[1].mods[1])
  test.equal("left", state.keyStrokes[1].key)
  test.equal(0, state.keyStrokes[1].delay)

  test.equal("shift", reload.mods[1])
  test.equal("cmd", reload.mods[2])
  test.equal("u", reload.key)
  test.equal(nil, reload.repeatFn)
end)

test.test("Hotkey は run で組み込み Command と関数を実行する", function()
  local called = 0
  local _, _, state = start({
    { "ctrl+p", run = "timer" },
    { "ctrl+x", run = function() called = called + 1 end, label = "自作" },
    { "ctrl+o", run = "console" },
  })

  state.hotkeys[1].pressedFn()
  test.equal(true, state.choosers[1].visible)
  state.hotkeys[2].pressedFn()
  test.equal(1, called)
  state.hotkeys[3].pressedFn()
  test.equal(1, state.consoleOpened)
end)

test.test("Hotkey は run の関数が失敗したら名前とともに知らせる", function()
  local _, _, state = start({
    { "ctrl+x", run = function() error("boom") end, label = "自作の動作" },
  })

  state.hotkeys[1].pressedFn()

  test.equal(1, #state.alerts)
  test.contains(state.alerts[1], "自作の動作 でエラーが起きました")
  test.contains(state.alerts[1], "boom")
end)

test.test("Hotkey は only の間だけ有効になり、except の間は無効になる", function()
  local _, _, state = start({
    { "cmd+d", block = true, only = "Google Chrome" },
    { "ctrl+d", send = "forwarddelete", except = { "cmux", "Terminal" } },
  })
  local blocker, delete = state.hotkeys[1], state.hotkeys[2]

  test.equal(false, blocker.enabled)
  test.equal(true, delete.enabled, "最前面アプリが不明なら except は有効")

  state.activate(fakeHs.app("Google Chrome"))
  test.equal(true, blocker.enabled)
  test.equal(true, delete.enabled)

  state.activate(fakeHs.app("cmux"))
  test.equal(false, blocker.enabled)
  test.equal(false, delete.enabled)

  blocker.pressedFn()
  test.equal(0, #state.keyStrokes)
end)

test.test("Hotkey は範囲を分けた同じ組み合わせを最前面アプリに応じて切り替える", function()
  local _, _, state = start({
    { "ctrl+r", app = "Zed", except = "Google Chrome" },
    { "ctrl+r", send = "cmd+r", only = "Google Chrome" },
  })
  local zed, reload = state.hotkeys[1], state.hotkeys[2]

  state.activate(fakeHs.app("Google Chrome"))
  test.equal(false, zed.enabled)
  test.equal(true, reload.enabled)

  state.activate(fakeHs.app("Finder"))
  test.equal(true, zed.enabled)
  test.equal(false, reload.enabled)
end)

test.test("Hotkey は登録できなかった項目を報告し、残りを登録する", function()
  local hs, state = fakeHs.install()
  state.rejectedKeys.f5 = true
  local bound, failures = require("modules.hotkeys").start({
    { "f5", send = "cmd+r" },
    { "ctrl+m", app = "Typora" },
  })

  test.truthy(hs)
  test.equal(1, #bound)
  test.equal("Typora に切り替え", bound[1].label)
  test.equal(1, #failures)
  test.contains(failures[1], "hotkeys[1]: F5 を登録できませんでした")
  test.contains(failures[1], "key is reserved: f5")
end)

test.test("Hotkey は既定の名前と範囲の説明を持つ", function()
  local bound = start({
    { "ctrl+i", send = "up" },
    { "ctrl+m", app = "Typora" },
    { "cmd+d", block = true, only = "Google Chrome" },
    { "ctrl+d", send = "forwarddelete", except = { "cmux", "Terminal" } },
    { "ctrl+p", run = "timer" },
    { "ctrl+x", run = function() end },
    { "ctrl+y", app = "Zed", label = "エディタ" },
  })
  local hotkeys = require("modules.hotkeys")

  test.equal("↑ を送る", bound[1].label)
  test.equal("⌃I", hotkeys.describe(bound[1]))
  test.equal("Typora に切り替え", bound[2].label)
  test.equal("⌘D を無効化", bound[3].label)
  test.equal("⌘D · Google Chrome のみ", hotkeys.describe(bound[3]))
  test.equal("⌃D · cmux、Terminal 以外", hotkeys.describe(bound[4]))
  test.equal("タイマー", bound[5].label)
  test.equal("カスタム動作", bound[6].label)
  test.equal("エディタ", bound[7].label)
end)
