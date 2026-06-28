local M = {}

function M.bind(hotkey, registry)
  registry:bind(hotkey, function()
    hs.eventtap.keyStroke({ "cmd" }, "r", 0)
  end)
end

return M
