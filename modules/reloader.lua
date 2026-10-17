-- config.lua の保存を監視し、Config Preflight に通った場合だけ再読み込みする。
-- 問題があれば再読み込みせず、今の状態を保ったまま問題を表示する。
local preflight = require("modules.preflight")
local ui = require("modules.ui")

local M = {}

local RELOADED_KEY = "hammerspoon-config.reloaded"
local DEBOUNCE_SECONDS = 0.3

local configPath
local lastContent
local applied = false
local watcher
local debounce

local function readFile(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = file:read("a")
  file:close()
  return content
end

-- 読み込み済みのモジュールと init.lua の構文を確かめる。
local function syntaxProblems()
  local files = { hs.configdir .. "/init.lua" }
  for name in pairs(package.loaded) do
    if type(name) == "string" and name:match("^modules%.") then
      local path = package.searchpath(name, package.path)
      if path then table.insert(files, path) end
    end
  end
  table.sort(files)

  local problems = {}
  for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    if not chunk then table.insert(problems, tostring(err)) end
  end
  return problems
end

-- 前回の再読み込みがこのモジュールからのものかを返し、印を消す。
function M.takeReloadedFlag()
  local reloaded = hs.settings.get(RELOADED_KEY) == true
  if reloaded then hs.settings.clear(RELOADED_KEY) end
  return reloaded
end

-- options.force が真なら、内容が変わっていなくても再読み込みする。
function M.reload(options)
  options = options or {}
  local content = readFile(configPath)
  if not options.force and content == lastContent then return false end
  lastContent = content

  local _, problems = preflight.load(configPath)
  for _, problem in ipairs(syntaxProblems()) do table.insert(problems, problem) end

  if #problems > 0 then
    local state = applied and "今の設定のまま動いています" or "設定はまだ適用されていません"
    ui.problems("設定に問題があるため再読み込みしませんでした（" .. state .. "）", problems)
    return false
  end

  hs.settings.set(RELOADED_KEY, true)
  hs.reload()
  return true
end

-- path の保存を監視する。isApplied は今の設定が適用済みかどうか。
function M.watch(path, isApplied)
  configPath = path
  applied = isApplied == true
  lastContent = readFile(path)

  local dir, name = path:match("^(.*)/([^/]+)$")
  debounce = hs.timer.delayed.new(DEBOUNCE_SECONDS, function() M.reload() end)
  watcher = hs.pathwatcher.new(dir, function(paths)
    for _, changed in ipairs(paths) do
      if changed:match("([^/]+)$") == name then
        debounce:start()
        return
      end
    end
  end)
  watcher:start()
end

return M
