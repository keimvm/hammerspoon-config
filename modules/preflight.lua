-- Config Preflight。副作用を起こす前に設定全体を検証し、問題をまとめて返す。
-- 設定データは変更せず、アプリがインストール済みかどうかは調べない。
local hotkeys = require("modules.hotkeys")
local inputSource = require("modules.input_source")
local remap = require("modules.remap")
local report = require("modules.report")

local M = {}

local SECTIONS = { "remap", "hotkeys", "inputSource" }

function M.check(config)
  local root = report.new()
  if type(config) ~= "table" then
    root:add("config.lua は設定のテーブルを return してください")
    return root.problems
  end

  root:fields(config, SECTIONS)
  remap.validate(config.remap, root:at("remap"))
  hotkeys.validate(config.hotkeys, root:at("hotkeys"))
  inputSource.validate(config.inputSource, root:at("inputSource"))
  return root.problems
end

-- source は config.lua のパス、または設定テーブル。
-- 成功時は設定と空の一覧を、失敗時は nil と問題の一覧を返す。
function M.load(source)
  local config = source
  if type(source) == "string" then
    local chunk, loadError = loadfile(source)
    if not chunk then return nil, { "config.lua を読み込めません: " .. tostring(loadError) } end

    local ok, result = pcall(chunk)
    if not ok then return nil, { "config.lua の実行中にエラーが起きました: " .. tostring(result) } end
    config = result
  end

  local problems = M.check(config)
  if #problems > 0 then return nil, problems end
  return config, problems
end

return M
