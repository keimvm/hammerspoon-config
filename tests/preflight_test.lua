local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local function loadPreflight()
  fakeHs.install()
  return require("modules.preflight")
end

local function problemsFor(config)
  return loadPreflight().check(config)
end

local function hasProblem(problems, fragment)
  for _, problem in ipairs(problems) do
    if problem:find(fragment, 1, true) then return true end
  end
  return false
end

local function expectProblem(problems, fragment)
  test.truthy(hasProblem(problems, fragment), string.format(
    "%q を含む問題がありません:\n%s", fragment, table.concat(problems, "\n")
  ))
end

local function writeTempFile(content)
  local path = string.format(
    "%s/hammerspoon-preflight-%d-%d.lua",
    os.getenv("TMPDIR") or "/tmp",
    os.time(),
    math.random(1000000)
  )
  local file = assert(io.open(path, "w"))
  file:write(content)
  file:close()
  return path
end

test.test("Config Preflight は同梱の config.lua を受け付ける", function()
  local config, problems = loadPreflight().load("./config.lua")

  test.truthy(config, table.concat(problems or {}, "\n"))
  test.equal(0, #problems)
end)

test.test("Config Preflight は設定がテーブルでなければ拒否する", function()
  expectProblem(problemsFor(nil), "config: config.lua は設定のテーブルを return してください")
end)

test.test("Config Preflight は不明な項目を打ち間違いの候補とともに報告する", function()
  local problems = problemsFor({ hotkey = {}, remap = {} })

  expectProblem(problems, "hotkey: 不明な項目です（もしかして hotkeys）")
end)

test.test("Config Preflight は複数の問題を1回でまとめて報告する", function()
  local problems = problemsFor({
    remap = { caps_lockk = "left_control" },
    hotkeys = { { "ctl+i", send = "up" }, { "ctrl+m" } },
    inputSource = { eisuu = { "Zed" } },
  })

  test.equal(4, #problems)
  expectProblem(problems, "remap.caps_lockk: 変換できないキーです（もしかして caps_lock）")
  expectProblem(problems, "hotkeys[1]: 不明な修飾キーです: ctl（もしかして ctrl）")
  expectProblem(problems, "hotkeys[2]: 動作を1つ指定してください")
  expectProblem(problems, "inputSource.eisuu: eisu か kana を指定してください（もしかして eisu）")
end)

test.test("Config Preflight は remap の変換先と以前のリスト形式を拒否する", function()
  local problems = problemsFor({ remap = { caps_lock = "left_ctrl", escape = 1 } })
  expectProblem(problems, "remap.caps_lock: 変換先のキーが不明です: left_ctrl（もしかして left_control）")
  expectProblem(problems, "remap.escape: 変換先のキーが不明です: 1")

  problems = problemsFor({ remap = { { from = "caps_lock", to = "left_control" } } })
  expectProblem(problems, "remap: 物理キー = \"変換後のキー\" の形で書いてください")
end)

test.test("Config Preflight は hotkeys の形と動作の組み合わせを検証する", function()
  local problems = problemsFor({
    hotkeys = {
      { "ctrl+a", send = "up", app = "Zed" },
      { "ctrl+b", app = "" },
      { "ctrl+c", run = "timr" },
      { "ctrl+e", block = 1 },
      { "ctrl+f", app = "Zed", once = true },
      { "ctrl+g", send = "up", once = "yes" },
      { "ctrl+h", block = true, only = "Zed", except = "cmux" },
      { "ctrl+i", block = true, only = {} },
      { "ctrl+j", app = "Zed", onyl = "Zed" },
      { "ctrl+k", "Zed" },
      { "fn+l", send = "up" },
      { "ctrl+m", send = "ctrl+nope" },
      { "ctrl+n", app = "Zed", label = "" },
      "ctrl+o",
    },
  })

  expectProblem(problems, "hotkeys[1]: 動作は1つだけ指定してください（send と app）")
  expectProblem(problems, "hotkeys[2].app: 空でない文字列を指定してください")
  expectProblem(problems, "hotkeys[3].run: 不明な Command です: timr（もしかして timer）")
  expectProblem(problems, "hotkeys[4].block: block = true と書いてください")
  expectProblem(problems, "hotkeys[5].once: once は send と組み合わせて使います")
  expectProblem(problems, "hotkeys[6].once: true か false を指定してください")
  expectProblem(problems, "hotkeys[7]: only と except は同時に指定できません")
  expectProblem(problems, "hotkeys[8].only: アプリ名を1つ以上指定してください")
  expectProblem(problems, "hotkeys[9].onyl: 不明な項目です（もしかして only）")
  expectProblem(problems, "hotkeys[10]: [2] の値は使えません。項目名 = 値 の形で書いてください")
  expectProblem(problems, "hotkeys[11]: fn は Hotkey の修飾キーには使えません")
  expectProblem(problems, "hotkeys[12].send: 不明なキーです: nope")
  expectProblem(problems, "hotkeys[13].label: 空でない文字列を指定してください")
  expectProblem(problems, "hotkeys[14]: テーブル { ... } で指定してください")
  test.equal(15, #problems)
end)

test.test("Config Preflight は番号が飛んだ Hotkey のリストを拒否する", function()
  local hotkeys = {}
  hotkeys[2] = { "ctrl+j", send = "left" }
  hotkeys[4] = { "ctrl+l", send = "right" }

  local config, problems = loadPreflight().load({ hotkeys = hotkeys })

  test.equal(nil, config)
  expectProblem(problems, "hotkeys: { ... } に順に並べたリストで指定してください")
end)

test.test("Config Preflight はテンキーの加算キーを Hotkey と send に使える", function()
  local problems = problemsFor({ hotkeys = {
    { "ctrl+pad+", send = "pad+" },
  } })

  test.equal(0, #problems, table.concat(problems, "\n"))
end)

test.test("Config Preflight は表記が違っても同じ Hotkey Identity の重複を拒否する", function()
  local problems = problemsFor({
    hotkeys = {
      { "shift+cmd+u", run = "timer" },
      { "Command+Shift+U", app = "Zed" },
    },
  })

  test.equal(1, #problems)
  expectProblem(problems, "hotkeys[2]: ⇧⌘U は hotkeys[1] と重複しています")
end)

test.test("Config Preflight は動作に問題がある Hotkey の重複も同時に報告する", function()
  local problems = problemsFor({
    hotkeys = {
      { "ctrl+r", app = "Zed" },
      { "Ctrl+R", run = 42 },
    },
  })

  test.equal(2, #problems, table.concat(problems, "\n"))
  expectProblem(problems, "hotkeys[2].run: Command 名（palette / timer / reload / console / remap-off）か関数を指定してください")
  expectProblem(problems, "hotkeys[2]: ⌃R は hotkeys[1] と重複しています")
end)

test.test("Config Preflight は範囲が重ならない同じ Hotkey を受け付ける", function()
  local problems = problemsFor({
    hotkeys = {
      { "ctrl+r", app = "Zed", except = { "Google Chrome", "Safari" } },
      { "ctrl+r", send = "cmd+r", only = "Google Chrome" },
      { "ctrl+r", block = true, only = "Safari" },
    },
  })

  test.equal(0, #problems, table.concat(problems, "\n"))
end)

test.test("Config Preflight は範囲が重なる同じ Hotkey を拒否する", function()
  local problems = problemsFor({
    hotkeys = {
      { "ctrl+a", app = "Zed", only = { "Zed", "cmux" } },
      { "ctrl+a", block = true, only = "cmux" },
      { "ctrl+b", app = "Zed", except = "Zed" },
      { "ctrl+b", block = true, except = "cmux" },
      { "ctrl+c", app = "Zed", except = "Zed" },
      { "ctrl+c", block = true, only = { "Zed", "Safari" } },
      { "ctrl+d", app = "Zed" },
      { "ctrl+d", block = true, only = "Safari" },
    },
  })

  test.equal(4, #problems, table.concat(problems, "\n"))
  expectProblem(problems, "hotkeys[2]: ⌃A は hotkeys[1] と重複しています")
  expectProblem(problems, "hotkeys[4]: ⌃B は hotkeys[3] と重複しています")
  expectProblem(problems, "hotkeys[6]: ⌃C は hotkeys[5] と重複しています")
  expectProblem(problems, "hotkeys[8]: ⌃D は hotkeys[7] と重複しています")
end)

test.test("Config Preflight は inputSource の形と重複を検証する", function()
  local problems = problemsFor({
    inputSource = {
      eisu = { "Zed", "cmux" },
      kana = { "Typora", "Zed", 3 },
    },
  })

  test.equal(2, #problems, table.concat(problems, "\n"))
  expectProblem(problems, "inputSource.kana[2]: Zed は inputSource.eisu[1] にもあります")
  expectProblem(problems, "inputSource.kana[3]: 空でない文字列を指定してください")
end)

test.test("Config Preflight は設定データを変更しない", function()
  local preflight = loadPreflight()
  local entry = { "ctrl+m", app = "Typora", only = "Finder" }
  local config = { hotkeys = { entry }, inputSource = { eisu = { "Zed" } } }

  test.equal(0, #preflight.check(config))
  test.equal("Finder", entry.only)
  test.equal(nil, entry.label)
  test.equal(1, #config.hotkeys)
  test.equal(nil, config.remap)
end)

test.test("Config Preflight は config.lua の構文エラーと実行時エラーを報告する", function()
  local preflight = loadPreflight()

  local syntaxPath = writeTempFile("return {")
  local config, problems = preflight.load(syntaxPath)
  os.remove(syntaxPath)
  test.equal(nil, config)
  expectProblem(problems, "config.lua を読み込めません")

  local runtimePath = writeTempFile("error('boom')")
  config, problems = preflight.load(runtimePath)
  os.remove(runtimePath)
  test.equal(nil, config)
  expectProblem(problems, "config.lua の実行中にエラーが起きました")
  expectProblem(problems, "boom")
end)
