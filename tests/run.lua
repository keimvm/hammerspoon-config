package.path = "./?.lua;./?/init.lua;" .. package.path

local testFiles = {
  "tests/init_test.lua",
  "tests/config_validation_test.lua",
  "tests/hotkey_registry_test.lua",
  "tests/reload_test.lua",
  "tests/input_remap_test.lua",
  "tests/app_switcher_test.lua",
  "tests/app_hotkey_blocker_test.lua",
  "tests/unicode_converter_test.lua",
}

if arg[1] then testFiles = { arg[1] } end

for _, file in ipairs(testFiles) do
  dofile(file)
end

local test = require("tests.test_helper")
if not test.run() then os.exit(1) end
