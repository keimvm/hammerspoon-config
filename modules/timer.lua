local M = {}

local DEFAULT_MODS = { "ctrl" }
local DEFAULT_KEY = "`"
local MIN_MINUTES = 1
local MAX_MINUTES = 180
local MIN_SECONDS = 1
local MAX_SECONDS = 10800
local CHOOSER_WIDTH = 36
local CHOOSER_ROWS = 1
local CHOOSER_FG = { red = 0.96, green = 0.97, blue = 0.98, alpha = 1 }
local CHOOSER_SUBTEXT = { red = 0.66, green = 0.70, blue = 0.76, alpha = 1 }

local chooser = nil
local chooserVisible = false
local unitToggleHotkey = nil
local unit = "minutes"
local running = nil
local activeAlertIds = {}
local alertDismissTap = nil

local function copyList(list)
  local copy = {}
  for index, value in ipairs(list) do
    copy[index] = value
  end
  return copy
end

local function placeholderFor(currentUnit)
  if currentUnit == "seconds" then
    return string.format("秒（%d〜%d）", MIN_SECONDS, MAX_SECONDS)
  end
  return string.format("分（%d〜%d）", MIN_MINUTES, MAX_MINUTES)
end

local function rangeErrorFor(currentUnit)
  if currentUnit == "seconds" then
    return string.format("%d〜%d秒で入力してください", MIN_SECONDS, MAX_SECONDS)
  end
  return string.format("%d〜%d分で入力してください", MIN_MINUTES, MAX_MINUTES)
end

local function parseQuery(query, currentUnit)
  local nextUnit = currentUnit
  local cleanedChars = {}
  local hasUnsupportedCharacter = false
  for index = 1, #query do
    local char = query:sub(index, index)
    if char == "s" or char == "S" then
      nextUnit = "seconds"
    elseif char == "m" or char == "M" then
      nextUnit = "minutes"
    elseif char:match("%d") then
      table.insert(cleanedChars, char)
    else
      hasUnsupportedCharacter = true
      table.insert(cleanedChars, char)
    end
  end

  local cleaned = table.concat(cleanedChars)
  local amount = tonumber(cleaned)
  local parsed = {
    cleaned = cleaned,
    unit = nextUnit,
  }

  if hasUnsupportedCharacter then
    parsed.errorText = "数字と s / m だけ入力してください"
    return parsed
  end

  if cleaned == "" then return parsed end

  if type(amount) ~= "number" or amount % 1 ~= 0 then
    parsed.errorText = rangeErrorFor(nextUnit)
    return parsed
  end

  if nextUnit == "minutes" then
    if amount >= MIN_MINUTES and amount <= MAX_MINUTES then
      parsed.valid = true
      parsed.amount = amount
      parsed.seconds = amount * 60
      parsed.choiceText = string.format("%d分で開始", amount)
    else
      parsed.errorText = rangeErrorFor(nextUnit)
    end
  elseif amount >= MIN_SECONDS and amount <= MAX_SECONDS then
    parsed.valid = true
    parsed.amount = amount
    parsed.seconds = amount
    parsed.choiceText = string.format("%d秒で開始", amount)
  else
    parsed.errorText = rangeErrorFor(nextUnit)
  end

  return parsed
end

local function elapsedText(amount, elapsedUnit)
  if elapsedUnit == "seconds" then
    return string.format("%d秒が経過しました", amount)
  end
  return string.format("%d分が経過しました", amount)
end

local function formatRemaining(seconds)
  local whole = math.ceil(seconds)
  local mins = math.floor(whole / 60)
  local secs = whole % 60
  return string.format("%d:%02d", mins, secs)
end

local function dismissAlerts()
  for _, alertId in ipairs(activeAlertIds) do
    hs.alert.closeSpecific(alertId, 0)
  end
  activeAlertIds = {}

  if alertDismissTap then
    alertDismissTap:stop()
    alertDismissTap = nil
  end
