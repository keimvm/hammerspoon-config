-- 最前面アプリの変化を、必要とする機能へ知らせる。application watcher は1つだけ作る。
local M = {}

local listeners = {}
local watcher

-- listener は最前面アプリの名前（不明なら nil）を受け取る。
function M.subscribe(listener)
  table.insert(listeners, listener)
end

local function publish(app)
  local name = app and app:name()
  for _, listener in ipairs(listeners) do listener(name) end
end

-- 監視を始め、現在の最前面アプリをすぐに知らせる。
function M.start()
  if watcher or #listeners == 0 then return end

  watcher = hs.application.watcher.new(function(_, event, app)
    if event == hs.application.watcher.activated then publish(app) end
  end)
  watcher:start()
  publish(hs.application.frontmostApplication())
end

return M
