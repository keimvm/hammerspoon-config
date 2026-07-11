local M = {}

local ROOT_TABLE_FIELDS = {
  "hidRemap",
  "commandKeys",
  "controlLayer",
  "reload",
  "appSwitchers",
  "unicodeConverter",
}

local MOD_ALIASES = {
  command = "cmd",
  control = "ctrl",
  option = "alt",
}

local VALID_MODIFIERS = {
  alt = true,
  cmd = true,
  ctrl = true,
  fn = true,
  shift = true,
}

local MOD_ORDER = {
  ctrl = 1,
  alt = 2,
  shift = 3,
  cmd = 4,
  fn = 5,
}

local VALID_HID_KEYS = {
  caps_lock = true,
  left_command = true,
  left_control = true,
}

local function addError(errors, path, message)
  table.insert(errors, string.format("%s %s", path, message))
end

local function requireTable(errors, path, value)
  if type(value) == "table" then return true end
  addError(errors, path, "must be a table")
  return false
end

local function requireNonEmptyString(errors, path, value)
  if type(value) == "string" and value ~= "" then return true end
  addError(errors, path, "must be a non-empty string")
  return false
end

local function validateEnabled(errors, path, value)
  if value ~= nil and type(value) ~= "boolean" then
    addError(errors, path .. ".enabled", "must be a boolean")
  end
end

local function validateKnownKey(errors, path, value)
  if type(value) ~= "string" or value == "" then return end
  local keycodes = hs and hs.keycodes and hs.keycodes.map or {}
  if keycodes[value] == nil and keycodes[string.lower(value)] == nil then
    addError(errors, path, "is unknown: " .. value)
  end
end

local function validateModifiers(errors, path, mods)
  if type(mods) ~= "table" then return end

  for index, mod in ipairs(mods) do
    local itemPath = string.format("%s[%d]", path, index)
    if requireNonEmptyString(errors, itemPath, mod) then
      local normalized = MOD_ALIASES[string.lower(mod)] or string.lower(mod)
      if not VALID_MODIFIERS[normalized] then
        addError(errors, itemPath, "is unknown: " .. mod)
      end
    end
  end
end

local function validateKnownModifier(errors, path, value)
  if not requireNonEmptyString(errors, path, value) then return end
  local normalized = MOD_ALIASES[string.lower(value)] or string.lower(value)
  if not VALID_MODIFIERS[normalized] then
    addError(errors, path, "is unknown: " .. value)
  end
end

local function validateKnownHidKey(errors, path, value)
  if not requireNonEmptyString(errors, path, value) then return end
  if not VALID_HID_KEYS[value] then
    addError(errors, path, "is unknown: " .. value)
  end
end

local function validateHotkey(errors, path, hotkey, hotkeys)
  if not requireTable(errors, path, hotkey) then return end

  table.insert(hotkeys, { path = path, value = hotkey })

  validateEnabled(errors, path, hotkey.enabled)
  requireNonEmptyString(errors, path .. ".id", hotkey.id)
  requireNonEmptyString(errors, path .. ".description", hotkey.description)
  if requireTable(errors, path .. ".mods", hotkey.mods) then
    validateModifiers(errors, path .. ".mods", hotkey.mods)
  end
  if requireNonEmptyString(errors, path .. ".key", hotkey.key) then
    validateKnownKey(errors, path .. ".key", hotkey.key)
  end
end

local function validateRootFields(errors, config)
  local valid = {}
  for _, field in ipairs(ROOT_TABLE_FIELDS) do
    valid[field] = requireTable(errors, "config." .. field, config[field])
  end
  return valid
end

