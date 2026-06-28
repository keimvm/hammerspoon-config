local M = {}

local Registry = {}
Registry.__index = Registry

local MOD_ALIASES = {
  command = "cmd",
  control = "ctrl",
  option = "alt",
}

local MOD_ORDER = {
  ctrl = 1,
  alt = 2,
  shift = 3,
  cmd = 4,
  fn = 5,
}

local function enabled(hotkey)
  return hotkey.enabled ~= false
end

local function requireNonEmptyString(value, fieldName, hotkeyId)
  if type(value) ~= "string" or value == "" then
    error(string.format("hotkey %s must have a non-empty %s", tostring(hotkeyId or "<unknown>"), fieldName), 3)
  end
end

local function normalizeMod(mod)
  local normalized = string.lower(tostring(mod))
  return MOD_ALIASES[normalized] or normalized
end

local function normalizeMods(mods, hotkeyId)
  if mods == nil then return {} end
  if type(mods) ~= "table" then
    error(string.format("hotkey %s mods must be a table", tostring(hotkeyId or "<unknown>")), 3)
  end

  local normalized = {}
  for _, mod in ipairs(mods) do
    requireNonEmptyString(mod, "mod", hotkeyId)
    table.insert(normalized, normalizeMod(mod))
  end

  table.sort(normalized, function(a, b)
    local aOrder = MOD_ORDER[a] or 100
    local bOrder = MOD_ORDER[b] or 100
    if aOrder == bOrder then return a < b end
    return aOrder < bOrder
  end)

  return normalized
end

local function normalizeKey(key, hotkeyId)
  requireNonEmptyString(key, "key", hotkeyId)
  return string.lower(key)
end

local function formatHotkey(mods, key)
  local parts = {}
  for _, mod in ipairs(mods) do table.insert(parts, mod) end
  table.insert(parts, key)
  return table.concat(parts, "+")
end

local function validateMetadata(hotkey)
  if type(hotkey) ~= "table" then
    error("hotkey metadata must be a table", 3)
  end

  requireNonEmptyString(hotkey.id, "id", hotkey.id)
  requireNonEmptyString(hotkey.description, "description", hotkey.id)

  local mods = normalizeMods(hotkey.mods, hotkey.id)
  local key = normalizeKey(hotkey.key, hotkey.id)
  return mods, key
end

function M.new()
  return setmetatable({ hotkeys = {} }, Registry)
end

function Registry:bind(hotkey, callback)
  local mods, key = validateMetadata(hotkey)
  if not enabled(hotkey) then return nil end

  if type(callback) ~= "function" then
    error(string.format("hotkey %s callback must be a function", hotkey.id), 2)
  end

  local identity = formatHotkey(mods, key)
  local existing = self.hotkeys[identity]
  if existing then
    error(
      string.format(
        "duplicate hotkey %s: %s (%s) conflicts with %s (%s)",
        identity,
        hotkey.id,
        hotkey.description,
        existing.id,
        existing.description
      ),
      2
    )
  end

  self.hotkeys[identity] = {
    id = hotkey.id,
    description = hotkey.description,
  }

  return hs.hotkey.bind(hotkey.mods or {}, hotkey.key, callback)
end

return M
