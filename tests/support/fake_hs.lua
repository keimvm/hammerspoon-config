local M = {}

function M.window(id, options)
  options = options or {}
  local window = {
    focusCount = 0,
    minimized = options.minimized == true,
    raiseCount = 0,
    spaces = options.spaces or { 1 },
    standard = options.standard ~= false,
  }

  function window:id() return id end
  function window:isStandard() return self.standard end
  function window:role() return options.role or "AXWindow" end
  function window:subrole()
    if options.subrole then return options.subrole end
    if self:role() ~= "AXWindow" then return "" end
    return self.standard and "AXStandardWindow" or "AXDialog"
  end
  function window:isMinimized() return self.minimized end
  function window:unminimize() self.minimized = false end
  function window:becomeMain()
    if self.owner then self.owner.main = self end
    return self
  end
  function window:focus()
    self.focusCount = self.focusCount + 1
    self:becomeMain()
    if self.owner then
      self.owner.activated = true
      self.owner.frontmost = true
      self.owner.focused = self
    end
    return self
  end
  function window:raise() self.raiseCount = self.raiseCount + 1 end

  return window
end

function M.app(name, options)
  options = options or {}
  local app = {
    activated = false,
    frontmost = options.frontmost == true,
    hidden = false,
    focused = options.focusedWindow,
    windows = options.windows or {},
  }
  for _, window in ipairs(app.windows) do window.owner = app end

  function app:name() return name end
  function app:path() return options.path or ("/Applications/" .. name .. ".app") end
  function app:pid() return options.pid or 1 end
  function app:bundleID() return options.bundleID or ("test." .. string.lower(name)) end
  function app:allWindows() return self.windows end
  function app:mainWindow() return self.main or self.windows[1] end
  function app:focusedWindow() return self.focused end
  function app:isFrontmost() return self.frontmost end
  function app:hide()
    self.hidden = true
    self.frontmost = false
  end
  function app:unhide() self.hidden = false end
  function app:activate()
    self.activated = true
    self.frontmost = true
    if options.onActivate then options.onActivate(self) end
  end

  return app
end

local KEYCODES = {
  a = 0, s = 1, d = 2, f = 3, h = 4, g = 5, z = 6, x = 7, c = 8, v = 9,
  b = 11, q = 12, w = 13, e = 14, r = 15, y = 16, t = 17,
  ["1"] = 18, ["2"] = 19, ["3"] = 20, ["4"] = 21, ["6"] = 22, ["5"] = 23,
  ["="] = 24, ["9"] = 25, ["7"] = 26, ["-"] = 27, ["8"] = 28, ["0"] = 29,
  ["]"] = 30, o = 31, u = 32, ["["] = 33, i = 34, p = 35, l = 37, j = 38,
  ["'"] = 39, k = 40, [";"] = 41, ["\\"] = 42, [","] = 43, ["/"] = 44,
  n = 45, m = 46, ["."] = 47, ["`"] = 50,
  ["return"] = 36, tab = 48, space = 49, delete = 51, escape = 53,
  ["pad+"] = 69,
  f1 = 122, f2 = 120, f3 = 99, f4 = 118, f5 = 96, f6 = 97, f7 = 98, f8 = 100,
  f9 = 101, f10 = 109, f11 = 103, f12 = 111,
  home = 115, pageup = 116, forwarddelete = 117, ["end"] = 119, pagedown = 121,
  left = 123, right = 124, down = 125, up = 126,
}

