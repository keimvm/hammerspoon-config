-- App Switcher。アプリを起動、フォーカス、非表示、またはウィンドウを順に切り替える。
-- 候補は各ディスプレイで現在表示中の Space を優先する。
local ui = require("modules.ui")

local M = {}

local log = hs.logger.new("app_switcher", "warning")
-- 最前面で2回押したとみなす間隔（秒）。この間は非表示を保留する。
local DOUBLE_PRESS_INTERVAL = 0.3
-- 最前面で押した直後の状態。{ key, at, app, hideTimer, winId }
local lastPress

local function stateKey(app, fallbackName)
  return (app and app:bundleID()) or fallbackName
end

local function findRunningApp(hint)
  local app = hs.application.get(hint)
  if app then return app end

  return hs.application.find(hint, false, true)
end

-- app:hide() は AX でアプリに隠すよう求め、結果も AX で読み返す。最前面の Zed などはこの応答に
-- 0.4 秒ほどかかるため、AppleScriptObjC から NSRunningApplication で隠す。失敗したときだけ app:hide() を使う。
-- AppKit を読み込むと1回 0.02 秒ほどかかるため、クラスは NSClassFromString で取る。
-- アプリが終了していればエラーになる。hide の戻り値は隠せた場合も false になるため使わない。
local function hideApp(app)
  local ok = hs.osascript.applescript(string.format(
    'use framework "Foundation"\n'
      .. '((current application\'s NSClassFromString("NSRunningApplication"))'
      .. "'s runningApplicationWithProcessIdentifier:%d)'s hide()",
    app:pid()
  ))
  if ok then return end
  log.wf("hide via NSRunningApplication failed for %s", app:name())
  app:hide()
end

-- 保留中の非表示を取り消す。別アプリの Hotkey なら、取り消さずにすぐ隠す。
local function settlePendingHide(key)
  local pending = lastPress
  lastPress = nil
  if not (pending and pending.hideTimer) then return end

  pending.hideTimer:stop()
  if pending.key ~= key then hideApp(pending.app) end
end

-- 候補はアプリのウィンドウ一覧の順（重なり順）に並べる。
local function getCandidateWindows(app)
  local wins, ids, seen = {}, {}, {}
  local function addWindow(win)
    if not win then return end
    local id = win:id()
    if not id or id <= 0 or seen[id] then return end
    -- 標準フィルターと同じ種類だけを扱い、補助パネルや Finder のデスクトップを除く。
    -- タイトルのないダイアログも除く。Zed の小さな浮動ウィンドウなどが2枚目に数えられ、隠すのが遅れるため。
    local subrole = win:subrole()
    if not hs.window.filter.allowedWindowRoles[subrole] then return end
    if subrole ~= "AXStandardWindow" and (win:title() or "") == "" then return end
    table.insert(wins, win)
    ids[win], seen[id] = id, true
  end

  for _, win in ipairs(app:allWindows() or {}) do
    addWindow(win)
  end
  -- 別 Space のウィンドウが一覧から取れないアプリでも、新規表示を要求する前に確認する。
  if #wins == 0 then
    addWindow(app:mainWindow())
    addWindow(app:focusedWindow())
  end
  return wins, ids
end

local function getPreferredCandidateWindows(wins, ids)
  if #wins == 0 then return wins, false end

  local ok, activeSpaces, err = pcall(hs.spaces.activeSpaces)
  if not ok or not activeSpaces or next(activeSpaces) == nil then
    log.wf("active space lookup failed: %s", err or activeSpaces or "unknown error")
    return nil
  end

  local activeSpaceIds = {}
  for _, spaceId in pairs(activeSpaces) do
    activeSpaceIds[spaceId] = true
  end

  local current, other = {}, {}
  local lookupFailed = false
  for _, win in ipairs(wins) do
    local spacesOk, windowSpaces, spacesErr = pcall(hs.spaces.windowSpaces, win)
    if not spacesOk or not windowSpaces then
      log.wf(
        "window space lookup failed for %s: %s",
        tostring(ids[win]),
        spacesErr or windowSpaces or "unknown error"
      )
      lookupFailed = true
    elseif #windowSpaces > 0 then
      local isCurrent = false
      for _, spaceId in ipairs(windowSpaces) do
        if activeSpaceIds[spaceId] then
          isCurrent = true
          break
        end
      end
      table.insert(isCurrent and current or other, win)
    end
  end

  -- 空の所属一覧は非表示タブなどにも現れるため候補から外す。API の失敗とは区別する。
  -- 現在の Space にあると確認できた候補は使えるが、取得失敗時は別 Space へ移動しない。
  if #current == 0 and lookupFailed then return nil end
  local isCurrent = #current > 0
  wins = isCurrent and current or other
  if #wins == 0 then return nil end

  return wins, isCurrent
end

local function visibleWindows(wins)
  local visible = {}
  for _, win in ipairs(wins) do
    if not win:isMinimized() then table.insert(visible, win) end
  end
  return visible
end

local function findById(wins, ids, id)
  if not id then return nil end
  for _, win in ipairs(wins) do
    if ids[win] == id then return win end
  end
end

local function focusedWindowId(app)
  local fw = app:focusedWindow()
  return fw and fw:id()
end

