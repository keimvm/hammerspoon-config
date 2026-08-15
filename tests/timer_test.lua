local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function resetTimerModules()
  test.resetModule("modules.app_switcher")
  test.resetModule("modules.bindings")
  test.resetModule("modules.hotkey_registry")
  test.resetModule("modules.timer")
  test.resetModule("modules.unicode_converter")
end

local function setup()
  local hs, state = fakeHs.new()
  state.now = 1000
  _G.hs = hs
  resetTimerModules()
  return hs, state
end

local function repeatingTimer(state)
  for _, timer in ipairs(state.timers) do
    if timer.interval then return timer end
  end
end

local function delayedTimer(state)
  for _, timer in ipairs(state.timers) do
    if timer.delay then return timer end
  end
end

local function activeMenubar(state)
  local item
  for _, menubar in ipairs(state.menubars) do
    if not menubar.deleted then item = menubar end
  end
  return item
end

local function cancelMenu(menubar)
  local menu = menubar.menu
  if type(menu) == "function" then menu = menu() end
  menu[1].fn()
end

local function typeQuery(chooser, query)
  chooser.queryValue = query
  chooser.queryChangedFn(query)
end

local function startFromQuery(state, query)
  local timer = require("modules.timer")
  timer.toggle()
  local chooser = state.choosers[#state.choosers]
  typeQuery(chooser, query)
  chooser.callback(chooser.currentChoices[1])
  return chooser
end

test.test("Timer は enabled 設定で Hotkey 登録を切り替える", function()
  local hs, state = setup()
  local registry = require("modules.hotkey_registry").new()
  require("modules.bindings").bind({
    timer = { enabled = false },
  }, registry)

  test.equal(0, #state.hotkeys)

  hs, state = setup()
  registry = require("modules.hotkey_registry").new()
  local binding = { enabled = true }
  require("modules.bindings").bind({
    timer = binding,
  }, registry)

  test.equal(1, #state.hotkeys)
  test.equal("`", state.hotkeys[1].key)
  test.equal(1, #state.hotkeys[1].mods)
  test.equal("ctrl", state.hotkeys[1].mods[1])
  test.equal(nil, binding.id)
  test.equal(nil, binding.mods)
  test.equal(nil, binding.key)
  state.hotkeys[1].pressedFn()
  test.equal(true, state.choosers[1].visible)
end)

test.test("Timer は明示した mods と key を既定より優先する", function()
  local _, state = setup()
  local registry = require("modules.hotkey_registry").new()
  require("modules.bindings").bind({
    timer = {
      enabled = true,
      mods = { "cmd" },
      key = "b",
    },
  }, registry)

  test.equal("b", state.hotkeys[1].key)
  test.equal(1, #state.hotkeys[1].mods)
  test.equal("cmd", state.hotkeys[1].mods[1])
end)

test.test("Timer は開くと分の入力範囲を示して開始行を出さない", function()
  local _, state = setup()
  require("modules.timer").toggle()

  local chooser = state.choosers[1]
  test.equal(true, chooser.visible)
  test.equal("分（1〜180）", chooser.placeholderTextValue)
  test.equal(0, #chooser.currentChoices)
end)

test.test("Timer は有効な分数で開始行を出す", function()
  local _, state = setup()
  require("modules.timer").toggle()
  local chooser = state.choosers[1]
  typeQuery(chooser, "25")

  test.equal(1, #chooser.currentChoices)
  test.equal("25分で開始", chooser.currentChoices[1].text)
end)

test.test("Timer は s で秒に切り替え欄から取り除く", function()
  local _, state = setup()
  require("modules.timer").toggle()
  local chooser = state.choosers[1]
  typeQuery(chooser, "90s")

  test.equal("90", chooser.queryValue)
  test.equal("秒（1〜10800）", chooser.placeholderTextValue)
  test.equal("90秒で開始", chooser.currentChoices[1].text)
end)

test.test("Timer は m で分に戻す", function()
  local _, state = setup()
  require("modules.timer").toggle()
  local chooser = state.choosers[1]
  typeQuery(chooser, "90s")
  typeQuery(chooser, "90m")

  test.equal("90", chooser.queryValue)
  test.equal("分（1〜180）", chooser.placeholderTextValue)
  test.equal("90分で開始", chooser.currentChoices[1].text)
end)

test.test("Timer は単位記号以外を別の時間値へ変換しない", function()
  local _, state = setup()
  local timer = require("modules.timer")
  timer.toggle()
  local chooser = state.choosers[1]

  typeQuery(chooser, "1.5")
  test.equal("1.5", chooser.queryValue)
  test.equal(1, #chooser.currentChoices)
  test.equal("数字と s / m だけ入力してください", chooser.currentChoices[1].text)
  chooser.callback(chooser.currentChoices[1])
  test.equal(0, #state.menubars)
end)

test.test("Timer は空では候補を出さず範囲外では許容範囲を示す", function()
  local _, state = setup()
  local timer = require("modules.timer")
  timer.toggle()
  local chooser = state.choosers[1]

  typeQuery(chooser, "")
  test.equal(0, #chooser.currentChoices)

  typeQuery(chooser, "0")
  test.equal(1, #chooser.currentChoices)
  test.equal("1〜180分で入力してください", chooser.currentChoices[1].text)
  chooser.callback(chooser.currentChoices[1])
  test.equal(0, #state.menubars)

  timer.toggle()
  chooser = state.choosers[1]
  typeQuery(chooser, "181")
  test.equal(1, #chooser.currentChoices)
  test.equal("1〜180分で入力してください", chooser.currentChoices[1].text)
  chooser.callback(chooser.currentChoices[1])
  test.equal(0, #state.menubars)

  timer.toggle()
  chooser = state.choosers[1]
  typeQuery(chooser, "s")
  typeQuery(chooser, "10801")
  test.equal(1, #chooser.currentChoices)
  test.equal("1〜10800秒で入力してください", chooser.currentChoices[1].text)
  chooser.callback(chooser.currentChoices[1])
  test.equal(0, #state.menubars)
end)

test.test("Timer は Enter でメニューバーに残り時間を出す", function()
  local _, state = setup()
  startFromQuery(state, "25")

  local menubar = activeMenubar(state)
  test.truthy(menubar, "メニューバーがありません")
  test.equal("25:00", menubar.title)
end)

test.test("Timer は1秒ごとに残り時間を減らす", function()
  local _, state = setup()
  startFromQuery(state, "25")
  state.now = state.now + 1
  repeatingTimer(state).callback()

  test.equal("24:59", activeMenubar(state).title)
end)

test.test("Timer は1秒の countdown を 0:01 のまま完了する", function()
  local _, state = setup()
  local timer = require("modules.timer")
  timer.toggle()
  local chooser = state.choosers[1]
  typeQuery(chooser, "1s")
  chooser.callback(chooser.currentChoices[1])

  local menubar = activeMenubar(state)
  test.equal("0:01", menubar.title)

  state.now = state.now + 1
  repeatingTimer(state).callback()

  test.equal(true, menubar.deleted)
  test.equal(nil, activeMenubar(state))
  test.equal("0:01", menubar.title)
  test.equal(1, #state.notifications)
  test.equal("タイマー", state.notifications[1].title)
  test.equal("1秒が経過しました", state.notifications[1].informativeText)
  test.equal(true, state.notifications[1].alwaysPresent)
  test.equal(0, state.notifications[1].withdrawAfter)
  test.equal(nil, state.notifications[1].soundName)
  delayedTimer(state).callback()
  test.equal(0, #state.alerts)
end)

test.test("Timer は分で開始した完了通知に当初の長さを入れる", function()
  local _, state = setup()
  startFromQuery(state, "25")
  state.now = state.now + 25 * 60
  repeatingTimer(state).callback()

  test.equal("25分が経過しました", state.notifications[1].informativeText)
  test.equal(nil, activeMenubar(state))
end)

test.test("Timer は秒開始の残りを分:秒で表示する", function()
  local _, state = setup()
  startFromQuery(state, "90s")

  test.equal("1:30", activeMenubar(state).title)
end)

test.test("Timer は180分を 180:00 で表示する", function()
  local _, state = setup()
  startFromQuery(state, "180")

  test.equal("180:00", activeMenubar(state).title)
end)

test.test("Timer は走行中の Enter で置き換え通知しない", function()
  local _, state = setup()
  startFromQuery(state, "25")
  startFromQuery(state, "1")

  test.equal("1:00", activeMenubar(state).title)
  test.equal(true, state.menubars[1].deleted)
  test.equal(0, #state.notifications)
end)

test.test("Timer はメニューのキャンセルで止め通知しない", function()
  local _, state = setup()
  startFromQuery(state, "25")
  local menubar = activeMenubar(state)
  cancelMenu(menubar)

  test.equal(true, menubar.deleted)
  test.equal(nil, activeMenubar(state))
  test.equal(0, #state.notifications)
end)

test.test("Timer は入力中の再トグルで閉じて走行を続ける", function()
  local _, state = setup()
  startFromQuery(state, "25")
  local timer = require("modules.timer")
  timer.toggle()
  local chooser = state.choosers[1]
  test.equal(true, chooser.visible)
  test.equal("分（1〜180）", chooser.placeholderTextValue)

  timer.toggle()
  test.equal(false, chooser.visible)
  test.equal("25:00", activeMenubar(state).title)
end)

test.test("Timer は毎回分で開き直す", function()
  local _, state = setup()
  local timer = require("modules.timer")
  timer.toggle()
  typeQuery(state.choosers[1], "s")
  timer.toggle()
  timer.toggle()

  test.equal("分（1〜180）", state.choosers[1].placeholderTextValue)
  test.equal("", state.choosers[1].queryValue)
  test.equal(0, #state.choosers[1].currentChoices)
end)

test.test("Timer は通知できないとき alert に落とす", function()
  local _, state = setup()
  state.notifyPresented = false
  startFromQuery(state, "1s")
  state.now = state.now + 1
  repeatingTimer(state).callback()

  test.equal(1, #state.notifications)
  test.equal(0, #state.alerts)
  delayedTimer(state).callback()
  test.equal(1, #state.alerts)
  test.equal("1秒が経過しました", state.alerts[1])
end)

test.test("Timer は壁時計で残り時間を合わせる", function()
  local _, state = setup()
  startFromQuery(state, "10")
  state.now = state.now + 8 * 60
  repeatingTimer(state).callback()

  test.equal("2:00", activeMenubar(state).title)
end)

test.test("Timer は期限を過ぎた壁時計で完了する", function()
  local _, state = setup()
  startFromQuery(state, "5")
  state.now = state.now + 5 * 60 + 30
  repeatingTimer(state).callback()

  test.equal(nil, activeMenubar(state))
  test.equal("5分が経過しました", state.notifications[1].informativeText)
end)
