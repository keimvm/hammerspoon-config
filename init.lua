-- Hammerspoon の入口。config.lua を検証し、問題がなければ上から順に適用する。
-- テストでは設定テーブルを引数で渡せる。
local dockToggle = require("modules.dock_toggle")
local frontmost = require("modules.frontmost")
local hotkeys = require("modules.hotkeys")
local inputSource = require("modules.input_source")
local palette = require("modules.palette")
local preflight = require("modules.preflight")
local reloader = require("modules.reloader")
local remap = require("modules.remap")
local ui = require("modules.ui")

local configOverride = ...
local configPath = hs.configdir .. "/config.lua"
local reloaded = reloader.takeReloadedFlag()

local config, problems = preflight.load(configOverride or configPath)

-- 設定に問題があっても、直して保存すれば適用されるよう監視は始める。
reloader.watch(configPath, config ~= nil)

if not config then
  ui.problems("設定に問題があるため、何も適用していません", problems)
  return
end

-- App Switcher のフォーカス移動を即時にする。
hs.window.animationDuration = 0

remap.apply(config.remap)
local bound, failures = hotkeys.start(config.hotkeys)
inputSource.start(config.inputSource)
frontmost.start()
dockToggle.start(config.dockToggle)
palette.use(bound)

if #failures > 0 then
  ui.problems("登録できなかった Hotkey があります", failures)
elseif reloaded then
  ui.toast(string.format("設定を再読み込みしました（Hotkey %d 件）", #bound))
end
