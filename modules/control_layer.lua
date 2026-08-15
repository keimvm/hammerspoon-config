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

local function destinationId(to)
  if type(to) == "string" and to ~= "" then
    return string.lower(to)
  end
  if type(to) ~= "table" then return nil end
  if type(to.key) ~= "string" or to.key == "" then return nil end

  local parts = {}
  if type(to.mods) == "table" then
    for _, mod in ipairs(to.mods) do
      if type(mod) == "string" and mod ~= "" then
        table.insert(parts, string.lower(mod))
      end
    end
  end
  table.insert(parts, string.lower(to.key))
  return table.concat(parts, "+")
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

  if type(hotkey.id) ~= "string" or hotkey.id == "" then
    local id = destinationId(hotkey.to)
    if id then hotkey.id = "control-layer." .. id end
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

local function emitTarget(to)
  if type(to) == "table" then
    local mods = to.mods
    if type(mods) ~= "table" then mods = {} end
    hs.eventtap.keyStroke(mods, to.key, 0)
    return
  end

  hs.eventtap.keyStroke({}, to, 0)
end

local function bindHotkeys(bindings, registry)
  for _, binding in ipairs(bindings or {}) do
    local emit = function()
      emitTarget(binding.to)
    end
    local repeatFn
    if binding.repeatable ~= false then repeatFn = emit end
    registry:bind(M.desiredHotkey(binding), emit, nil, repeatFn)
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
