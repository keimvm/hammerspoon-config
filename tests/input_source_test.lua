local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function start(config, frontmostApp)
  local _, state = fakeHs.install()
  state.frontmostApplication = frontmostApp
  require("modules.input_source").start(config)
  require("modules.frontmost").start()
  return state
end

local CONFIG = {
  eisu = { "Zed", "cmux" },
  kana = { "Typora" },
}

test.test("Input Source は起動時に対象アプリが最前面なら切り替える", function()
  local state = start(CONFIG, fakeHs.app("Zed"))

  test.equal(1, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)
  test.equal(1, #state.applicationWatchers)
  test.equal(true, state.applicationWatchers[1].started)
end)

test.test("Input Source は対象アプリの activate で英数・かなを送る", function()
  local state = start(CONFIG, fakeHs.app("Safari"))
  test.equal(0, #state.keyStrokes)

  state.activate(fakeHs.app("cmux"))
  state.activate(fakeHs.app("Typora"))

  test.equal(2, #state.keyStrokes)
  test.equal(0x66, state.keyStrokes[1].key)
  test.equal(0x68, state.keyStrokes[2].key)
end)

test.test("Input Source は対象外のアプリや不明な最前面では入力ソースを変えない", function()
  local state = start(CONFIG, nil)

  state.activate(fakeHs.app("Notion"))
  state.activate(nil)

  test.equal(0, #state.keyStrokes)
end)

test.test("Input Source は設定がなければアプリを監視しない", function()
  local state = start({ eisu = {} }, fakeHs.app("Zed"))

  test.equal(0, #state.applicationWatchers)
end)
