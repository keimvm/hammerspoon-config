local appSwitcher = require("modules.app_switcher")

local M = {}

local function enabled(config)
  return config.enabled ~= false
end

function M.bind(config)
  config = config or {}

  for _, binding in ipairs(config.appSwitchers or {}) do
    if enabled(binding) then
      appSwitcher.bindToggle(binding.appName, binding.mods, binding.key, binding.dirToOpen)
    end
  end

  if config.unicodeConverter and enabled(config.unicodeConverter) then
    local unicodeConverter = require("modules.unicode_converter")
    unicodeConverter.bindHotkey(config.unicodeConverter.mods, config.unicodeConverter.key)
  end
end

return M