-- Hammerspoon の API のうち、この設定が使う部分だけを記録つきで再現する。
function M.new()
  local state = {
    alertDetails = {},
    alerts = {},
    applicationWatchers = {},
    applications = {},
    appleScripts = {},
    axElements = {},
    choosers = {},
    closedAlerts = {},
    consoleOpened = 0,
    delayedTimers = {},
    eventtaps = {},
    hotkeys = {},
    jsonValues = {},
    keyStrokes = {},
    launchedApps = {},
    logs = {},
    menubars = {},
    now = 1000,
    operations = {},
    pathwatchers = {},
    playedSounds = {},
    rejectedKeys = {},
    reloadCount = 0,
    settings = {},
    soundRequests = {},
    sounds = {},
    tasks = {},
    timers = {},
    activeSpaces = { main = 1 },
  }

  local hs = {
    alert = {},
    application = { watcher = { activated = "activated" } },
    axuielement = {},
    chooser = {},
    configdir = ".",
    eventtap = {
      event = {
        types = {
          leftMouseDown = "leftMouseDown",
          leftMouseUp = "leftMouseUp",
          rightMouseDown = "rightMouseDown",
          otherMouseDown = "otherMouseDown",
        },
      },
    },
    hotkey = {},
    json = {},
    keycodes = { map = {} },
    logger = {},
    menubar = {},
    osascript = {},
    pathwatcher = {},
    settings = {},
    spaces = {},
    sound = {},
    task = {},
    timer = {},
    window = {
      animationDuration = 0.2,
      filter = { allowedWindowRoles = { AXStandardWindow = true, AXDialog = true, AXSystemDialog = true } },
    },
  }

  for name, code in pairs(KEYCODES) do
    hs.keycodes.map[name] = code
    hs.keycodes.map[code] = name
  end

  local function createHotkey(operation, enabled, mods, key, pressedFn, releasedFn, repeatFn)
    if state.rejectedKeys[key] then error("key is reserved: " .. key) end
    table.insert(state.operations, operation)
    local hotkey = {
      enabled = enabled,
      mods = mods,
      key = key,
      pressedFn = pressedFn,
      releasedFn = releasedFn,
      repeatFn = repeatFn,
    }
    function hotkey:enable()
      self.enabled = true
      return self
    end
    function hotkey:disable()
      self.enabled = false
      return self
    end
    table.insert(state.hotkeys, hotkey)
    return hotkey
  end

  function hs.hotkey.bind(mods, key, pressedFn, releasedFn, repeatFn)
    return createHotkey("hotkey.bind", true, mods, key, pressedFn, releasedFn, repeatFn)
  end

  function hs.hotkey.new(mods, key, pressedFn, releasedFn, repeatFn)
    return createHotkey("hotkey.new", false, mods, key, pressedFn, releasedFn, repeatFn)
  end

  function hs.application.frontmostApplication()
    return state.frontmostApplication
  end

  function hs.application.watcher.new(callback)
    table.insert(state.operations, "application.watcher.new")
    local watcher = { callback = callback, started = false }
    function watcher:start()
      self.started = true
      return self
    end
    function watcher:stop()
      self.started = false
      return self
    end
    table.insert(state.applicationWatchers, watcher)
    return watcher
  end

  -- 最前面アプリの切り替えを application watcher へ届ける。
  function state.activate(app)
    state.frontmostApplication = app
    for _, watcher in ipairs(state.applicationWatchers) do
      if watcher.started then watcher.callback(app and app:name(), hs.application.watcher.activated, app) end
    end
  end

  function hs.application.get(hint)
    return state.applications[hint]
  end

  -- 各要素の問い合わせ時点の上限を記録し、state.axErrors で AX の失敗を再現する。
  local function axElement(kind, attributes)
    local element = { kind = kind, queries = {} }
    local function failed(name)
      return state.axErrors and state.axErrors[kind .. "." .. name]
    end
    function element:setTimeout(value)
      if failed("setTimeout") then return nil, "invalid element" end
      self.timeout = value
      return self
    end
    function element:attributeValue(name)
      table.insert(self.queries, { name = name, timeout = self.timeout })
      if failed(name) then return nil, "cannot complete" end
      return attributes(name)
    end
    table.insert(state.axElements, element)
    return element
  end

  -- state.dockItems の { x, y, w, h, role, subrole, url } を Dock の要素として返す。
  function hs.axuielement.applicationElement(app)
    table.insert(state.operations, "axuielement.applicationElement")
    local isDock = app:name() == "Dock"
    local element = axElement(isDock and "dock" or "app", function(name)
      if name == "AXFocusedWindow" and app.focused then
        return axElement("window", function(attribute)
          if attribute == "AXMinimized" then return app.focused:isMinimized() end
          if attribute == "AXSubrole" then return app.focused:subrole() end
        end)
      end
    end)
    element.pid = app:pid()
    function element:elementAtPosition(point)
      table.insert(self.queries, { name = "elementAtPosition", timeout = self.timeout })
      if state.axErrors and state.axErrors["dock.elementAtPosition"] then return nil, "cannot complete" end
      for _, item in ipairs(state.dockItems or {}) do
        if point.x >= item.x and point.x < item.x + item.w and point.y >= item.y and point.y < item.y + item.h then
          return axElement("item", function(name)
            if name == "AXRole" then return item.role or "AXDockItem" end
            if name == "AXSubrole" then return item.subrole or "AXApplicationDockItem" end
            if name == "AXURL" then return item.url end
          end)
        end
      end
      return nil, "no element"
    end
    return element
  end

  function hs.application.find(hint)
    return state.applications[hint]
  end

  function hs.application.launchOrFocus(appName)
    table.insert(state.launchedApps, appName)
    return true
  end

  function hs.spaces.activeSpaces()
    return state.activeSpaces
  end

  function hs.spaces.windowSpaces(window)
    return window.spaces
  end

  function hs.alert.show(message, ...)
    local id = "alert-" .. tostring(#state.alertDetails + 1)
    table.insert(state.alertDetails, {
      id = id,
      message = message,
      arguments = { ... },
      closed = false,
    })
    table.insert(state.alerts, message)
    return id
  end

  function hs.alert.closeSpecific(id, seconds)
    for _, alert in ipairs(state.alertDetails) do
      if alert.id == id then alert.closed = true end
    end
    table.insert(state.closedAlerts, { id = id, seconds = seconds })
  end

  function hs.chooser.new(callback)
    local chooser = {
      callback = callback,
      currentChoices = {},
      visible = false,
    }

    local function setter(field)
      return function(self, value)
        self[field] = value
        return self
      end
    end

    chooser.width = setter("widthValue")
    chooser.rows = setter("rowsValue")
    chooser.bgDark = setter("bgDarkValue")
    chooser.fgColor = setter("fgColorValue")
    chooser.subTextColor = setter("subTextColorValue")
    chooser.placeholderText = setter("placeholderTextValue")
    chooser.searchSubText = setter("searchSubTextValue")
    chooser.queryChangedCallback = setter("queryChangedFn")

    function chooser:choices(choices)
      self.currentChoices = choices
      return self
    end
    function chooser:query(query)
      if query == nil then return self.queryValue end
      self.queryValue = query
      return self
    end
    function chooser:show()
      self.visible = true
      return self
    end
    function chooser:hide()
      self.visible = false
      return self
    end
    -- 行を選んだときと同じく、閉じてから callback を呼ぶ。
    function chooser:select(index)
      self.visible = false
      self.callback(self.currentChoices[index])
    end

    table.insert(state.choosers, chooser)
    return chooser
  end

  function hs.osascript.applescript(script)
    table.insert(state.appleScripts, script)
    return true
  end

  function hs.timer.doAfter(delay, callback)
    local timer = { delay = delay, callback = callback, running = true }
    function timer:stop()
      self.running = false
      return self
    end
    table.insert(state.timers, timer)
    return timer
  end

  function hs.timer.doEvery(interval, callback)
    local timer = { interval = interval, callback = callback, running = true }
    function timer:stop()
      self.running = false
      return self
    end
    table.insert(state.timers, timer)
    return timer
  end

  hs.timer.delayed = {}
  function hs.timer.delayed.new(delay, callback)
    local timer = { delay = delay, callback = callback, running = false, starts = 0 }
    function timer:start()
      self.running = true
      self.starts = self.starts + 1
      return self
    end
    function timer:stop()
      self.running = false
      return self
    end
    -- 待ち時間が過ぎたことにして実行する。
    function timer:fire()
      self.running = false
      self.callback()
    end
    table.insert(state.delayedTimers, timer)
    return timer
  end

  function hs.timer.secondsSinceEpoch()
    return state.now
  end

  function hs.menubar.new(inMenuBar)
    local item = { inMenuBar = inMenuBar ~= false, deleted = false }
    function item:setTitle(title)
      self.title = title
      return self
    end
    function item:setMenu(menu)
      self.menu = menu
      return self
    end
    function item:delete()
      self.deleted = true
      self.inMenuBar = false
    end
    table.insert(state.menubars, item)
    return item
  end

  function hs.sound.getByName(name)
    table.insert(state.soundRequests, name)
    if state.soundUnavailable then return nil end

    local sound = { name = name, playCount = 0 }
    function sound:volume(level)
      if level == nil then return self.volumeValue end
      self.volumeValue = level
      return self
    end
    function sound:play()
      self.playCount = self.playCount + 1
      table.insert(state.playedSounds, self.name)
      return self
    end
    table.insert(state.sounds, sound)
    return sound
  end

  function hs.eventtap.keyStroke(mods, key, delay)
    table.insert(state.keyStrokes, { mods = mods, key = key, delay = delay })
  end

  function hs.eventtap.new(watchedTypes, callback)
    table.insert(state.operations, "eventtap.new")
    local tap = { watchedTypes = watchedTypes, callback = callback, started = false }
    -- 1つのマウスイベントを送り、止めたかどうかを返す。
    function tap:send(eventType, point, flags)
      local event = {}
      function event:getType() return eventType end
      function event:location() return point end
      function event:getFlags() return flags or {} end
      return self.callback(event)
    end
    function tap:start()
      self.started = true
      return self
    end
    function tap:stop()
      self.started = false
      return self
    end
    table.insert(state.eventtaps, tap)
    return tap
  end

  function hs.logger.new(name)
    local logger = {}
    local function record(level)
      return function(message)
        table.insert(state.logs, { level = level, name = name, message = message })
      end
    end
    logger.w = record("warning")
    logger.e = record("error")
    function logger.wf(format, ...)
      logger.w(string.format(format, ...))
    end
    return logger
  end

  function hs.json.encode(value)
    table.insert(state.jsonValues, value)
    return "<encoded-json>"
  end

  function hs.task.new(path, callback, args)
    table.insert(state.operations, "task.new")
    local task = { path = path, callback = callback, args = args, started = false }
    function task:start()
      self.started = true
      return true
    end
    table.insert(state.tasks, task)
    return task
  end

  function hs.pathwatcher.new(path, callback)
    local watcher = { path = path, callback = callback, started = false }
    function watcher:start()
      self.started = true
      return self
    end
    table.insert(state.pathwatchers, watcher)
    return watcher
  end

  function hs.settings.get(key)
    return state.settings[key]
  end

  function hs.settings.set(key, value)
    state.settings[key] = value
  end

  function hs.settings.clear(key)
    state.settings[key] = nil
    return true
  end

  function hs.reload()
    state.reloadCount = state.reloadCount + 1
  end

  function hs.openConsole()
    state.consoleOpened = state.consoleOpened + 1
  end

  return hs, state
end

-- fake hs を _G.hs に置き、読み込み済みの modules を捨てて新しい状態から始める。
function M.install()
  local hs, state = M.new()
  _G.hs = hs
  for name in pairs(package.loaded) do
    if name:match("^modules%.") then package.loaded[name] = nil end
  end
  return hs, state
end

return M
