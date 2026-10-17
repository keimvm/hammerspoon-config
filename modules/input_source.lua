-- 対象アプリが最前面になったとき、英数・かなキーを送って入力ソースを切り替える。
local frontmost = require("modules.frontmost")
local report = require("modules.report")

local M = {}

-- JIS キーボードの英数・かなキーのキーコード。
local SOURCE_KEY_CODES = { eisu = 0x66, kana = 0x68 }
local SOURCES = { "eisu", "kana" }

function M.validate(config, at)
  if config == nil then return end
  if not at:table(config) then return end

  local keys = {}
  for source in pairs(config) do table.insert(keys, source) end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

  local owners = {}
  for _, source in ipairs(keys) do
    local sourceAt = at:at(tostring(source))
    if not SOURCE_KEY_CODES[source] then
      sourceAt:add("eisu か kana を指定してください" .. report.hint(tostring(source), SOURCES))
    elseif sourceAt:list(config[source]) then
      for index, app in ipairs(config[source]) do
        local appAt = sourceAt:at(index)
        if appAt:string(app) then
          if owners[app] then
            appAt:add(app .. " は " .. owners[app] .. " にもあります")
          else
            owners[app] = appAt.path
          end
        end
      end
    end
  end
end

function M.start(config)
  local keyCodes = {}
  for source, apps in pairs(config or {}) do
    for _, app in ipairs(apps) do keyCodes[app] = SOURCE_KEY_CODES[source] end
  end
  if next(keyCodes) == nil then return end

  frontmost.subscribe(function(appName)
    local keyCode = appName and keyCodes[appName]
    if keyCode then hs.eventtap.keyStroke({}, keyCode, 0) end
  end)
end

return M
