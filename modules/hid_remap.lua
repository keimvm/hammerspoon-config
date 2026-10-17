local M = {}

local log = hs.logger.new("hid_remap", "warning")
local runningTasks = {}

local hidUsage = {
  caps_lock = 0x700000039,
  left_control = 0x7000000E0,
  left_command = 0x7000000E3,
  right_command = 0x7000000E7,
  -- JIS キーボードの英数キー (LANG2) とかなキー (LANG1)。
  eisu = 0x700000091,
  kana = 0x700000090,
}

local function buildMapping(mapping)
  local from = hidUsage[mapping.from]
  local to = hidUsage[mapping.to]

  if not from then error("unknown HID source key: " .. tostring(mapping.from)) end
  if not to then error("unknown HID destination key: " .. tostring(mapping.to)) end

  return {
    HIDKeyboardModifierMappingSrc = from,
    HIDKeyboardModifierMappingDst = to,
  }
end

function M.supportsKey(key)
  return hidUsage[key] ~= nil
end

function M.apply(config)
  if not config then return end

  local userKeyMapping = {}
  if config.enabled ~= false then
    for _, mapping in ipairs(config.mappings or {}) do
      table.insert(userKeyMapping, buildMapping(mapping))
    end
  end

  local payload = hs.json.encode({ UserKeyMapping = userKeyMapping })
  local task
  task = hs.task.new("/usr/bin/hidutil", function(exitCode, _, stdErr)
    runningTasks[task] = nil
    if exitCode == 0 then return end

    log.wf("hidutil failed: %s", stdErr or ("exit " .. tostring(exitCode)))
  end, { "property", "--set", payload })

  if not task then
    log.w("failed to create hidutil task")
    return
  end

  runningTasks[task] = true
  if not task:start() then
    runningTasks[task] = nil
    log.w("failed to start hidutil task")
  end
end

return M
