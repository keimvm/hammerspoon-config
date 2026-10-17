local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

local VALID = 'return { hotkeys = { { "ctrl+i", send = "up" } } }'
local VALID_CHANGED = 'return { hotkeys = { { "ctrl+j", send = "left" } } }'
local INVALID = 'return { hotkeys = { { "ctrl+i" } } }'

local function tempPath()
  return string.format(
    "%s/hammerspoon-reloader-%d-%d.lua",
    (os.getenv("TMPDIR") or "/tmp"):gsub("/$", ""),
    os.time(),
    math.random(1000000)
  )
end

local function write(path, content)
  local file = assert(io.open(path, "w"))
  file:write(content)
  file:close()
end

-- 一時ファイルを config.lua に見立てて監視を始める。
local function watch(content, applied)
  local hs, state = fakeHs.install()
  local path = tempPath()
  write(path, content)
  local reloader = require("modules.reloader")
  reloader.watch(path, applied ~= false)
  return {
    hs = hs,
    state = state,
    path = path,
    reloader = reloader,
    save = function(newContent)
      write(path, newContent)
      state.pathwatchers[1].callback({ path })
      state.delayedTimers[1]:fire()
    end,
    close = function() os.remove(path) end,
  }
end

test.test("Safe Reload は設定ファイルの親ディレクトリを監視し、その名前の変更だけを拾う", function()
  local env = watch(VALID)
  local watcher = env.state.pathwatchers[1]
  local debounce = env.state.delayedTimers[1]

  test.equal(env.path:match("^(.*)/"), watcher.path)
  test.equal(true, watcher.started)
  test.equal(0.3, debounce.delay)

  watcher.callback({ env.path .. ".swp", "/somewhere/else.lua" })
  test.equal(0, debounce.starts)
  watcher.callback({ env.path })
  test.equal(1, debounce.starts)
  env.close()
end)

test.test("Safe Reload は内容が変わらなければ再読み込みしない", function()
  local env = watch(VALID)

  env.save(VALID)

  test.equal(0, env.state.reloadCount)
  test.equal(0, #env.state.alerts)
  env.close()
end)

test.test("Safe Reload は検証に通った変更だけ印をつけて再読み込みする", function()
  local env = watch(VALID)

  env.save(VALID_CHANGED)

  test.equal(1, env.state.reloadCount)
  test.equal(true, env.state.settings["hammerspoon-config.reloaded"])
  test.equal(true, env.reloader.takeReloadedFlag())
  test.equal(false, env.reloader.takeReloadedFlag())
  env.close()
end)

test.test("Safe Reload は問題のある変更を適用せず、今の設定のまま問題を表示する", function()
  local env = watch(VALID)

  env.save(INVALID)

  test.equal(0, env.state.reloadCount)
  test.equal(1, #env.state.alerts)
  test.contains(env.state.alerts[1], "再読み込みしませんでした（今の設定のまま動いています）")
  test.contains(env.state.alerts[1], "hotkeys[1]: 動作を1つ指定してください")

  env.save(INVALID)
  test.equal(1, #env.state.alerts, "同じ内容の保存では繰り返し表示しない")

  env.save(VALID_CHANGED)
  test.equal(1, env.state.reloadCount)
  env.close()
end)

test.test("Safe Reload は起動時に適用できなかった場合もその旨を表示する", function()
  local env = watch(INVALID, false)

  env.save('return { hotkey = {} }')

  test.contains(env.state.alerts[1], "（設定はまだ適用されていません）")
  test.contains(env.state.alerts[1], "hotkey: 不明な項目です（もしかして hotkeys）")
  env.close()
end)

test.test("Safe Reload は Command から呼ぶと内容が同じでも再読み込みする", function()
  local env = watch(VALID)

  require("modules.commands").get("reload").run()

  test.equal(1, env.state.reloadCount)
  env.close()
end)
