-- 同時に1本だけの one-shot countdown。残り時間はメニューバーに表示する。
local ui = require("modules.ui")

local M = {}

local MIN_MINUTES = 1
local MAX_MINUTES = 180
local MIN_SECONDS = 1
local MAX_SECONDS = 10800
local COMPLETION_SOUND_NAME = "Tink"
local COMPLETION_SOUND_VOLUME = 0.25

local chooser = nil
local chooserVisible = false
local unitToggleHotkey = nil
local unit = "minutes"
local running = nil
local completionSound = nil

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

-- 入力欄の s / m を単位の切り替えとして取り除き、残りを数値として読む。
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
    else
      if not char:match("%d") then hasUnsupportedCharacter = true end
      table.insert(cleanedChars, char)
    end
  end

  local cleaned = table.concat(cleanedChars)
  local parsed = { cleaned = cleaned, unit = nextUnit }

  if hasUnsupportedCharacter then
    parsed.errorText = "数字と s / m だけ入力してください"
    return parsed
  end
  if cleaned == "" then return parsed end

  local amount = tonumber(cleaned)
  local min, max, seconds, suffix = MIN_MINUTES, MAX_MINUTES, 60, "分"
  if nextUnit == "seconds" then
    min, max, seconds, suffix = MIN_SECONDS, MAX_SECONDS, 1, "秒"
  end

  if amount and amount % 1 == 0 and amount >= min and amount <= max then
    parsed.valid = true
    parsed.amount = amount
    parsed.seconds = amount * seconds
    parsed.choiceText = string.format("%d%sで開始", amount, suffix)
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
  return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local function playCompletionSound()
  if not completionSound then
    completionSound = hs.sound.getByName(COMPLETION_SOUND_NAME)
    if completionSound then completionSound:volume(COMPLETION_SOUND_VOLUME) end
  end
  if completionSound then completionSound:play() end
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
  ui.sticky(text)
  playCompletionSound()
end

local function remainingSeconds()
  return running.endsAt - hs.timer.secondsSinceEpoch()
end

local function tick()
  if not running then return end
  local remaining = remainingSeconds()
  if remaining <= 0 then
    complete()
    return
  end
  if running.menubar then running.menubar:setTitle(formatRemaining(remaining)) end
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
      return { { title = "キャンセル", fn = stopRunning } }
    end)
  end

  running.timer = hs.timer.doEvery(1, tick)
end

local function applyQuery(query)
  local parsed = parseQuery(query, unit)
  unit = parsed.unit
  if parsed.cleaned ~= query then chooser:query(parsed.cleaned) end
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

  chooser = ui.chooser(function(choice)
    chooserVisible = false
    disableUnitToggle()
    if not choice or not choice.seconds then return end
    startCountdown(choice)
  end)

  -- Tab は入力画面を開いている間だけ、数値を保ったまま単位を切り替える。
  unitToggleHotkey = hs.hotkey.new({}, "tab", function()
    if not chooserVisible then return end
    unit = unit == "minutes" and "seconds" or "minutes"
    applyQuery(chooser:query() or "")
  end)

  chooser:queryChangedCallback(function(query)
    applyQuery(query or "")
  end)

  return chooser
end

-- 実行中なら残り時間（例: 12:34）を返す。
function M.remainingText()
  if not running then return nil end
  return formatRemaining(math.max(remainingSeconds(), 0))
end

function M.cancel()
  stopRunning()
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
