local test = require("tests.test_helper")
local fakeHs = require("tests.support.fake_hs")

test.test("init.lua は fake hs 上で必要 module を読み込める", function()
  local hs = fakeHs.new()
  _G.hs = hs

  for name in pairs(package.loaded) do
    if name:match("^modules%.") then
      package.loaded[name] = nil
    end
  end

  local ok, err = pcall(dofile, "init.lua")
  test.equal(true, ok, err)
end)
