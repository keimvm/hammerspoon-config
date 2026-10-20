local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

-- Finder を最前面にし、ファイル一覧にフォーカスがある状態から始める。
local function start(options)
  options = options or {}
  local _, state = fakeHs.install()
  state.frontmostApplication = options.app or fakeHs.app("Finder", { bundleID = "com.apple.finder" })
  state.focusedRole = options.focusedRole or "AXOutline"
  return state, require("modules.finder_cut")
end

local function lastStroke(state)
  local stroke = state.keyStrokes[#state.keyStrokes]
  return table.concat(stroke.mods, "+") .. "+" .. stroke.key, stroke
end

-- Finder がコピーを終えて pasteboard が変わったことにし、待っている timer を進める。
local function finishCopy(state)
  state.pasteboardChangeCount = state.pasteboardChangeCount + 1
  for _, timer in ipairs(state.timers) do
    if timer.running then timer.callback() end
  end
end

test.test("Finder Cut は切り取りをコピーとして送り、続く貼り付けを移動にする", function()
  local state, finderCut = start()

  finderCut.cut()
  local copy, stroke = lastStroke(state)
  test.equal("cmd+c", copy)
  test.equal(0, stroke.delay)
  test.equal(state.frontmostApplication, stroke.application, "Hotkey に戻らないよう Finder へ直接送る")

  finishCopy(state)
  test.equal(false, state.timers[1].running, "コピーを記録したら待つのをやめる")

  finderCut.paste()
  test.equal("cmd+alt+v", (lastStroke(state)))
  finderCut.paste()
  test.equal("cmd+v", (lastStroke(state)), "移動は1回だけ")
end)

test.test("Finder Cut は切り取りの後に別のものをコピーしていれば通常の貼り付けにする", function()
  local state, finderCut = start()

  finderCut.cut()
  finishCopy(state)
  state.pasteboardChangeCount = state.pasteboardChangeCount + 1

  finderCut.paste()
  test.equal("cmd+v", (lastStroke(state)))
end)

test.test("Finder Cut は切り取っていなければ通常の貼り付けにする", function()
  local state, finderCut = start()

  finderCut.paste()
  local paste, stroke = lastStroke(state)
  test.equal("cmd+v", paste)
  test.equal(state.frontmostApplication, stroke.application)
end)

test.test("Finder Cut はコピーが反映されないまま待ち切ったら、移動にしない", function()
  local state, finderCut = start()

  finderCut.cut()
  local poll = state.timers[1]
  for _ = 1, 50 do poll.callback() end
  test.equal(false, poll.running)

  finderCut.paste()
  test.equal("cmd+v", (lastStroke(state)))
end)

test.test("Finder Cut は新しい切り取りで前の切り取りを取り消す", function()
  local state, finderCut = start()

  finderCut.cut()
  finishCopy(state)
  finderCut.cut()
  test.equal(false, state.timers[1].running, "前の待ちを止める")

  finderCut.paste()
  test.equal("cmd+v", (lastStroke(state)), "新しいコピーが反映されるまでは移動にしない")
end)

test.test("Finder Cut は名前の入力欄などでは文字の切り取り・貼り付けを送る", function()
  for _, role in ipairs({ "AXTextField", "AXTextArea", "AXComboBox" }) do
    local state, finderCut = start({ focusedRole = role })

    finderCut.cut()
    test.equal("cmd+x", (lastStroke(state)), role)
    test.equal(0, #state.timers)
  end

  local state, finderCut = start()
  finderCut.cut()
  finishCopy(state)
  state.focusedRole = "AXTextField"
  finderCut.paste()
  test.equal("cmd+v", (lastStroke(state)), "入力欄への貼り付けでは移動しない")
  state.focusedRole = "AXOutline"
  finderCut.paste()
  test.equal("cmd+alt+v", (lastStroke(state)), "切り取りは入力欄の貼り付けで消えない")
end)

test.test("Finder Cut は AX の問い合わせに上限を付け、失敗したら通常の操作にする", function()
  local state, finderCut = start()

  finderCut.cut()
  for _, element in ipairs(state.axElements) do
    test.equal(0.05, element.queries[1].timeout, element.kind)
  end

  state.axErrors = { ["app.AXFocusedUIElement"] = true }
  finderCut.cut()
  test.equal("cmd+x", (lastStroke(state)))
end)

test.test("Finder Cut は Finder 以外では通常の切り取り・貼り付けを送る", function()
  local state, finderCut = start({ app = fakeHs.app("Zed") })

  finderCut.cut()
  test.equal("cmd+x", (lastStroke(state)))
  finderCut.paste()
  test.equal("cmd+v", (lastStroke(state)))
  test.equal(0, #state.timers)
end)
