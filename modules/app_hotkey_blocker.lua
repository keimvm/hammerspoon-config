local M = {}

local state = {}
local DEFAULT_MODS = { "cmd" }

local function copyList(list)
  local copy = {}
  for index, value in ipairs(list) do
    copy[index] = value
  end
  return copy
end

local function derivedId(binding)
  local mods = binding.mods
  local key = binding.key
  if type(key) ~= "string" or key == "" then return nil end
  if type(mods) ~= "table" then
    mods = DEFAULT_MODS
  end

  local parts = {}
  for _, mod in ipairs(mods) do
    if type(mod) == "string" and mod ~= "" then
      table.insert(parts, string.lower(mod))
    end
  end
  table.insert(parts, string.lower(key))
  return "app-hotkey-blocker." .. table.concat(parts, "+")
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
    local id = derivedId(hotkey)
    if id then hotkey.id = id end
  end

  return hotkey
end

function M.start(blockers, registry)
  blockers = blockers or {}

  local entries = {}
  for _, config in ipairs(blockers) do
    if config.enabled ~= false then
      table.insert(entries, {
        appName = config.appName,
        hotkey = registry:create(M.desiredHotkey(config), function() end),
      })
    end
  end

  if #entries == 0 then return end

  local function sync(app)
    local name = app and app:name()
    for _, entry in ipairs(entries) do
      if name == entry.appName then
        entry.hotkey:enable()
      else
        entry.hotkey:disable()
      end
    end
  end

  state.entries = entries
  state.watcher = hs.application.watcher.new(function(_, event, app)
    if event == hs.application.watcher.activated then
      sync(app)
    end
  end)

  state.watcher:start()
  sync(hs.application.frontmostApplication())
end

return M
