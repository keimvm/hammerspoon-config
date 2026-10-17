local M = {}

local eventtap = hs.eventtap
local event = eventtap.event
local types = event.types
local props = event.properties

local tap
local chordTap

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

  -- 通常の打鍵を Hammerspoon の処理に通さないため、常時監視するのは flagsChanged だけにする。
  -- keyDown とマウス押下は、対象の Command キーを押している間だけ別の eventtap で監視する。
  local chordTypes = {
    types.keyDown,
    types.leftMouseDown,
    types.rightMouseDown,
    types.otherMouseDown,
  }
  local synchronized = not eventtap.checkKeyboardModifiers().cmd

  local function syncChordTap()
    if hasDownState(states) then
      chordTap:start()
    else
      chordTap:stop()
    end
  end

  tap = eventtap.new({ types.flagsChanged }, function(e)
    if not synchronized then
      if not e:getFlags().cmd then
        synchronized = true
      end
      return false
    end

    if isIgnored(e, config.ignoredEventSourceUserData) then return false end

    local keyCode = e:getKeyCode()
    local state = states[keyCode]

    if state then
      if not state.down then
        local flags = e:getFlags()
        if not flags.cmd then return false end

        local isChord = flags.ctrl or flags.alt or flags.shift or flags.fn or hasDownState(states)
        markDownStatesUsed(states)
        state.down = true
        state.used = isChord
        syncChordTap()
      else
        state.down = false
        -- 監視中の tap を送信直後に破棄すると、送信したキーが届かないことがあるため先に止める。
        syncChordTap()

        if not state.used then
          hs.eventtap.keyStroke({}, state.outputKeyCode, 0)
        end
      end

      return false
    end

    markDownStatesUsed(states)
    return false
  end)

  chordTap = eventtap.new(chordTypes, function(e)
    if not isIgnored(e, config.ignoredEventSourceUserData) then
      markDownStatesUsed(states)
    end
    return false
  end)

  tap:start()
end

return M
