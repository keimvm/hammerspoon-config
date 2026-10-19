-- Dock Toggle。最前面アプリの Dock アイコンをクリックすると、そのアプリを非表示にする。
-- 表示と再表示は Dock 本来の動きに任せ、ここでは隠すクリックだけを止める。
local M = {}

local DOCK_BUNDLE_ID = "com.apple.dock"
-- AX の各問い合わせの上限（秒）。クリックを長く待たせない。
local AX_TIMEOUT = 0.05
local MODIFIERS = { "cmd", "alt", "ctrl", "shift" }

local tap
local dockPid, dockElement
local swallowMouseUp = false

function M.validate(value, at)
  if value == nil or type(value) == "boolean" then return end
  at:add("true か false を指定してください")
end

-- タイムアウトは要素ごとの設定で、取得した子要素には引き継がれない。
local function boundedElement(element)
  if element then return element:setTimeout(AX_TIMEOUT) end
end

-- Dock の要素は Dock が再起動すると無効になるため、pid が変わったら取り直す。
local function getDockElement()
  local dock = hs.application.get(DOCK_BUNDLE_ID)
  if not dock then return nil end

  local pid = dock:pid()
  if pid ~= dockPid or not dockElement then
    dockPid = pid
    dockElement = boundedElement(hs.axuielement.applicationElement(dock))
  end
  return dockElement
end

local function hasModifier(event)
  local flags = event:getFlags()
  for _, name in ipairs(MODIFIERS) do
    if flags[name] then return true end
  end
  return false
end

-- AXURL は文字列か { url = ... } で返る。比較できるよう、末尾の / を除いたパスにする。
local function bundlePath(value)
  local url = type(value) == "table" and (value.filePath or value.url) or value
  if type(url) ~= "string" then return nil end

  local path = url:gsub("^file://", ""):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  return (path:gsub("/+$", ""))
end

-- Dock のアプリのアイコンがあれば、そのアプリのバンドルのパスを返す。
local function dockItemPathAt(point)
  local dock = getDockElement()
  if not dock then return nil end

  -- Dock のプロセスだけを調べる。カーソルの下のアプリが応答しなくても待たされない。
  local item = boundedElement(dock:elementAtPosition(point))
  if not item then return nil end
  if item:attributeValue("AXRole") ~= "AXDockItem" then return nil end
  if item:attributeValue("AXSubrole") ~= "AXApplicationDockItem" then return nil end
  return bundlePath(item:attributeValue("AXURL"))
end

-- 今のウィンドウが前面に出ていれば隠す。ウィンドウがない・最小化中は Dock 本来の動きに任せる。
local function appToHide(path)
  local app = hs.application.frontmostApplication()
  if not (app and path and bundlePath(app:path()) == path) then return nil end

  -- hs.application / hs.window の問い合わせでは、この要素の上限が使われない。
  local element = boundedElement(hs.axuielement.applicationElement(app))
  if not element then return nil end
  local win = boundedElement(element:attributeValue("AXFocusedWindow"))
  if not win or win:attributeValue("AXMinimized") ~= false then return nil end
  if not hs.window.filter.allowedWindowRoles[win:attributeValue("AXSubrole")] then return nil end
  return app
end

local function onMouseDown(event)
  swallowMouseUp = false
  if hasModifier(event) then return false end

  local app = appToHide(dockItemPathAt(event:location()))
  if not app then return false end

  -- 押下だけを止めると Dock が押されたままになるため、対応する離しも止める。
  swallowMouseUp = true
  hs.timer.doAfter(0, function() app:hide() end)
  return true
end

local function onMouseUp()
  if not swallowMouseUp then return false end
  swallowMouseUp = false
  return true
end

function M.start(enabled)
  if not enabled or tap then return end

  local types = hs.eventtap.event.types
  tap = hs.eventtap.new({ types.leftMouseDown, types.leftMouseUp }, function(event)
    if event:getType() == types.leftMouseDown then return onMouseDown(event) end
    return onMouseUp()
  end)
  tap:start()
end

return M