local function validateFeatureShapes(errors, config, valid, hotkeys)
  if valid.hidRemap then
    validateEnabled(errors, "config.hidRemap", config.hidRemap.enabled)
    if requireTable(errors, "config.hidRemap.mappings", config.hidRemap.mappings) then
      for index, mapping in ipairs(config.hidRemap.mappings) do
        local path = string.format("config.hidRemap.mappings[%d]", index)
        if requireTable(errors, path, mapping) then
          validateKnownHidKey(errors, path .. ".from", mapping.from)
          validateKnownHidKey(errors, path .. ".to", mapping.to)
        end
      end
    end
  end

  if valid.commandKeys then
    validateEnabled(errors, "config.commandKeys", config.commandKeys.enabled)
    if requireTable(errors, "config.commandKeys.bindings", config.commandKeys.bindings) then
      for index, binding in ipairs(config.commandKeys.bindings) do
        local path = string.format("config.commandKeys.bindings[%d]", index)
        if requireTable(errors, path, binding) then
          if requireNonEmptyString(errors, path .. ".commandKey", binding.commandKey) then
            validateKnownKey(errors, path .. ".commandKey", binding.commandKey)
          end
          if type(binding.outputKeyCode) ~= "number" then
            addError(errors, path .. ".outputKeyCode", "must be a number")
          end
        end
      end
    end
  end

  if valid.controlLayer then
    if requireTable(errors, "config.controlLayer.arrows", config.controlLayer.arrows) then
      for index, binding in ipairs(config.controlLayer.arrows) do
        local path = string.format("config.controlLayer.arrows[%d]", index)
        validateHotkey(errors, path, binding, hotkeys)
        if type(binding) == "table"
          and requireNonEmptyString(errors, path .. ".arrow", binding.arrow)
        then
          validateKnownKey(errors, path .. ".arrow", binding.arrow)
        end
      end
    end
    if config.controlLayer.sentinelCommand ~= nil then
      local path = "config.controlLayer.sentinelCommand"
      local sentinel = config.controlLayer.sentinelCommand
      if requireTable(errors, path, sentinel) then
        validateEnabled(errors, path, sentinel.enabled)
        if requireNonEmptyString(errors, path .. ".sentinelKey", sentinel.sentinelKey) then
          validateKnownKey(errors, path .. ".sentinelKey", sentinel.sentinelKey)
        end
        validateKnownModifier(errors, path .. ".virtualModifier", sentinel.virtualModifier)
        if sentinel.syntheticEventSourceUserData ~= nil
          and type(sentinel.syntheticEventSourceUserData) ~= "number"
        then
          addError(errors, path .. ".syntheticEventSourceUserData", "must be a number")
        end
      end
    end
  end

  if valid.reload then
    validateHotkey(errors, "config.reload", config.reload, hotkeys)
  end

  if valid.appSwitchers then
    for index, binding in ipairs(config.appSwitchers) do
      local path = string.format("config.appSwitchers[%d]", index)
      validateHotkey(errors, path, binding, hotkeys)
      if type(binding) == "table" then
        requireNonEmptyString(errors, path .. ".appName", binding.appName)
        if binding.dirToOpen ~= nil and type(binding.dirToOpen) ~= "string" then
          addError(errors, path .. ".dirToOpen", "must be a string")
        end
      end
    end
  end

  if valid.unicodeConverter then
    validateHotkey(errors, "config.unicodeConverter", config.unicodeConverter, hotkeys)
  end
end

local function hotkeyIdentity(hotkey)
  if type(hotkey.mods) ~= "table" or type(hotkey.key) ~= "string" or hotkey.key == "" then
    return nil
  end

  local mods = {}
  for _, mod in ipairs(hotkey.mods) do
    if type(mod) ~= "string" or mod == "" then return nil end
    local normalized = MOD_ALIASES[string.lower(mod)] or string.lower(mod)
    table.insert(mods, normalized)
  end
  table.sort(mods, function(a, b)
    local aOrder = MOD_ORDER[a] or 100
    local bOrder = MOD_ORDER[b] or 100
    if aOrder == bOrder then return a < b end
    return aOrder < bOrder
  end)
  table.insert(mods, string.lower(hotkey.key))
  return table.concat(mods, "+")
end

local function validateHotkeyDuplicates(errors, hotkeys)
  local ids = {}
  local identities = {}

  for _, entry in ipairs(hotkeys) do
    local hotkey = entry.value
    if type(hotkey.id) == "string" and hotkey.id ~= "" then
      if ids[hotkey.id] then
        addError(
          errors,
          entry.path .. ".id",
          string.format("duplicates %s.id: %s", ids[hotkey.id], hotkey.id)
        )
      else
        ids[hotkey.id] = entry.path
      end
    end

    if hotkey.enabled ~= false then
      local identity = hotkeyIdentity(hotkey)
      if identity then
        if identities[identity] then
          addError(
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
end

function M.validate(config)
  local errors = {}

  if type(config) ~= "table" then
    addError(errors, "config", "must be a table")
  else
    local valid = validateRootFields(errors, config)
    local hotkeys = {}
    validateFeatureShapes(errors, config, valid, hotkeys)
    validateHotkeyDuplicates(errors, hotkeys)
  end

  if #errors > 0 then
    error("invalid Hammerspoon config:\n- " .. table.concat(errors, "\n- "), 2)
  end

  return true
end

return M
