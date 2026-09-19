local M = {}

local log = hs.logger.new("app_switcher", "warning")
local appState = {}  -- key: bundleID or appName -> { lastWinId = number }
local DEFAULT_MODS = { "ctrl" }

local function copyList(list)
  local copy = {}
  for index, value in pairs(list) do
    copy[index] = value
  end
  return copy
end

local function derivedId(binding)
  local mods = binding.mods
  local key = binding.key
  if type(key) ~= "string" or key == "" then return nil end
  if type(mods) ~= "table" then
    mods = DEFAULT_MODS
  end

  local parts = {}
  for _, mod in ipairs(mods) do
    if type(mod) == "string" and mod ~= "" then
      table.insert(parts, string.lower(mod))
    end
  end
  table.insert(parts, string.lower(key))
  return "app-switcher." .. table.concat(parts, "+")
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

  if type(hotkey.id) ~= "string" or hotkey.id == "" then
    local id = derivedId(hotkey)
    if id then hotkey.id = id end
  end

  return hotkey
end

local function stateKey(app, fallbackName)
  return (app and app:bundleID()) or fallbackName
end

local function findRunningApp(hint)
  local app = hs.application.get(hint)
  if app then return app end

  return hs.application.find(hint, false, true)
end

local function getCandidateWindows(app)
  local all = app:allWindows() or {}
  local standard = {}

  for _, w in ipairs(all) do
    if w:isStandard() then table.insert(standard, w) end
  end

  local wins = (#standard > 0) and standard or {}

  if #wins == 0 then
    local mw = app:mainWindow()
    if mw then wins = { mw } end
  end

  if #wins == 0 then wins = copyList(all) end

  return wins
end

local function getCurrentSpaceCandidates(wins)
  local ok, activeSpaces, err = pcall(hs.spaces.activeSpaces)
  if not ok or not activeSpaces then
    log.wf("active space lookup failed: %s", err or activeSpaces or "unknown error")
    return nil
  end

  local activeSpaceIds = {}
  for _, spaceId in pairs(activeSpaces) do
    activeSpaceIds[spaceId] = true
  end

  local current = {}
  for _, win in ipairs(wins) do
    local spacesOk, windowSpaces, spacesErr = pcall(hs.spaces.windowSpaces, win)
    if not spacesOk or not windowSpaces then
      log.wf(
        "window space lookup failed for %s: %s",
        tostring(win:id()),
        spacesErr or windowSpaces or "unknown error"
      )
      return nil
    end

    for _, spaceId in ipairs(windowSpaces) do
      if activeSpaceIds[spaceId] then
        table.insert(current, win)
        break
      end
    end
  end

  return current
end

local function getPreferredCandidateWindows(app)
  local wins = getCandidateWindows(app)
  if #wins <= 1 then return wins end

  local current = getCurrentSpaceCandidates(wins)
  if current and #current > 0 then wins = current end

  -- OS を跨ぐ ID 取得は候補ごとに1回とし、比較関数では Lua の値だけを扱う。
  local ids = {}
  for _, win in ipairs(wins) do ids[win] = win:id() or 0 end
  table.sort(wins, function(a, b) return ids[a] < ids[b] end)

  return wins
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

  app:unhide()
  app:activate(true)

  if win:isMinimized() then
    win:unminimize()
  end

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

    local wins = getPreferredCandidateWindows(app)
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

  if app:isFrontmost() then
    local fw = app:focusedWindow() or app:mainWindow()
    if fw then appState[key].lastWinId = fw:id() end
    app:hide()
    return
  end

  local wins = getPreferredCandidateWindows(app)

  if #wins == 0 then
    reopenApp(app)
    focusNextWindowAfterReopen(appName)
    return
  end

  local idx = nextIndexByLastId(wins, appState[key].lastWinId)
  focusWindow(app, wins[idx])
  appState[key].lastWinId = wins[idx]:id()
end

function M.bindToggle(binding, registry)
  registry:bind(M.desiredHotkey(binding), function()
    M.toggleOrCycle(binding.appName)
  end)
end

return M
