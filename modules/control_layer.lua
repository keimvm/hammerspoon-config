local M = {}

local eventtap = hs.eventtap
local event = eventtap.event
local types = event.types
local props = event.properties
local DEFAULT_MODS = { "ctrl" }

local tap
local virtualModifierDown = false

local function copyList(list)
  local copy = {}
  for index, value in ipairs(list) do
    copy[index] = value
  end
  return copy
end

function M.desiredHotkey(binding)
  if type(binding) ~= "table" then return binding end

  local hotkey = {}
  for key, value in pairs(binding) do
    hotkey[key] = value
  end

  if hotkey.mods == nil then
    hotkey.mods = copyList(DEFAULT_MODS)
  elseif type(hotkey.mods) == "table" then
    hotkey.mods = copyList(hotkey.mods)
  end

  if (type(hotkey.id) ~= "string" or hotkey.id == "")
    and type(hotkey.to) == "string"
    and hotkey.to ~= ""
  then
    hotkey.id = "control-layer." .. string.lower(hotkey.to)
  end

  return hotkey
end

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

local function bindHotkeys(bindings, registry)
  for _, binding in ipairs(bindings or {}) do
    local emit = function()
      hs.eventtap.keyStroke({}, binding.to, 0)
    end
    registry:bind(M.desiredHotkey(binding), emit, nil, emit)
  end
end

function M.bind(config, registry)
  config = config or {}

  bindHotkeys(config.bindings, registry)

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
