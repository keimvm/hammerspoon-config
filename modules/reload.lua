local M = {}

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
    hotkey.mods = {}
  elseif type(hotkey.mods) == "table" then
    hotkey.mods = copyList(hotkey.mods)
  end

  if type(hotkey.id) ~= "string" or hotkey.id == "" then
    hotkey.id = "reload.config"
  end

  return hotkey
end

function M.bind(hotkey, registry)
  registry:bind(M.desiredHotkey(hotkey), function()
    hs.eventtap.keyStroke({ "cmd" }, "r", 0)
  end)
end

return M
