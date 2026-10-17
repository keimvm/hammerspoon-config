-- 物理キーの変換（Input Remap）。hidutil の UserKeyMapping を設定の内容で置き換える。
local report = require("modules.report")
local ui = require("modules.ui")

local M = {}

-- USB HID Keyboard/Keypad page（0x07）の usage ID。
local HID_USAGE = {
  caps_lock = 0x39,
  escape = 0x29,
  tab = 0x2B,
  space = 0x2C,
  ["return"] = 0x28,
  delete = 0x2A,
  forwarddelete = 0x4C,
  left_control = 0xE0,
  left_shift = 0xE1,
  left_option = 0xE2,
  left_command = 0xE3,
  right_control = 0xE4,
  right_shift = 0xE5,
  right_option = 0xE6,
  right_command = 0xE7,
  -- JIS キーボードの英数キー (LANG2) とかなキー (LANG1)。
  eisu = 0x91,
  kana = 0x90,
}

local runningTasks = {}
local log

local function keyNames()
  local names = {}
  for name in pairs(HID_USAGE) do table.insert(names, name) end
  table.sort(names)
  return names
end

local function usage(name)
  return 0x700000000 + HID_USAGE[name]
end

local function setUserKeyMapping(mappings)
  log = log or hs.logger.new("remap", "warning")
  local payload = hs.json.encode({ UserKeyMapping = mappings })
  local task
  task = hs.task.new("/usr/bin/hidutil", function(exitCode, _, stdErr)
    runningTasks[task] = nil
    if exitCode ~= 0 then log.wf("hidutil failed: %s", stdErr or ("exit " .. tostring(exitCode))) end
  end, { "property", "--set", payload })

  if not task then
    log.w("failed to create hidutil task")
    return false
  end

  runningTasks[task] = true
  if not task:start() then
    runningTasks[task] = nil
    log.w("failed to start hidutil task")
    return false
  end
  return true
end

function M.validate(remap, at)
  if remap == nil then return end
  if not at:table(remap) then return end

  local sources = {}
  for from in pairs(remap) do table.insert(sources, from) end
  table.sort(sources, function(a, b) return tostring(a) < tostring(b) end)

  local names = keyNames()
  for _, from in ipairs(sources) do
    local to = remap[from]
    if type(from) ~= "string" then
      at:add("物理キー = \"変換後のキー\" の形で書いてください（例: caps_lock = \"left_control\"）")
    else
      local itemAt = at:at(from)
      if not HID_USAGE[from] then
        itemAt:add("変換できないキーです" .. report.hint(from, names))
      end
      if type(to) ~= "string" or not HID_USAGE[to] then
        itemAt:add("変換先のキーが不明です: " .. tostring(to)
          .. (type(to) == "string" and report.hint(to, names) or ""))
      end
    end
  end
end

-- 設定がなければ何もしない。空のテーブルなら変換を解除する。
function M.apply(remap)
  if remap == nil then return end

  local sources = {}
  for from in pairs(remap) do table.insert(sources, from) end
  table.sort(sources)

  local mappings = {}
  for _, from in ipairs(sources) do
    table.insert(mappings, {
      HIDKeyboardModifierMappingSrc = usage(from),
      HIDKeyboardModifierMappingDst = usage(remap[from]),
    })
  end
  setUserKeyMapping(mappings)
end

-- 変換を一時的に解除する。再読み込みすると設定の変換に戻る。
function M.clear()
  if setUserKeyMapping({}) then
    ui.toast("キー変換を解除しました（再読み込みで戻ります）", 2)
  end
end

function M.keyNames()
  return keyNames()
end

return M
