local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function loadChord()
  fakeHs.install()
  return require("modules.chord")
end

test.test("Chord は修飾キーの別名・順序・大文字小文字を正規化する", function()
  local chord = loadChord()
  local parsed = assert(chord.parse("Command+Shift+U"))

  test.equal("shift+cmd+u", parsed.id)
  test.equal(2, #parsed.mods)
  test.equal("shift", parsed.mods[1])
  test.equal("cmd", parsed.mods[2])
  test.equal("u", parsed.key)
  test.equal(parsed.id, assert(chord.parse("⇧ + ⌘ + u")).id)
  test.equal("ctrl+i", assert(chord.parse("ctrl+control+i")).id)
end)

test.test("Chord は修飾キーなしのキーと記号キーを受け付ける", function()
  local chord = loadChord()

  test.equal("f5", assert(chord.parse("F5")).id)
  test.equal("ctrl+;", assert(chord.parse("ctrl+;")).id)
  test.equal("forwarddelete", assert(chord.parse("forwarddelete")).id)
end)

test.test("Chord はテンキーの加算キーを区切り文字と区別する", function()
  local chord = loadChord()

  test.equal("pad+", assert(chord.parse("pad+")).key)
  local parsed = assert(chord.parse("Control + PAD+"))
  test.equal("ctrl+pad+", parsed.id)
  test.equal("ctrl", parsed.mods[1])
  test.equal("pad+", parsed.key)
  test.equal(nil, (chord.parse("ctrl++pad+")))
end)

test.test("Chord は macOS のメニューと同じ記号で表示する", function()
  local chord = loadChord()

  test.equal("⌃⇧U", chord.display(assert(chord.parse("shift+ctrl+u"))))
  test.equal("F5", chord.display(assert(chord.parse("f5"))))
  test.equal("⌘R", chord.display(assert(chord.parse("cmd+r"))))
  test.equal("↑", chord.display(assert(chord.parse("up"))))
  test.equal("⌫", chord.display(assert(chord.parse("delete"))))
  test.equal("⌃;", chord.display(assert(chord.parse("ctrl+;"))))
end)

test.test("Chord は打ち間違いに近い候補を添えて拒否する", function()
  local chord = loadChord()

  local _, modifierError = chord.parse("ctl+i")
  test.contains(modifierError, "不明な修飾キーです: ctl")
  test.contains(modifierError, "もしかして ctrl")

  local _, keyError = chord.parse("ctrl+forwardelete")
  test.contains(keyError, "不明なキーです: forwardelete")
  test.contains(keyError, "もしかして forwarddelete")
end)

test.test("Chord は空のキーと Hotkey の fn を拒否し、送り先の fn は受け付ける", function()
  local chord = loadChord()

  test.equal(nil, (chord.parse("")))
  test.equal(nil, (chord.parse(42)))
  local _, emptyKey = chord.parse("ctrl+")
  test.contains(emptyKey, "キーがありません")

  local _, fnError = chord.parse("fn+left")
  test.contains(fnError, "fn は Hotkey の修飾キーには使えません")
  test.equal("fn+left", assert(chord.parse("fn+left", { allowFn = true })).id)
end)
