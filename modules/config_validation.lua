local appHotkeyBlocker = require("modules.app_hotkey_blocker")
local appSwitcher = require("modules.app_switcher")
local controlLayer = require("modules.control_layer")
local hidRemap = require("modules.hid_remap")
local hotkeyRegistry = require("modules.hotkey_registry")
local reload = require("modules.reload")
local unicodeConverter = require("modules.unicode_converter")

local M = {}

local ROOT_TABLE_FIELDS = {
  "hidRemap",
  "commandKeys",
  "controlLayer",
  "reload",
  "appHotkeyBlocker",
  "appSwitchers",
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
        if type(binding) == "table"
          and requireNonEmptyString(errors, path .. ".to", binding.to)
        then
          validateKnownKey(errors, path .. ".to", binding.to)
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
    collectHotkey("config.reload", reload.desiredHotkey(config.reload), hotkeys)
  end

  if valid.appHotkeyBlocker then
    collectHotkey(
      "config.appHotkeyBlocker",
      appHotkeyBlocker.desiredHotkey(config.appHotkeyBlocker),
      hotkeys
    )
    requireNonEmptyString(
      errors,
      "config.appHotkeyBlocker.appName",
      config.appHotkeyBlocker.appName
    )
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
