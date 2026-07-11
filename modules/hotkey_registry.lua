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

local VALID_MODIFIERS = {
  alt = true,
  cmd = true,
  ctrl = true,
  fn = true,
  shift = true,
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

local function addDefinitionError(errors, path, message)
  table.insert(errors, string.format("%s %s", path, message))
end

local function knownKey(key)
  local keycodes = hs and hs.keycodes and hs.keycodes.map or {}
  return keycodes[key] ~= nil or keycodes[string.lower(key)] ~= nil
end

function M.isKnownModifier(mod)
  if type(mod) ~= "string" or mod == "" then return false end
  return VALID_MODIFIERS[normalizeMod(mod)] == true
end

local function validateDefinition(errors, entry)
  local path = entry.path
  local hotkey = entry.value
  if type(hotkey) ~= "table" then
    addDefinitionError(errors, path, "must be a table")
    return false
  end

  if hotkey.enabled ~= nil and type(hotkey.enabled) ~= "boolean" then
    addDefinitionError(errors, path .. ".enabled", "must be a boolean")
  end
  if type(hotkey.id) ~= "string" or hotkey.id == "" then
    addDefinitionError(errors, path .. ".id", "must be a non-empty string")
  end
  if type(hotkey.description) ~= "string" or hotkey.description == "" then
    addDefinitionError(errors, path .. ".description", "must be a non-empty string")
  end

  local identityValid = true
  if type(hotkey.mods) ~= "table" then
    addDefinitionError(errors, path .. ".mods", "must be a table")
    identityValid = false
  else
    for index, mod in ipairs(hotkey.mods) do
      local itemPath = string.format("%s.mods[%d]", path, index)
      if type(mod) ~= "string" or mod == "" then
        addDefinitionError(errors, itemPath, "must be a non-empty string")
        identityValid = false
      else
        if not M.isKnownModifier(mod) then
          addDefinitionError(errors, itemPath, "is unknown: " .. mod)
          identityValid = false
        end
      end
    end
  end

  if type(hotkey.key) ~= "string" or hotkey.key == "" then
    addDefinitionError(errors, path .. ".key", "must be a non-empty string")
    identityValid = false
  elseif not knownKey(hotkey.key) then
    addDefinitionError(errors, path .. ".key", "is unknown: " .. hotkey.key)
    identityValid = false
  end

  return identityValid
end

function M.validationErrors(entries)
  local errors = {}
  local ids = {}
  local identities = {}

  for _, entry in ipairs(entries) do
    local identityValid = validateDefinition(errors, entry)
    local hotkey = entry.value
    if type(hotkey) == "table" then
      if type(hotkey.id) == "string" and hotkey.id ~= "" then
        if ids[hotkey.id] then
          addDefinitionError(
            errors,
            entry.path .. ".id",
            string.format("duplicates %s.id: %s", ids[hotkey.id], hotkey.id)
          )
        else
          ids[hotkey.id] = entry.path
        end
      end

      if identityValid and hotkey.enabled ~= false then
        local mods = normalizeMods(hotkey.mods, hotkey.id)
        local key = normalizeKey(hotkey.key, hotkey.id)
        local identity = formatHotkey(mods, key)
        if identities[identity] then
          addDefinitionError(
            errors,
            entry.path,
            string.format("duplicates Hotkey Identity %s from %s", identity, identities[identity])
          )
        else
          identities[identity] = entry.path
        end
      end
    end
  end

  return errors
end

function M.new()
  return setmetatable({ hotkeys = {} }, Registry)
end

local function requireOptionalFunction(value, fieldName, hotkeyId)
  if value ~= nil and type(value) ~= "function" then
    error(string.format("hotkey %s %s must be a function", tostring(hotkeyId or "<unknown>"), fieldName), 3)
  end
end

function Registry:bind(hotkey, pressedFn, releasedFn, repeatFn)
  local mods, key = validateMetadata(hotkey)
  if not enabled(hotkey) then return nil end

  if type(pressedFn) ~= "function" then
    error(string.format("hotkey %s pressedFn must be a function", hotkey.id), 2)
  end
  requireOptionalFunction(releasedFn, "releasedFn", hotkey.id)
  requireOptionalFunction(repeatFn, "repeatFn", hotkey.id)

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

  return hs.hotkey.bind(hotkey.mods or {}, hotkey.key, pressedFn, releasedFn, repeatFn)
end

return M
