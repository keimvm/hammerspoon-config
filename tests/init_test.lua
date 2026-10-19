local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

-- init.lua を読み込む。config を渡さなければ同梱の config.lua を使う。
local function boot(config, prepare)
  local hs, state = fakeHs.install()
  if prepare then prepare(hs, state) end
  local ok, err = pcall(assert(loadfile("init.lua")), config)
  test.equal(true, ok, err)
  return hs, state
end

local function hotkeyFor(state, key, mods)
  for _, hotkey in ipairs(state.hotkeys) do
    if hotkey.key == key and table.concat(hotkey.mods, "+") == table.concat(mods or {}, "+") then
      return hotkey
    end
  end
end

test.test("init.lua は同梱の設定を検証して各機能を開始する", function()
  local hs, state = boot()

  test.equal(0, hs.window.animationDuration)
  test.equal(1, #state.tasks)
  test.equal("/usr/bin/hidutil", state.tasks[1].path)
  test.equal(4, #state.jsonValues[1].UserKeyMapping)
  test.equal(16, #state.hotkeys)
  test.equal(1, #state.applicationWatchers)
  test.equal(true, state.applicationWatchers[1].started)
  test.equal(1, #state.pathwatchers)
  test.equal(true, state.pathwatchers[1].started)
  test.equal(0, #state.alerts)
  -- 常駐する eventtap は Dock Toggle の左クリックだけ。keyDown は監視しない。
  test.equal(1, #state.eventtaps)
  test.equal(true, state.eventtaps[1].started)
  test.equal("leftMouseDown", state.eventtaps[1].watchedTypes[1])
  test.equal("leftMouseUp", state.eventtaps[1].watchedTypes[2])
  test.equal(2, #state.eventtaps[1].watchedTypes)
end)

test.test("init.lua の既定の Hotkey は矢印・アプリ切り替え・タイマーを動かす", function()
  local _, state = boot()

  local up = hotkeyFor(state, "i", { "ctrl" })
  up.pressedFn()
  test.equal("up", state.keyStrokes[1].key)
  test.equal(up.pressedFn, up.repeatFn)

  local f5 = hotkeyFor(state, "f5")
  test.equal(nil, f5.repeatFn)
  f5.pressedFn()
  test.equal("r", state.keyStrokes[2].key)
  test.equal("cmd", state.keyStrokes[2].mods[1])

  hotkeyFor(state, "g", { "ctrl" }).pressedFn()
  hotkeyFor(state, "r", { "ctrl" }).pressedFn()
  test.equal("Google Chrome", state.launchedApps[1])
  test.equal("Zed", state.launchedApps[2])

  hotkeyFor(state, "p", { "ctrl" }).pressedFn()
  test.equal(true, state.choosers[1].visible)
end)

test.test("init.lua は Google Chrome が最前面の間だけ cmd+d を無効にする", function()
  local _, state = boot()
  local blocker = hotkeyFor(state, "d", { "cmd" })

  test.equal(false, blocker.enabled)
  state.activate(fakeHs.app("Google Chrome"))
  test.equal(true, blocker.enabled)
  state.activate(fakeHs.app("Safari"))
  test.equal(false, blocker.enabled)
end)

test.test("init.lua は対象アプリが最前面になると英数へ切り替える", function()
  local _, state = boot(nil, function(_, state)
    state.frontmostApplication = fakeHs.app("Zed")
  end)

  test.equal(1, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)

  state.activate(fakeHs.app("Typora"))
  test.equal(1, #state.keyStrokes)
  state.activate(fakeHs.app("Visual Studio Code"))
  test.equal(2, #state.keyStrokes)
end)

test.test("init.lua は設定に問題があれば何も適用せず、監視だけ始めて問題を表示する", function()
  local hs, state = boot({
    remap = { caps_lock = "left_control" },
    hotkeys = { { "ctrl+i", send = "up" }, { "ctrl+q" } },
  })

  test.equal(0.2, hs.window.animationDuration)
  test.equal(0, #state.hotkeys)
  test.equal(0, #state.tasks)
  test.equal(0, #state.applicationWatchers)
  test.equal(1, #state.pathwatchers)
  test.equal(1, #state.alerts)
  test.contains(state.alerts[1], "設定に問題があるため、何も適用していません")
  test.contains(state.alerts[1], "hotkeys[2]: 動作を1つ指定してください")
  test.equal("indefinite", state.alertDetails[1].arguments[1])
  test.equal("error", state.logs[1].level)
end)

test.test("init.lua は登録できない Hotkey があっても残りを登録して報告する", function()
  local _, state = boot(nil, function(_, state)
    state.rejectedKeys.f5 = true
  end)

  test.equal(15, #state.hotkeys)
  test.equal(1, #state.alerts)
  test.contains(state.alerts[1], "登録できなかった Hotkey があります")
  test.contains(state.alerts[1], "hotkeys[7]: F5 を登録できませんでした")
end)

test.test("init.lua は自分で再読み込みした後だけ完了を短く知らせる", function()
  local _, state = boot(nil, function(_, state)
    state.settings["hammerspoon-config.reloaded"] = true
  end)

  test.equal(1, #state.alerts)
  test.equal("設定を再読み込みしました（Hotkey 16 件）", state.alerts[1])
  test.equal(nil, state.settings["hammerspoon-config.reloaded"])
end)

test.test("init.lua は remap がなければ hidutil を呼ばない", function()
  local _, state = boot({ hotkeys = { { "ctrl+i", send = "up" } } })

  test.equal(0, #state.tasks)
  test.equal(1, #state.hotkeys)
  test.equal(0, #state.applicationWatchers, "最前面アプリを使う機能がなければ監視しない")
end)
