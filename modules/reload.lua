local M = {}

function M.bind()
  -- F5 -> Cmd+R
  hs.hotkey.bind({}, "F5", function()
    hs.eventtap.keyStroke({ "cmd" }, "r", 0)
  end)
end

return M
