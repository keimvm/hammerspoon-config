local M = {}

local eventtap = hs.eventtap
local event = eventtap.event
local types = event.types
local props = event.properties

local tap

local function isIgnored(e, ignoredUserData)
  return ignoredUserData and e:getProperty(props.eventSourceUserData) == ignoredUserData
end

local function hasDownState(states)
  for _, state in pairs(states) do
    if state.down then return true end
  end
  return false
end

local function markDownStatesUsed(states)
  for _, state in pairs(states) do
    if state.down then state.used = true end
  end
end

function M.bind(config)
  if not config or config.enabled == false then return end

  local states = {}
  for _, binding in ipairs(config.bindings or {}) do
    local keyCode = hs.keycodes.map[binding.commandKey]
    if not keyCode then error("unknown command key: " .. tostring(binding.commandKey)) end

    states[keyCode] = {
      down = false,
      used = false,
      outputKeyCode = binding.outputKeyCode,
    }
  end

  local watchedTypes = {
    types.flagsChanged,
    types.keyDown,
    types.leftMouseDown,
    types.rightMouseDown,
    types.otherMouseDown,
  }

  tap = eventtap.new(watchedTypes, function(e)
    if isIgnored(e, config.ignoredEventSourceUserData) then return false end

    local eventType = e:getType()
    local keyCode = e:getKeyCode()
    local state = states[keyCode]

    if eventType == types.flagsChanged and state then
      if not state.down then
        if not e:getFlags().cmd then return false end

        local isChord = hasDownState(states)
        markDownStatesUsed(states)
        state.down = true
        state.used = isChord
      else
        state.down = false

        if not state.used then
          hs.eventtap.keyStroke({}, state.outputKeyCode, 0)
        end
      end

      return false
    end

    if eventType == types.flagsChanged then
      markDownStatesUsed(states)
      return false
    end

    if eventType ~= types.flagsChanged then
      markDownStatesUsed(states)
    end

    return false
  end)

  tap:start()
end

return M
