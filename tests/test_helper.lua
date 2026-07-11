local M = { cases = {} }

local function render(value)
  if type(value) == "string" then return string.format("%q", value) end
  return tostring(value)
end

function M.test(name, fn)
  table.insert(M.cases, { name = name, fn = fn })
end

function M.equal(expected, actual, message)
  if expected == actual then return end
  error(message or string.format("expected %s, got %s", render(expected), render(actual)), 2)
end

function M.truthy(value, message)
  if value then return end
  error(message or "expected a truthy value", 2)
end

function M.contains(text, fragment, message)
  if type(text) == "string" and text:find(fragment, 1, true) then return end
  error(message or string.format("expected %s to contain %s", render(text), render(fragment)), 2)
end

function M.resetModule(name)
  package.loaded[name] = nil
end

function M.run()
  local failed = 0

  for _, case in ipairs(M.cases) do
    local ok, err = pcall(case.fn)
    if ok then
      io.write("ok - ", case.name, "\n")
    else
      failed = failed + 1
      io.stderr:write("not ok - ", case.name, "\n", tostring(err), "\n")
    end
  end

  io.write(string.format("%d tests, %d failures\n", #M.cases, failed))
  return failed == 0
end

return M
