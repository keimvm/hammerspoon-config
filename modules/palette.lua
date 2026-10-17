-- コマンドパレット。登録済みの Hotkey と組み込み Command を一覧し、選ぶと実行する。
-- 一覧は設定から作るため、Hotkey の早見表としても使える。
local commands = require("modules.commands")
local hotkeys = require("modules.hotkeys")
local ui = require("modules.ui")

local M = {}

-- chooser を閉じて元のアプリへフォーカスが戻ってから実行する。
local RUN_DELAY_SECONDS = 0.05

local bound = {}
local actions = {}
local chooser
local visible = false
local pendingRun -- 実行前に timer が回収されないよう保持する。

function M.use(list)
  bound = list or {}
end

local function addRow(rows, text, subText, run)
  table.insert(actions, run)
  table.insert(rows, { text = text, subText = subText, action = #actions })
end

local function buildRows()
  local rows = {}
  actions = {}

  local boundCommands = {}
  for _, hotkey in ipairs(bound) do
    if hotkey.action == "run" and type(hotkey.target) == "string" then
      boundCommands[hotkey.target] = true
    end
    if not (hotkey.action == "run" and hotkey.target == "palette") then
      addRow(rows, hotkey.label, hotkeys.describe(hotkey), hotkey.run)
    end
  end

  local remaining = require("modules.timer").remainingText()
  if remaining then
    addRow(rows, "タイマーを停止", "残り " .. remaining, function()
      require("modules.timer").cancel()
    end)
  end

  for _, command in ipairs(commands.all()) do
    if command.id ~= "palette" and not boundCommands[command.id] then
      addRow(rows, command.label, "Hotkey なし", command.run)
    end
  end
  return rows
end

local function ensureChooser()
  if chooser then return chooser end

  chooser = ui.chooser(function(choice)
    visible = false
    if not choice or not actions[choice.action] then return end
    pendingRun = hs.timer.doAfter(RUN_DELAY_SECONDS, actions[choice.action])
  end, {
    width = 40,
    rows = 12,
    placeholder = "Hotkey と Command を検索",
    searchSubText = true,
  })
  return chooser
end

function M.show()
  local c = ensureChooser()
  c:choices(buildRows())
  c:query("")
  c:show()
  visible = true
end

function M.hide()
  if chooser then chooser:hide() end
  visible = false
end

function M.toggle()
  if visible then
    M.hide()
  else
    M.show()
  end
end

return M
