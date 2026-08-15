local M = {}

local SOURCE_KEY_CODES = {
  eisu = 0x66,
  kana = 0x68,
}

local watcher

function M.supportsSource(source)
  return SOURCE_KEY_CODES[source] ~= nil
end

function M.start(config)
  config = config or {}
  if config.enabled == false then return end

  local sourcesByApp = {}
  for _, binding in ipairs(config.bindings or {}) do
    if binding.enabled ~= false then
      sourcesByApp[binding.appName] = SOURCE_KEY_CODES[binding.source]
    end
  end

  if next(sourcesByApp) == nil then return end

  local function apply(app)
    if not app then return end
    local keyCode = sourcesByApp[app:name()]
    if not keyCode then return end
    hs.eventtap.keyStroke({}, keyCode, 0)
  end

  watcher = hs.application.watcher.new(function(_, event, app)
    if event == hs.application.watcher.activated then
      apply(app)
    end
  end)

  watcher:start()
  apply(hs.application.frontmostApplication())
end

return M
