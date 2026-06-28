local M = {}

local eventtap = hs.eventtap
local event = eventtap.event
local types = event.types
local props = event.properties

local tap
local virtualModifierDown = false

local function markSynthetic(ev, userData)
  if userData then
    ev:setProperty(props.eventSourceUserData, userData)
  end
  return ev
end

local function postModifier(key, isDown, userData)
  markSynthetic(event.newKeyEvent(hs.keycodes.map[key], isDown), userData):post()
  virtualModifierDown = isDown
end

local function bindArrowHotkeys(arrows)
  for _, binding in ipairs(arrows or {}) do
    hs.hotkey.bind(binding.mods, binding.key, function()
      hs.eventtap.keyStroke({}, binding.arrow, 0)
    end)
  end
end

function M.bind(config)
  config = config or {}

  bindArrowHotkeys(config.arrows)

  if config.sentinelCommand and config.sentinelCommand.enabled ~= false then
    local sentinelKeyCode = hs.keycodes.map[config.sentinelCommand.sentinelKey]
    local virtualModifier = config.sentinelCommand.virtualModifier
    local userData = config.sentinelCommand.syntheticEventSourceUserData

    if not sentinelKeyCode then
      error("unknown sentinel key: " .. tostring(config.sentinelCommand.sentinelKey))
    end

    if virtualModifierDown then
      postModifier(virtualModifier, false, userData)
    end

    tap = eventtap.new({ types.keyDown, types.keyUp }, function(e)
      if e:getKeyCode() ~= sentinelKeyCode then return false end

      if e:getType() == types.keyDown then
        if not virtualModifierDown then
          postModifier(virtualModifier, true, userData)
        end
      elseif virtualModifierDown then
        postModifier(virtualModifier, false, userData)
      end

      return true
    end)

    tap:start()
  end
end

return M
