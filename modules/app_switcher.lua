-- App Switcher。アプリを起動、フォーカス、非表示、またはウィンドウを順に切り替える。
-- 候補は各ディスプレイで現在表示中の Space を優先する。
local ui = require("modules.ui")

local M = {}

local log = hs.logger.new("app_switcher", "warning")
local appState = {}  -- key: bundleID or appName -> { lastWinId = number }

local function stateKey(app, fallbackName)
  return (app and app:bundleID()) or fallbackName
end

local function findRunningApp(hint)
  local app = hs.application.get(hint)
  if app then return app end

  return hs.application.find(hint, false, true)
end

local function getCandidateWindows(app)
  local wins, ids, seen = {}, {}, {}
  local function addWindow(win)
    if not win then return end
    local id = win:id()
    if not id or id <= 0 or seen[id] then return end
    -- 標準フィルターと同じ種類だけを扱い、補助パネルや Finder のデスクトップを除く。
    if hs.window.filter.allowedWindowRoles[win:subrole()] then
      table.insert(wins, win)
      ids[win], seen[id] = id, true
    end
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

  -- OS を跨ぐ ID 取得は候補ごとに1回とし、比較関数では Lua の値だけを扱う。
  table.sort(wins, function(a, b) return ids[a] < ids[b] end)

  return wins, isCurrent
end

local function nextIndexByLastId(wins, lastWinId)
  if #wins == 0 then return nil end
  if not lastWinId then return 1 end

  for i, w in ipairs(wins) do
    if w:id() == lastWinId then
      return (i % #wins) + 1
    end
  end

  return 1
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

local function focusNextWindowAfterReopen(appName)
  hs.timer.doAfter(0.05, function()
    local app = findRunningApp(appName)
    if not app then return end

    local key = stateKey(app, appName)
    appState[key] = appState[key] or { lastWinId = nil }

    local wins = getPreferredCandidateWindows(getCandidateWindows(app))
    if not wins then return end
    local idx = nextIndexByLastId(wins, appState[key].lastWinId)
    if not idx then return end

    focusWindow(app, wins[idx])
    appState[key].lastWinId = wins[idx]:id()
  end)
end

function M.toggleOrCycle(appName)
  local app = findRunningApp(appName)

  if not app then
    hs.application.launchOrFocus(appName)
    return
  end

  local key = stateKey(app, appName)
  appState[key] = appState[key] or { lastWinId = nil }

  local wins, ids = getCandidateWindows(app)
  if #wins == 0 then
    reopenApp(app)
    focusNextWindowAfterReopen(appName)
    return
  end

  local isCurrent
  wins, isCurrent = getPreferredCandidateWindows(wins, ids)
  if not wins then
    ui.toast("デスクトップを確認できませんでした。もう一度押してください。", 2)
    return
  end

  -- Finder のデスクトップが最前面なだけなら、非表示にせず別 Space のウィンドウを開く。
  if app:isFrontmost() and isCurrent then
    local fw = app:focusedWindow()
    local focusedId = fw and fw:id()
    for _, win in ipairs(wins) do
      if ids[win] == focusedId and not win:isMinimized() then
        appState[key].lastWinId = focusedId
        app:hide()
        return
      end
    end
  end

  local idx = nextIndexByLastId(wins, appState[key].lastWinId)
  focusWindow(app, wins[idx])
  appState[key].lastWinId = wins[idx]:id()
end

return M
