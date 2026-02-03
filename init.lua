-- F5 -> Cmd+R（リロード）
hs.hotkey.bind({}, "F5", function()
  hs.eventtap.keyStroke({ "cmd" }, "r", 0)
end)


-- toggle / cycle application windows

local log = hs.logger.new("init", "warning")
local appState = {} -- key: bundleID or appName -> { lastWinId = number }
local openTasks = {} -- keep hs.task references alive

local function stateKey(app, fallbackName)
  return (app and app:bundleID()) or fallbackName
end

-- 「実行中アプリを見つける」：厳密一致の落とし穴を回避
local function findRunningApp(hint)
  -- get() は「アプリ名/BundleID/pid」での単一取得（より安全）
  local app = hs.application.get(hint)
  if app then return app end

  -- find() は部分一致もできる（exact=false, stringLiteral=true）
  -- iTerm vs iTerm2 のようなケースに強い
  return hs.application.find(hint, false, true)
end

local function getFilesInDirectory(dirPath)
  local files = {}
  local iter, dirObj = hs.fs.dir(dirPath)
  if not iter then
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
    return false
  end
  return true
end

-- 標準ウィンドウ優先。無ければ mainWindow → allWindows の順でフォールバック
local function getCandidateWindows(app)
  local all = app:allWindows() or {} -- current Space の制限あり
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
  app:activate(true) -- allWindows=true

  if win:isMinimized() then
    win:unminimize()
  end
  win:focus()
  win:raise()
  return true
end

-- ウィンドウが0枚のとき：reopenイベントで「Dock再オープン相当」を狙う
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

local function toggleOrCycle(appName, dirToOpen)
  local app = findRunningApp(appName)

  -- 未起動：従来どおり起動
  if not app then
    if dirToOpen then
      local files = getFilesInDirectory(dirToOpen)
      if #files > 0 then
        if not openFilesWithApp(appName, files) then
          hs.application.launchOrFocus(appName)
        end
      else
        hs.application.launchOrFocus(appName)
      end
    else
      hs.application.launchOrFocus(appName)
    end
    return
  end

  local key = stateKey(app, appName)
  appState[key] = appState[key] or { lastWinId = nil }

  -- 前面なら隠す（iTermの「隠れない」をここで確実に潰す）
  if app:isFrontmost() then
    local fw = app:focusedWindow() or app:mainWindow()
    if fw then appState[key].lastWinId = fw:id() end
    app:hide()
    return
  end

  -- 背面/非表示：ウィンドウを順番に出す
  app:unhide()
  app:activate(true)

  local wins = getCandidateWindows(app)

  if #wins == 0 then
    -- ウィンドウ0枚：reopen を投げて生成を促す
    reopenApp(app)

    -- 生成は非同期になりがちなので、次のtickで再取得してフォーカス
    hs.timer.doAfter(0.05, function()
      local app2 = findRunningApp(appName)
      if not app2 then return end

      local key2 = stateKey(app2, appName)
      appState[key2] = appState[key2] or { lastWinId = nil }

      local wins2 = getCandidateWindows(app2)
      if #wins2 == 0 then return end

      local idx = nextIndexByLastId(wins2, appState[key2].lastWinId)
      if not idx then return end

      focusWindow(app2, wins2[idx])
      appState[key2].lastWinId = wins2[idx]:id()
    end)

    return
  end

  local idx = nextIndexByLastId(wins, appState[key].lastWinId)
  focusWindow(app, wins[idx])
  appState[key].lastWinId = wins[idx]:id()
end

local function makeToggle(appName, mods, key, dirToOpen)
  hs.hotkey.bind(mods, key, function()
    toggleOrCycle(appName, dirToOpen)
  end)
end

----------------------------------------------------------------------
-- bindings
----------------------------------------------------------------------

local home = os.getenv("HOME")

makeToggle("MarkEdit", { "ctrl" }, "m", home .. "/Desktop/memo") -- Ctrl+m
makeToggle("Marta", { "ctrl" }, "f")
makeToggle("Spark", { "ctrl" }, "o")
makeToggle("Google Chrome", { "ctrl" }, "p")
makeToggle("Ghostty", { "ctrl" }, "t")
makeToggle("Zed", { "ctrl" }, "r")
makeToggle("ChatGPT Atlas", { "ctrl" }, "g")
makeToggle("Notion", { "ctrl" }, "n")
--makeToggle("YouTube", { "ctrl" }, "y")
