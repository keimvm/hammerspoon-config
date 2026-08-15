local appHotkeyBlocker = require("modules.app_hotkey_blocker")
local appInputSource = require("modules.app_input_source")
local appSwitcher = require("modules.app_switcher")
local controlLayer = require("modules.control_layer")
local hidRemap = require("modules.hid_remap")
local hotkeyRegistry = require("modules.hotkey_registry")
local timer = require("modules.timer")
local unicodeConverter = require("modules.unicode_converter")

local M = {}

local ROOT_TABLE_FIELDS = {
  "hidRemap",
  "commandKeys",
  "controlLayer",
  "appHotkeyBlockers",
  "appSwitchers",
  "appInputSources",
  "timer",
  "unicodeConverter",
}

local function addError(errors, path, message)
  table.insert(errors, string.format("%s %s", path, message))
end

local function requireTable(errors, path, value)
  if type(value) == "table" then return true end
  addError(errors, path, "must be a table")
  return false
end

local function requireList(errors, path, value)
  if not requireTable(errors, path, value) then return false end

  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      addError(errors, path, "must be a list")
      return false
    end
    count = count + 1
  end

  for index = 1, count do
    if value[index] == nil then
      addError(errors, path, "must be a list")
      return false
    end
  end

  return true
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
  if not hotkeyRegistry.isKnownKey(value) then
    addError(errors, path, "is unknown: " .. value)
  end
end

local function validateKnownModifier(errors, path, value)
  if not requireNonEmptyString(errors, path, value) then return end
  if not hotkeyRegistry.isKnownModifier(value) then
    addError(errors, path, "is unknown: " .. value)
  end
end

local function validateKnownHidKey(errors, path, value)
  if not requireNonEmptyString(errors, path, value) then return end
  if not hidRemap.supportsKey(value) then
    addError(errors, path, "is unknown: " .. value)
  end
end

local function validateKnownSource(errors, path, value)
  if not requireNonEmptyString(errors, path, value) then return end
  if not appInputSource.supportsSource(value) then
    addError(errors, path, "is unknown: " .. value)
  end
end

local function validateKeyStroke(errors, path, value)
  if type(value) == "string" then
    if requireNonEmptyString(errors, path, value) then
      validateKnownKey(errors, path, value)
    end
    return
  end

  if type(value) ~= "table" then
    addError(errors, path, "must be a key name or chord table")
    return
  end

  if value.mods ~= nil then
    if type(value.mods) ~= "table" then
      addError(errors, path .. ".mods", "must be a table")
    else
      for index, mod in ipairs(value.mods) do
        validateKnownModifier(errors, path .. ".mods[" .. index .. "]", mod)
      end
    end
  end

  if requireNonEmptyString(errors, path .. ".key", value.key) then
    validateKnownKey(errors, path .. ".key", value.key)
  end
end

local function collectHotkey(path, hotkey, hotkeys)
  table.insert(hotkeys, { path = path, value = hotkey })
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
    if requireTable(errors, "config.controlLayer.bindings", config.controlLayer.bindings) then
      for index, binding in ipairs(config.controlLayer.bindings) do
        local path = string.format("config.controlLayer.bindings[%d]", index)
        collectHotkey(path, controlLayer.desiredHotkey(binding), hotkeys)
        if type(binding) == "table" then
          if binding.repeatable ~= nil and type(binding.repeatable) ~= "boolean" then
            addError(errors, path .. ".repeatable", "must be a boolean")
          end
          validateKeyStroke(errors, path .. ".to", binding.to)
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

  if valid.appHotkeyBlockers then
    if config.appHotkeyBlockers.appName ~= nil then
      addError(errors, "config.appHotkeyBlockers", "must be a list")
    else
      for index, binding in ipairs(config.appHotkeyBlockers) do
        local path = string.format("config.appHotkeyBlockers[%d]", index)
        collectHotkey(path, appHotkeyBlocker.desiredHotkey(binding), hotkeys)
        if type(binding) == "table" then
          requireNonEmptyString(errors, path .. ".appName", binding.appName)
        end
      end
    end
  end

  if valid.appSwitchers then
    for index, binding in ipairs(config.appSwitchers) do
      local path = string.format("config.appSwitchers[%d]", index)
      collectHotkey(path, appSwitcher.desiredHotkey(binding), hotkeys)
      if type(binding) == "table" then
        requireNonEmptyString(errors, path .. ".appName", binding.appName)
      end
    end
  end

  if valid.appInputSources then
    validateEnabled(errors, "config.appInputSources", config.appInputSources.enabled)
    if requireList(errors, "config.appInputSources.bindings", config.appInputSources.bindings) then
      local appNames = {}
      for index, binding in ipairs(config.appInputSources.bindings) do
        local path = string.format("config.appInputSources.bindings[%d]", index)
        if requireTable(errors, path, binding) then
          validateEnabled(errors, path, binding.enabled)
          if requireNonEmptyString(errors, path .. ".appName", binding.appName) then
            if appNames[binding.appName] then
              addError(
                errors,
                path .. ".appName",
                string.format(
                  "duplicates %s.appName: %s",
                  appNames[binding.appName],
                  binding.appName
                )
              )
            else
              appNames[binding.appName] = path
            end
          end
          validateKnownSource(errors, path .. ".source", binding.source)
        end
      end
    end
  end

  if valid.timer then
    collectHotkey(
      "config.timer",
      timer.desiredHotkey(config.timer),
      hotkeys
    )
  end

  if valid.unicodeConverter then
    collectHotkey(
      "config.unicodeConverter",
      unicodeConverter.desiredHotkey(config.unicodeConverter),
      hotkeys
    )
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
    for _, message in ipairs(hotkeyRegistry.validationErrors(hotkeys)) do
      table.insert(errors, message)
    end
  end

  if #errors > 0 then
    error("invalid Hammerspoon config:\n- " .. table.concat(errors, "\n- "), 2)
  end

  return true
end

return M
