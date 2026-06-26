local M = {}

local MAX_CLIPBOARD_BYTES = 1024
local MAX_CLIPBOARD_LINES = 10
local CHOOSER_WIDTH = 30
local CHOOSER_ROWS = 3
local CHOOSER_PLACEHOLDER = "Character or code point"
local CHOOSER_FG = { red = 0.96, green = 0.97, blue = 0.98, alpha = 1 }
local CHOOSER_SUBTEXT = { red = 0.66, green = 0.70, blue = 0.76, alpha = 1 }

local chooser = nil
local chooserVisible = false

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function countLines(s)
  local _, count = s:gsub("\n", "")
  return count + 1
end

local function safeClipboardText()
  local text = hs.pasteboard.getContents()
  if type(text) ~= "string" then return "" end
  if #text > MAX_CLIPBOARD_BYTES then return "" end
  if countLines(text) > MAX_CLIPBOARD_LINES then return "" end
  return text
end

local function codePointLabel(cp)
  local hex = string.upper(string.format("%X", cp))
  if #hex < 4 then
    hex = string.rep("0", 4 - #hex) .. hex
  end
  return "U+" .. hex
end

local function isValidCodePoint(cp)
  return cp >= 0 and cp <= 0x10FFFF and not (cp >= 0xD800 and cp <= 0xDFFF)
end

local function parseCodeToken(token)
  local hex = token:match("^[Uu]%+([0-9A-Fa-f]+)$")
  if hex then return tonumber(hex, 16), "explicit" end

  hex = token:match("^0[xX]([0-9A-Fa-f]+)$")
  if hex then return tonumber(hex, 16), "explicit" end

  if token:match("^[0-9A-Fa-f]+$") and token:match("%d") then
    return tonumber(token, 16), "bare"
  end

  return nil, nil
end

local function splitCodeTokens(input)
  local tokens = {}
  for token in input:gmatch("[^,%s]+") do
    table.insert(tokens, token)
  end
  return tokens
end

local function looksLikeCodePointInput(input)
  local tokens = splitCodeTokens(input)
  if #tokens == 0 then return false, tokens end

  for _, token in ipairs(tokens) do
    if not parseCodeToken(token) then
      return false, tokens
    end
  end

  return true, tokens
end

local function codePointsToString(input)
  local _, tokens = looksLikeCodePointInput(input)
  local chars = {}

  for _, token in ipairs(tokens) do
    local cp = parseCodeToken(token)
    if not cp then
      return nil, "Invalid code point: " .. token
    end

    if cp >= 0xD800 and cp <= 0xDFFF then
      return nil, "Invalid surrogate code point: " .. codePointLabel(cp)
    end

    if not isValidCodePoint(cp) then
      return nil, "Invalid code point: " .. codePointLabel(cp)
    end

    table.insert(chars, utf8.char(cp))
  end

  return table.concat(chars), string.format("%d code point%s", #tokens, #tokens == 1 and "" or "s")
end

local function stringToCodePoints(input)
  local labels = {}
  local ok, err = pcall(function()
    for _, cp in utf8.codes(input) do
      table.insert(labels, codePointLabel(cp))
    end
  end)

  if not ok then
    return nil, "Invalid UTF-8 input: " .. tostring(err)
  end

  return table.concat(labels, " "), string.format("%d character%s", #labels, #labels == 1 and "" or "s")
end

local function displayText(text)
  text = text:gsub("\n", "\\n")
  if #text <= 80 then return text end
  return text:sub(1, 77) .. "..."
end

local function disabledChoice(text, subText)
  return {
    text = text,
    subText = subText,
    disabled = true,
    valid = false,
  }
end

local function buildChoices(query)
  local input = trim(query or "")

  if input == "" then
    return {
      disabledChoice("Unicode Converter", "Examples: あ  U+3042  0x1F600  3042"),
    }
  end

  local output, detail
  if looksLikeCodePointInput(input) then
    output, detail = codePointsToString(input)
    if not output then
      return {
        disabledChoice(detail, "No result"),
      }
    end
  else
    output, detail = stringToCodePoints(input)
    if not output then
      return {
        disabledChoice(detail, "No result"),
      }
    end
  end

  return {
    {
      text = output,
      subText = detail,
      copyText = output,
    },
  }
end

local function alertCopied(text)
  hs.alert.show("Copied: " .. displayText(text), 1)
end

local function ensureChooser()
  if chooser then return chooser end

  chooser = hs.chooser.new(function(choice)
    chooserVisible = false
    if not choice or choice.disabled or not choice.copyText then return end

    hs.pasteboard.setContents(choice.copyText)
    alertCopied(choice.copyText)
  end)

  chooser:width(CHOOSER_WIDTH)
  chooser:rows(CHOOSER_ROWS)
  chooser:bgDark(true)
  chooser:fgColor(CHOOSER_FG)
  chooser:subTextColor(CHOOSER_SUBTEXT)
  chooser:placeholderText(CHOOSER_PLACEHOLDER)
  chooser:searchSubText(true)
  chooser:choices(buildChoices(""))
  chooser:queryChangedCallback(function(query)
    chooser:choices(buildChoices(query))
  end)

  return chooser
end

function M.show()
  local c = ensureChooser()
  local initialText = safeClipboardText()

  c:choices(buildChoices(initialText))
  c:query(initialText)
  c:show()
  chooserVisible = true
end

function M.hide()
  if chooser then chooser:hide() end
  chooserVisible = false
end

function M.toggle()
  if chooserVisible then
    M.hide()
  else
    M.show()
  end
end

function M.bindHotkey(mods, key)
  hs.hotkey.bind(mods, key, M.toggle)
end

return M
