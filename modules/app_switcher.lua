local M = {}

local log = hs.logger.new("app_switcher", "warning")
local appState = {}  -- key: bundleID or appName -> { lastWinId = number }
local openTasks = {} -- keep hs.task references alive

local function stateKey(app, fallbackName)
  return (app and app:bundleID()) or fallbackName
end

local function findRunningApp(hint)
  local app = hs.application.get(hint)
  if app then return app end

  return hs.application.find(hint, false, true)
end

local function getFilesInDirectory(dirPath)
  local files = {}
  local ok, iter, dirObj = pcall(hs.fs.dir, dirPath)
  if not ok or not iter then
    hs.alert.show("ディレクトリが見つかりません: " .. dirPath)
    return files
  end

  for entry in iter, dirObj do
    if entry ~= "." and entry ~= ".." and not entry:match("^%.") then
      local fullPath = dirPath .. "/" .. entry
      local attr = hs.fs.attributes(fullPath)
      if attr and attr.mode == "file" then
        table.insert(files, fullPath)
      end
    end
  end

  table.sort(files)
  return files
end

local function openFilesWithApp(appName, files)
  local args = { "-a", appName }
  for _, path in ipairs(files) do table.insert(args, path) end

  local task
  task = hs.task.new("/usr/bin/open", function(exitCode, _, stdErr)
    if task then openTasks[task] = nil end
    if exitCode == 0 then return end

    if stdErr and #stdErr > 0 then
      log.wf("open failed for %s: %s", appName, stdErr)
    else
      log.wf("open failed for %s (exit %d)", appName, exitCode)
    end

    hs.application.launchOrFocus(appName)
  end, args)

  if not task then
    log.wf("failed to create open task for %s", appName)
    return false
  end

  openTasks[task] = true
  if not task:start() then
    log.wf("failed to start open task for %s", appName)
    openTasks[task] = nil
    return false
  end

  return true
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

  if #wins == 0 then wins = all end

  table.sort(wins, function(a, b)
    return (a:id() or 0) < (b:id() or 0)
  end)

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
  if #wins == 0 then return wins end

  local current = getCurrentSpaceCandidates(wins)
  if current and #current > 0 then return current end

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

local function launchApp(appName, dirToOpen)
  if not dirToOpen then
    hs.application.launchOrFocus(appName)
    return
  end

  local files = getFilesInDirectory(dirToOpen)
  if #files > 0 and openFilesWithApp(appName, files) then
    return
  end

  hs.application.launchOrFocus(appName)
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

function M.toggleOrCycle(appName, dirToOpen)
  local app = findRunningApp(appName)

  if not app then
    launchApp(appName, dirToOpen)
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
  registry:bind(binding, function()
    M.toggleOrCycle(binding.appName, binding.dirToOpen)
  end)
end

return M
