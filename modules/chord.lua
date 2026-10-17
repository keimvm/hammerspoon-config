-- "ctrl+shift+u" のような Chord 表記の解析と表示。
local report = require("modules.report")

local M = {}

local MODIFIER_ALIASES = {
  ctrl = "ctrl", control = "ctrl", ["⌃"] = "ctrl",
  alt = "alt", option = "alt", opt = "alt", ["⌥"] = "alt",
  shift = "shift", ["⇧"] = "shift",
  cmd = "cmd", command = "cmd", ["⌘"] = "cmd",
  fn = "fn",
}
local MODIFIER_ORDER = { ctrl = 1, alt = 2, shift = 3, cmd = 4, fn = 5 }
local MODIFIER_SYMBOLS = { ctrl = "⌃", alt = "⌥", shift = "⇧", cmd = "⌘", fn = "fn " }
local KEY_SYMBOLS = {
  up = "↑", down = "↓", left = "←", right = "→",
  delete = "⌫", forwarddelete = "⌦", ["return"] = "↩", escape = "⎋", tab = "⇥",
  space = "Space", home = "↖", ["end"] = "↘", pageup = "⇞", pagedown = "⇟",
}

local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function modifierNames()
  local names = {}
  for name in pairs(MODIFIER_ALIASES) do
    if name:match("^%a+$") then table.insert(names, name) end
  end
  table.sort(names)
  return names
end

local function keyNames()
  local names = {}
  for name in pairs(hs.keycodes.map) do
    if type(name) == "string" then table.insert(names, name) end
  end
  table.sort(names)
  return names
end

-- hs.keycodes.map にある名前へ正規化する。見つからなければ nil。
function M.keyName(key)
  if type(key) ~= "string" or key == "" then return nil end
  local map = hs.keycodes.map
  local lowered = string.lower(key)
  if map[lowered] ~= nil then return lowered end
  if map[key] ~= nil then return key end
  return nil
end

-- 解析結果は { mods = { "ctrl", "shift" }, key = "u", id = "ctrl+shift+u" }。
-- options.allowFn が真のときだけ fn を修飾キーとして受け付ける。
function M.parse(text, options)
  options = options or {}
  if type(text) ~= "string" or trim(text) == "" then
    return nil, "\"ctrl+i\" のような文字列で指定してください"
  end

  local parts = {}
  for part in (text .. "+"):gmatch("(.-)%+") do
    table.insert(parts, trim(part))
  end
  local rawKey = table.remove(parts)
  -- pad+ のように末尾の + がキー名の一部なら、分割前の形へ戻す。
  if rawKey == "" and #parts > 0 and M.keyName(parts[#parts] .. "+") then
    rawKey = table.remove(parts) .. "+"
  end
  if rawKey == nil or rawKey == "" then
    return nil, "キーがありません: " .. text
  end

  local mods, seen = {}, {}
  for _, part in ipairs(parts) do
    local name = MODIFIER_ALIASES[string.lower(part)]
    if not name then
      return nil, "不明な修飾キーです: " .. part .. report.hint(part, modifierNames())
    end
    if name == "fn" and not options.allowFn then
      return nil, "fn は Hotkey の修飾キーには使えません（send の送り先には使えます）"
    end
    if not seen[name] then
      seen[name] = true
      table.insert(mods, name)
    end
  end
  table.sort(mods, function(a, b) return MODIFIER_ORDER[a] < MODIFIER_ORDER[b] end)

  local key = M.keyName(rawKey)
  if not key then
    return nil, "不明なキーです: " .. rawKey .. report.hint(rawKey, keyNames())
  end

  local idParts = {}
  for _, mod in ipairs(mods) do table.insert(idParts, mod) end
  table.insert(idParts, key)
  return { mods = mods, key = key, id = table.concat(idParts, "+") }
end

-- macOS のメニューと同じ記号で表示する（例: ⌃⇧U、F5、↑）。
function M.display(chord)
  local parts = {}
  for _, mod in ipairs(chord.mods) do table.insert(parts, MODIFIER_SYMBOLS[mod]) end
  local key = chord.key
  if KEY_SYMBOLS[key] then
    key = KEY_SYMBOLS[key]
  elseif utf8.len(key) == 1 or key:match("^f%d+$") then
    key = string.upper(key)
  end
  table.insert(parts, key)
  return table.concat(parts)
end

return M