end

local function announce(text)
  local alertId = hs.alert.show(text, "indefinite")
  if not alertId then return end

  table.insert(activeAlertIds, alertId)
  if alertDismissTap then return end

  local eventTypes = hs.eventtap.event.types
  alertDismissTap = hs.eventtap.new({
    eventTypes.leftMouseDown,
    eventTypes.rightMouseDown,
    eventTypes.otherMouseDown,
  }, function()
    dismissAlerts()
    return false
  end)
  alertDismissTap:start()
end

local function stopRunning()
  if not running then return end
  if running.timer then running.timer:stop() end
  if running.menubar then running.menubar:delete() end
  running = nil
end

local function complete()
  if not running then return end
  local text = elapsedText(running.amount, running.unit)
  stopRunning()
  announce(text)
end

local function tick()
  if not running then return end
  local remaining = running.endsAt - hs.timer.secondsSinceEpoch()
  if remaining <= 0 then
    complete()
    return
  end
  if running.menubar then
    running.menubar:setTitle(formatRemaining(remaining))
  end
end

local function startCountdown(choice)
  stopRunning()

  local menubar = hs.menubar.new()
  running = {
    amount = choice.amount,
    unit = choice.unit,
    endsAt = hs.timer.secondsSinceEpoch() + choice.seconds,
    menubar = menubar,
  }

  if menubar then
    menubar:setTitle(formatRemaining(choice.seconds))
    menubar:setMenu(function()
      return {
        {
          title = "キャンセル",
          fn = function()
            stopRunning()
          end,
        },
      }
    end)
  end

  running.timer = hs.timer.doEvery(1, tick)
end

local function applyQuery(query)
  local parsed = parseQuery(query, unit)
  unit = parsed.unit
  if parsed.cleaned ~= query then
    chooser:query(parsed.cleaned)
  end
  chooser:placeholderText(placeholderFor(unit))
  if parsed.valid then
    chooser:choices({
      {
        text = parsed.choiceText,
        amount = parsed.amount,
        unit = parsed.unit,
        seconds = parsed.seconds,
      },
    })
  elseif parsed.errorText then
    chooser:choices({ { text = parsed.errorText } })
  else
    chooser:choices({})
  end
end

local function disableUnitToggle()
  if unitToggleHotkey then unitToggleHotkey:disable() end
end

local function ensureChooser()
  if chooser then return chooser end

  chooser = hs.chooser.new(function(choice)
    chooserVisible = false
    disableUnitToggle()
    if not choice or not choice.seconds then return end
    startCountdown(choice)
  end)

  unitToggleHotkey = hs.hotkey.new({}, "tab", function()
    if not chooserVisible then return end
    unit = unit == "minutes" and "seconds" or "minutes"
    applyQuery(chooser:query() or "")
  end)

  chooser:width(CHOOSER_WIDTH)
  chooser:rows(CHOOSER_ROWS)
  chooser:bgDark(true)
  chooser:fgColor(CHOOSER_FG)
  chooser:subTextColor(CHOOSER_SUBTEXT)
  chooser:queryChangedCallback(function(query)
    applyQuery(query or "")
  end)

  return chooser
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

  if hotkey.key == nil then
    hotkey.key = DEFAULT_KEY
  end

  if type(hotkey.id) ~= "string" or hotkey.id == "" then
    hotkey.id = "timer.toggle"
  end

  return hotkey
end

function M.show()
  unit = "minutes"
  local c = ensureChooser()
  c:query("")
  applyQuery("")
  c:show()
  chooserVisible = true
  if unitToggleHotkey then unitToggleHotkey:enable() end
end

function M.hide()
  if chooser then chooser:hide() end
  chooserVisible = false
  disableUnitToggle()
end

function M.toggle()
  if chooserVisible then
    M.hide()
  else
    M.show()
  end
end

return M
