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
  function window:isMinimized() return self.minimized end
  function window:unminimize() self.minimized = false end
  function window:focus() self.focusCount = self.focusCount + 1 end
  function window:raise() self.raiseCount = self.raiseCount + 1 end

  return window
end

function M.app(name, options)
  options = options or {}
  local app = {
    activated = false,
    frontmost = options.frontmost == true,
    hidden = false,
    windows = options.windows or {},
  }
  local focusedWindow = options.focusedWindow

  function app:bundleID() return options.bundleID or ("test." .. string.lower(name)) end
  function app:allWindows() return self.windows end
  function app:mainWindow() return self.windows[1] end
  function app:focusedWindow() return focusedWindow end
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

function M.event(eventType, keyCode, flags, properties)
  local event = {}

  function event:getType() return eventType end
  function event:getKeyCode() return keyCode end
  function event:getFlags() return flags or {} end
  function event:getProperty(property) return properties and properties[property] end

  return event
end

function M.new()
  local state = {
    alerts = {},
    applications = {},
    appleScripts = {},
    choosers = {},
    eventtaps = {},
    hotkeys = {},
    jsonValues = {},
    keyStrokes = {},
    launchedApps = {},
    logs = {},
    tasks = {},
    timers = {},
    pasteboardText = "",
    operations = {},
    keyboardModifiers = {},
    activeSpaces = { main = 1 },
  }

  local hs = {
    alert = {},
    application = {},
    chooser = {},
    eventtap = {
      event = {
        properties = {
          eventSourceUserData = "eventSourceUserData",
        },
        types = {
          flagsChanged = "flagsChanged",
          keyDown = "keyDown",
          leftMouseDown = "leftMouseDown",
          rightMouseDown = "rightMouseDown",
          otherMouseDown = "otherMouseDown",
        },
      },
    },
    hotkey = {},
    fs = {},
    json = {},
    keycodes = {},
    logger = {},
    osascript = {},
    pasteboard = {},
    spaces = {},
    task = {},
    timer = {},
    window = {},
  }

  local keycodes = {
    cmd = 55,
    rightcmd = 54,
    f5 = 96,
    b = 11,
    f = 3,
    g = 5,
    i = 34,
    j = 38,
    k = 40,
    l = 37,
    m = 46,
    n = 45,
    o = 31,
    r = 15,
    t = 17,
    u = 32,
    up = 126,
    left = 123,
    down = 125,
    right = 124,
  }
  hs.keycodes.map = setmetatable({}, {
    __index = function(_, key)
      table.insert(state.operations, "keycode.lookup")
      return keycodes[key]
    end,
  })

  function hs.hotkey.bind(mods, key, pressedFn, releasedFn, repeatFn)
    table.insert(state.operations, "hotkey.bind")
    local hotkey = {
      mods = mods,
      key = key,
      pressedFn = pressedFn,
      releasedFn = releasedFn,
      repeatFn = repeatFn,
    }
    table.insert(state.hotkeys, hotkey)
    return hotkey
  end

  function hs.application.get(hint)
    return state.applications[hint]
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

  function hs.alert.show(message)
    table.insert(state.alerts, message)
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

    table.insert(state.choosers, chooser)
    return chooser
  end

  function hs.fs.dir()
    return nil
  end

  function hs.osascript.applescript(script)
    table.insert(state.appleScripts, script)
    return true
  end

  function hs.pasteboard.getContents()
    return state.pasteboardText
  end

  function hs.pasteboard.setContents(text)
    state.pasteboardText = text
    return true
  end

  function hs.timer.doAfter(delay, callback)
    local timer = { delay = delay, callback = callback }
    table.insert(state.timers, timer)
    return timer
  end

  function hs.eventtap.keyStroke(mods, key, delay)
    table.insert(state.keyStrokes, { mods = mods, key = key, delay = delay })
  end

  function hs.eventtap.checkKeyboardModifiers()
    return state.keyboardModifiers
  end

  function hs.eventtap.new(watchedTypes, callback)
    table.insert(state.operations, "eventtap.new")
    local tap = {
      watchedTypes = watchedTypes,
      callback = callback,
      started = false,
    }
    function tap:start()
      self.started = true
      return self
    end
    table.insert(state.eventtaps, tap)
    return tap
  end

  function hs.logger.new(name)
    local logger = {}
    function logger.w(message)
      table.insert(state.logs, { level = "warning", name = name, message = message })
    end
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
    local task = {
      path = path,
      callback = callback,
      args = args,
      started = false,
    }
    function task:start()
      self.started = true
      return true
    end
    table.insert(state.tasks, task)
    return task
  end

  return hs, state
end

return M
