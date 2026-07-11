local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

test.test("init.lua は Config Preflight 成功後に runtime side effect を開始する", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  for name in pairs(package.loaded) do
    if name:match("^modules%.") then
      package.loaded[name] = nil
    end
  end

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)
  test.equal("keycode.lookup", state.operations[1])
end)

test.test("init.lua は Config Preflight 失敗時に runtime side effect を開始しない", function()
  local hs, state = fakeHs.new()
  _G.hs = hs

  for name in pairs(package.loaded) do
    if name:match("^modules%.") then
      package.loaded[name] = nil
    end
  end

  local init = assert(loadfile("init.lua"))
  local ok, err = pcall(init, {})

  test.equal(false, ok)
  test.contains(err, "invalid Hammerspoon config:")
  test.equal(0, #state.hotkeys)
  test.equal(0, #state.eventtaps)
  test.equal(0, #state.tasks)
end)
