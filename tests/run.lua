package.path = "./?.lua;./?/init.lua;" .. package.path

-- 引数がなければ tests/*_test.lua をすべて実行する。
local testFiles = {}
if arg[1] then
  testFiles = { arg[1] }
else
  local listing = assert(io.popen("ls tests/*_test.lua"))
  for file in listing:lines() do table.insert(testFiles, file) end
  listing:close()
end

for _, file in ipairs(testFiles) do
  dofile(file)
end

local test = require("tests.test_helper")
if not test.run() then os.exit(1) end
