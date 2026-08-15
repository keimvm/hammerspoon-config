local appSwitcher = require("modules.app_switcher")
local timer = require("modules.timer")
local unicodeConverter = require("modules.unicode_converter")

local M = {}

function M.bind(config, registry)
  config = config or {}

  for _, binding in ipairs(config.appSwitchers or {}) do
    appSwitcher.bindToggle(binding, registry)
  end

  if config.timer then
    registry:bind(timer.desiredHotkey(config.timer), function()
      timer.toggle()
    end)
  end

  if config.unicodeConverter then
    registry:bind(unicodeConverter.desiredHotkey(config.unicodeConverter), function()
      unicodeConverter.toggle()
    end)
  end
end

return M
