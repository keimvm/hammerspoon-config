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
