local M = {}

local state = {}

local function syncHotkey(config, app)
  if app and app:bundleID() == config.bundleID then
    state.hotkey:enable()
  else
    state.hotkey:disable()
  end
end

function M.start(config, registry)
  config = config or {}
  if config.enabled == false then return end

  state.hotkey = registry:create(config, function() end)
  state.watcher = hs.application.watcher.new(function(_, event, app)
    if event == hs.application.watcher.activated then
      syncHotkey(config, app)
    end
  end)

  state.watcher:start()
  syncHotkey(config, hs.application.frontmostApplication())
end

return M
