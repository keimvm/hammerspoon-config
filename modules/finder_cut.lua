-- Finder Cut。Finder で ⌘X → ⌘V の順に押すと、ファイルを移動する。
-- Finder はファイルの切り取りを持たないため、切り取りはコピーとして行う。
-- そのコピーが pasteboard に残っている間だけ、次の貼り付けを移動（⌥⌘V）に変える。
local M = {}

local FINDER_BUNDLE_ID = "com.apple.finder"
-- AX の各問い合わせの上限（秒）。キー入力を長く待たせない。
local AX_TIMEOUT = 0.05
-- 名前の変更中や検索欄では、文字の切り取り・貼り付けに任せる。
local TEXT_ROLES = { AXTextField = true, AXTextArea = true, AXComboBox = true }
-- コピーが pasteboard に反映されるのを待つ間隔（秒）と回数。
local COPY_POLL_SECONDS = 0.02
local COPY_POLL_LIMIT = 50

local cutChangeCount -- 切り取りでコピーした直後の pasteboard の changeCount。
local copyPoll

local function boundedElement(element)
  if element then return element:setTimeout(AX_TIMEOUT) end
end

-- Finder でファイルを選んでいれば Finder を、文字の編集中・AX の失敗時は nil を返す。
local function finderWithFiles(app)
  if not app or app:bundleID() ~= FINDER_BUNDLE_ID then return nil end
  local element = boundedElement(hs.axuielement.applicationElement(app))
  local focused = element and boundedElement(element:attributeValue("AXFocusedUIElement"))
  if not focused then return nil end
  local role = focused:attributeValue("AXRole")
  if not role or TEXT_ROLES[role] then return nil end
  return app
end

-- Hotkey 自身に戻らないよう、最前面アプリへ直接送る。
local function sendTo(app, mods, key)
  if app then hs.eventtap.keyStroke(mods, key, 0, app) end
end

local function stopCopyPoll()
  if copyPoll then copyPoll:stop() end
  copyPoll = nil
end

-- コピーは Finder が非同期に行うため、changeCount が変わるまで待って記録する。
local function rememberCopy(before)
  stopCopyPoll()
  local attempts = 0
  copyPoll = hs.timer.doEvery(COPY_POLL_SECONDS, function()
    attempts = attempts + 1
    local count = hs.pasteboard.changeCount()
    if count ~= before then
      cutChangeCount = count
    elseif attempts < COPY_POLL_LIMIT then
      return
    end
    stopCopyPoll()
  end)
end

function M.cut()
  local app = hs.application.frontmostApplication()
  if not finderWithFiles(app) then return sendTo(app, { "cmd" }, "x") end

  cutChangeCount = nil
  rememberCopy(hs.pasteboard.changeCount())
  sendTo(app, { "cmd" }, "c")
end

function M.paste()
  local app = hs.application.frontmostApplication()
  -- 切り取りの後に別のものをコピーしていれば、通常の貼り付けにする。
  local cut = cutChangeCount ~= nil and cutChangeCount == hs.pasteboard.changeCount()
  if not (cut and finderWithFiles(app)) then return sendTo(app, { "cmd" }, "v") end

  cutChangeCount = nil
  sendTo(app, { "cmd", "alt" }, "v")
end

return M