-- 戻り先。直前に使ったウィンドウ、なければ重なり順で一番上を選ぶ。
-- 最小化中のウィンドウは、ほかに候補がないときだけ選ぶ。
local function topWindow(app, wins, ids)
  local visible = visibleWindows(wins)
  local pool = #visible > 0 and visible or wins
  return findById(pool, ids, focusedWindowId(app)) or pool[1]
end

-- 巡回は重なり順ではなく ID 順にする。前面に出すたびに重なり順が変わるため。
local function nextWindow(wins, ids, currentId)
  local sorted = { table.unpack(wins) }
  -- OS を跨ぐ ID 取得は候補ごとに1回とし、比較関数では Lua の値だけを扱う。
  table.sort(sorted, function(a, b) return ids[a] < ids[b] end)
  for i, win in ipairs(sorted) do
    if ids[win] == currentId then return sorted[(i % #sorted) + 1] end
  end
  return sorted[1]
end

local function focusWindow(app, win)
  if not (app and win) then return false end

  if win:isMinimized() then
    win:unminimize()
  end

  -- 再表示より先に対象を main にする。focus() 自体がアプリの前面化と Finder 対策を行う。
  win:becomeMain()
  app:unhide()
  win:focus()
  win:raise()
  return true
end

local function reopenApp(app)
  local bid = app and app:bundleID()
  if not bid then return false end

  local ok, _, err = hs.osascript.applescript(
    string.format('tell application id "%s" to reopen', bid)
  )
  if not ok then
    log.wf("reopen failed for %s: %s", bid, err or "unknown error")
  end

  return ok
end

local function focusTopWindowAfterReopen(appName)
  hs.timer.doAfter(0.05, function()
    local app = findRunningApp(appName)
    if not app then return end

    local wins, ids = getCandidateWindows(app)
    wins = getPreferredCandidateWindows(wins, ids)
    if not (wins and #wins > 0) then return end

    focusWindow(app, topWindow(app, wins, ids))
  end)
end

-- app:isFrontmost() は AX でアプリに問い合わせるため、最前面の Zed などで 0.4 秒ほど待たされる。
-- NSWorkspace の最前面アプリと pid で比べる。
local function isFrontmost(app)
  local front = hs.application.frontmostApplication()
  return front ~= nil and front:pid() == app:pid()
end

-- 画面上にある、そのアプリの通常レベルのウィンドウの数。WindowServer の情報だけを使い、アプリには問い合わせない。
-- 最小化中や別 Space のウィンドウ、浮動パネルは数えない。取得できなければ nil。
local function onscreenWindowCount(app)
  local ok, list = pcall(hs.window.list, true)
  if not ok or type(list) ~= "table" then return nil end

  local pid, count = app:pid(), 0
  for _, info in ipairs(list) do
    if info.kCGWindowOwnerPID == pid and info.kCGWindowLayer == 0 and (info.kCGWindowAlpha or 1) > 0 then
      count = count + 1
    end
  end
  return count
end

-- 最前面で押されたとき。1回なら隠し、短い間隔で続けて押されたら次のウィンドウへ進む。
-- ウィンドウが1つなら巡回先がないため、待たずに隠す。
local function pressWhileFrontmost(app, key, visible, ids, focusedId)
  local now = hs.timer.secondsSinceEpoch()
  local previous = lastPress
  local isRepeat = previous and previous.key == key and now - previous.at < DOUBLE_PRESS_INTERVAL
  settlePendingHide(key)

  if #visible < 2 then
    hideApp(app)
    return
  end

  if isRepeat then
    -- 前面化の直後は focusedWindow が古いことがあるため、直前に進めた先を基準にする。
    local target = nextWindow(visible, ids, previous.winId or focusedId)
    lastPress = { key = key, at = now, winId = ids[target] }
    focusWindow(app, target)
    return
  end

  local pending = { key = key, at = now, app = app }
  pending.hideTimer = hs.timer.doAfter(DOUBLE_PRESS_INTERVAL, function()
    if lastPress == pending then lastPress = nil end
    hideApp(app)
  end)
  lastPress = pending
end

function M.toggleOrCycle(appName)
  local app = findRunningApp(appName)
  local key = stateKey(app, appName)

  if not app then
    settlePendingHide(key)
    hs.application.launchOrFocus(appName)
    return
  end

  -- 画面上のウィンドウが1つなら巡回先がないため、AX で調べずにすぐ隠す。
  -- Zed など、最前面の間は AX の応答に 0.5 秒ほどかかるアプリがあるため。
  local frontmost = isFrontmost(app)
  if frontmost and onscreenWindowCount(app) == 1 then
    settlePendingHide(key)
    hideApp(app)
    return
  end

  local wins, ids = getCandidateWindows(app)
  if #wins == 0 then
    settlePendingHide(key)
    reopenApp(app)
    focusTopWindowAfterReopen(appName)
    return
  end

  local isCurrent
  wins, isCurrent = getPreferredCandidateWindows(wins, ids)
  if not wins then
    settlePendingHide(key)
    ui.toast("デスクトップを確認できませんでした。もう一度押してください。", 2)
    return
  end

  -- Finder のデスクトップが最前面なだけなら、非表示にせず別 Space のウィンドウを開く。
  if frontmost and isCurrent then
    local visible = visibleWindows(wins)
    local focusedId = focusedWindowId(app)
    if findById(visible, ids, focusedId) then
      pressWhileFrontmost(app, key, visible, ids, focusedId)
      return
    end
  end

  settlePendingHide(key)
  focusWindow(app, topWindow(app, wins, ids))
end

return M
