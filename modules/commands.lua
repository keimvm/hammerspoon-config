-- run で呼べる組み込みの Command。コマンドパレットにも並ぶ。
local M = {}

-- 循環参照を避けるため、各モジュールは実行時に読み込む。
local COMMANDS = {
  {
    id = "palette",
    label = "コマンドパレット",
    run = function() require("modules.palette").toggle() end,
  },
  {
    id = "timer",
    label = "タイマー",
    run = function() require("modules.timer").toggle() end,
  },
  {
    id = "reload",
    label = "設定を再読み込み",
    run = function() require("modules.reloader").reload({ force = true }) end,
  },
  {
    id = "console",
    label = "Hammerspoon Console を開く",
    run = function() hs.openConsole() end,
  },
  {
    id = "finder-cut",
    label = "Finder でファイルを切り取り",
    run = function() require("modules.finder_cut").cut() end,
  },
  {
    id = "finder-paste",
    label = "Finder で貼り付け（切り取ったファイルは移動）",
    run = function() require("modules.finder_cut").paste() end,
  },
  {
    id = "remap-off",
    label = "キー変換を一時解除",
    run = function() require("modules.remap").clear() end,
  },
}

local byId = {}
for _, command in ipairs(COMMANDS) do byId[command.id] = command end

function M.get(id)
  return byId[id]
end

function M.all()
  return COMMANDS
end

function M.ids()
  local ids = {}
  for _, command in ipairs(COMMANDS) do table.insert(ids, command.id) end
  return ids
end

return M
