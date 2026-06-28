local appSwitcher = require("modules.app_switcher")

local M = {}

function M.bind(config, registry)
  config = config or {}

  for _, binding in ipairs(config.appSwitchers or {}) do
    appSwitcher.bindToggle(binding, registry)
  end

  if config.unicodeConverter then
    registry:bind(config.unicodeConverter, function()
      local unicodeConverter = require("modules.unicode_converter")
      unicodeConverter.toggle()
    end)
  end
end

return M
