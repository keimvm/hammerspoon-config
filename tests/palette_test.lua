local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function boot()
  local hs, state = fakeHs.install()
  local ok, err = pcall(assert(loadfile("init.lua")))
  test.equal(true, ok, err)
  return hs, state
end

local function openPalette(state)
  for _, hotkey in ipairs(state.hotkeys) do
    if hotkey.key == ";" then
      hotkey.pressedFn()
      return state.choosers[#state.choosers]
    end
  end
  error("パレットの Hotkey がありません")
end

local function rowIndex(chooser, text)
  for index, row in ipairs(chooser.currentChoices) do
    if row.text == text then return index end
  end
end

local function rowFor(chooser, text)
  local index = rowIndex(chooser, text)
  return index and chooser.currentChoices[index]
end

-- 選んだ行の動作は、chooser が閉じて少し後に実行される。
local function select(state, chooser, text)
  chooser:select(assert(rowIndex(chooser, text), text .. " の行がありません"))
  local timer = state.timers[#state.timers]
  test.equal(0.05, timer.delay)
  timer.callback()
end

test.test("コマンドパレットは設定の Hotkey を記号つきで一覧する", function()
  local _, state = boot()
  local chooser = openPalette(state)

  test.equal(true, chooser.visible)
  test.equal(true, chooser.searchSubTextValue)
  test.equal("↑ を送る", chooser.currentChoices[1].text)
  test.equal("⌃I", chooser.currentChoices[1].subText)
  test.equal("⌃M", rowFor(chooser, "Typora に切り替え").subText)
  test.equal("F5", rowFor(chooser, "⌘R を送る").subText)
  test.equal("⌘D · Google Chrome のみ", rowFor(chooser, "⌘D を無効化").subText)
  test.equal("⌃P", rowFor(chooser, "タイマー").subText)
  test.equal(nil, rowFor(chooser, "コマンドパレット"), "パレット自身は並べない")
end)

test.test("コマンドパレットは Hotkey のない Command も並べる", function()
  local _, state = boot()
  local chooser = openPalette(state)

  test.equal("Hotkey なし", rowFor(chooser, "設定を再読み込み").subText)
  test.equal("Hotkey なし", rowFor(chooser, "Hammerspoon Console を開く").subText)
  test.equal("Hotkey なし", rowFor(chooser, "キー変換を一時解除").subText)

  local timerRows = 0
  for _, row in ipairs(chooser.currentChoices) do
    if row.text == "タイマー" then timerRows = timerRows + 1 end
  end
  test.equal(1, timerRows, "Hotkey のある Command を二重に並べない")
end)

test.test("コマンドパレットは選んだ行を閉じた後に実行する", function()
  local _, state = boot()
  local chooser = openPalette(state)

  select(state, chooser, "Typora に切り替え")
  test.equal(false, chooser.visible)
  test.equal("Typora", state.launchedApps[1])

  chooser = openPalette(state)
  select(state, chooser, "Hammerspoon Console を開く")
  test.equal(1, state.consoleOpened)

  chooser = openPalette(state)
  chooser:select(nil)
  test.equal(1, state.consoleOpened, "Esc で閉じても何も実行しない")
end)

test.test("コマンドパレットは実行中のタイマーを残り時間とともに止められる", function()
  local _, state = boot()
  local timer = require("modules.timer")
  timer.toggle()
  local timerChooser = state.choosers[#state.choosers]
  timerChooser.queryValue = "10"
  timerChooser.queryChangedFn("10")
  timerChooser:select(1)
  state.now = state.now + 30

  local chooser = openPalette(state)
  test.equal("残り 9:30", rowFor(chooser, "タイマーを停止").subText)
  select(state, chooser, "タイマーを停止")

  test.equal(nil, timer.remainingText())
  chooser = openPalette(state)
  test.equal(nil, rowFor(chooser, "タイマーを停止"))
end)

test.test("コマンドパレットは同じ Hotkey で閉じる", function()
  local _, state = boot()
  local chooser = openPalette(state)
  openPalette(state)

  test.equal(false, chooser.visible)
end)
