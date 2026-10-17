-- config.hotkeys の検証と登録。各 Hotkey は Chord と動作（send / app / run / block）を1つずつ持つ。
local appSwitcher = require("modules.app_switcher")
local chord = require("modules.chord")
local commands = require("modules.commands")
local frontmost = require("modules.frontmost")
local report = require("modules.report")
local ui = require("modules.ui")

local M = {}

local ACTIONS = { "send", "app", "run", "block" }
local FIELDS = { "send", "app", "run", "block", "once", "only", "except", "label" }

-- アプリ名1つ、またはアプリ名のリストを受け付ける。
local function appList(value, at)
  if type(value) == "string" then
    if not at:string(value) then return nil end
    value = { value }
  end
  if not at:list(value) then return nil end
  if #value == 0 then
    at:add("アプリ名を1つ以上指定してください")
    return nil
  end

  local apps, set, valid = {}, {}, true
  for index, app in ipairs(value) do
    if not at:at(index):string(app) then
      valid = false
    elseif not set[app] then
      set[app] = true
      table.insert(apps, app)
    end
  end
  if not valid then return nil end
  return apps, set
end

local function scopeOf(entry, at)
  if entry.only ~= nil and entry.except ~= nil then
    at:add("only と except は同時に指定できません")
    return nil, false
  end
  local kind = entry.only ~= nil and "only" or entry.except ~= nil and "except" or nil
  if not kind then return nil, true end

  local apps, set = appList(entry[kind], at:at(kind))
  if not apps then return nil, false end
  return { kind = kind, apps = apps, set = set }, true
end

local function inScope(scope, appName)
  if not scope then return true end
  local listed = appName ~= nil and scope.set[appName] == true
  if scope.kind == "only" then return listed end
  return not listed
end

-- 2つの範囲に、両方の Hotkey が同時に有効になるアプリがあるか。
local function overlaps(a, b)
  if not a or not b then return true end
  if a.kind == "except" and b.kind == "except" then return true end
  if a.kind == "only" and b.kind == "only" then
    for app in pairs(a.set) do
      if b.set[app] then return true end
    end
    return false
  end
  local only, except = a, b
  if a.kind ~= "only" then only, except = b, a end
  for app in pairs(only.set) do
    if not except.set[app] then return true end
  end
  return false
end

local function defaultLabel(hotkey)
  if hotkey.action == "send" then return chord.display(hotkey.target) .. " を送る" end
  if hotkey.action == "app" then return hotkey.target .. " に切り替え" end
  if hotkey.action == "run" then
    if type(hotkey.target) == "string" then return commands.get(hotkey.target).label end
    return "カスタム動作"
  end
  return chord.display(hotkey.chord) .. " を無効化"
end

-- 設定の1項目を、登録に使う形へ変換する。問題は at に報告する。
-- 戻り値は変換結果と、登録できる状態かどうか。動作が不正でも Chord と範囲は重複の確認に使う。
local function compile(entry, at)
  if not at:table(entry) then return nil, false end
  at:fields(entry, FIELDS, 1)

  local parsed, chordError = chord.parse(entry[1])
  if not parsed then at:add(chordError) end

  local scope, scopeValid = scopeOf(entry, at)
  local hotkey = { chord = parsed, scope = scope, scopeValid = scopeValid, once = entry.once == true }
  local valid = parsed ~= nil and scopeValid

  local actions = {}
  for _, action in ipairs(ACTIONS) do
    if entry[action] ~= nil then table.insert(actions, action) end
  end
  if #actions == 0 then
    valid = at:add("動作を1つ指定してください（send / app / run / block）")
  elseif #actions > 1 then
    valid = at:add("動作は1つだけ指定してください（" .. table.concat(actions, " と ") .. "）")
  else
    hotkey.action = actions[1]
  end

  local value = hotkey.action and entry[hotkey.action]
  local valueAt = hotkey.action and at:at(hotkey.action)
  if hotkey.action == "send" then
    local target, sendError = chord.parse(value, { allowFn = true })
    if target then
      hotkey.target = target
    else
      valid = valueAt:add(sendError)
    end
  elseif hotkey.action == "app" then
    valid = valueAt:string(value) and valid
    hotkey.target = value
  elseif hotkey.action == "run" then
    if type(value) == "function" or (type(value) == "string" and commands.get(value)) then
      hotkey.target = value
    elseif type(value) == "string" then
      valid = valueAt:add("不明な Command です: " .. value .. report.hint(value, commands.ids()))
    else
      valid = valueAt:add("Command 名（" .. table.concat(commands.ids(), " / ") .. "）か関数を指定してください")
    end
  elseif hotkey.action == "block" and value ~= true then
    valid = valueAt:add("block = true と書いてください")
  end

  if entry.once ~= nil then
    if type(entry.once) ~= "boolean" then
      valid = at:at("once"):add("true か false を指定してください")
    elseif hotkey.action and hotkey.action ~= "send" then
      valid = at:at("once"):add("once は send と組み合わせて使います")
    end
  end

  if entry.label ~= nil then
    valid = at:at("label"):string(entry.label) and valid
  end

  if valid then hotkey.label = entry.label or defaultLabel(hotkey) end
  return hotkey, valid
end

local function scopeText(scope)
  if not scope then return nil end
  local apps = table.concat(scope.apps, "、")
  if scope.kind == "only" then return apps .. " のみ" end
  return apps .. " 以外"
end

-- パレットなどに出す説明（例: ⌘D · Google Chrome のみ）。
function M.describe(hotkey)
  local text = chord.display(hotkey.chord)
  local scope = scopeText(hotkey.scope)
  if scope then text = text .. " · " .. scope end
  return text
end

function M.validate(list, at)
  if list == nil then return end
  if not at:list(list) then return end

  local registered = {}
  for index, entry in ipairs(list) do
    local itemAt = at:at(index)
    local hotkey = compile(entry, itemAt)
    if hotkey and hotkey.chord and hotkey.scopeValid then
      local id = hotkey.chord.id
      for _, other in ipairs(registered[id] or {}) do
        if overlaps(hotkey.scope, other.scope) then
          itemAt:add(string.format(
            "%s は %s と重複しています。アプリごとに使い分けるなら only / except で範囲を分けてください",
            chord.display(hotkey.chord),
            other.path
          ))
          break
        end
      end
      registered[id] = registered[id] or {}
      table.insert(registered[id], { path = itemAt.path, scope = hotkey.scope })
    end
  end
end

local function actionFor(hotkey)
  if hotkey.action == "send" then
    local target = hotkey.target
    return function() hs.eventtap.keyStroke(target.mods, target.key, 0) end
  elseif hotkey.action == "app" then
    return function() appSwitcher.toggleOrCycle(hotkey.target) end
  elseif hotkey.action == "run" then
    local fn = hotkey.target
    if type(fn) == "string" then fn = commands.get(fn).run end
    return function()
      local ok, err = xpcall(fn, debug.traceback)
      if not ok then ui.problems(hotkey.label .. " でエラーが起きました", { tostring(err) }) end
    end
  end
  return function() end
end

-- 検証済みの設定から Hotkey を登録する。範囲つきの Hotkey は最前面アプリに応じて切り替える。
-- 戻り値は登録できた Hotkey の一覧と、登録できなかった理由の一覧。
function M.start(list)
  local bound, failures, scoped = {}, {}, {}

  for index, entry in ipairs(list or {}) do
    local hotkey, valid = compile(entry, report.new())
    assert(valid, "hotkeys は Config Preflight で検証してから登録してください")
    local run = actionFor(hotkey)
    local repeatFn = (hotkey.action == "send" and not hotkey.once) and run or nil
    local create = hotkey.scope and hs.hotkey.new or hs.hotkey.bind
    local ok, registered = pcall(create, hotkey.chord.mods, hotkey.chord.key, run, nil, repeatFn)

    if ok and registered then
      hotkey.hotkey = registered
      hotkey.run = run
      table.insert(bound, hotkey)
      if hotkey.scope then table.insert(scoped, hotkey) end
    else
      table.insert(failures, string.format(
        "hotkeys[%d]: %s を登録できませんでした（%s）",
        index,
        chord.display(hotkey.chord),
        tostring(registered)
      ))
    end
  end

  if #scoped > 0 then
    frontmost.subscribe(function(appName)
      -- 先に無効化してから有効化し、同じ組み合わせが同時に有効にならないようにする。
      for _, hotkey in ipairs(scoped) do
        if not inScope(hotkey.scope, appName) then hotkey.hotkey:disable() end
      end
      for _, hotkey in ipairs(scoped) do
        if inScope(hotkey.scope, appName) then hotkey.hotkey:enable() end
      end
    end)
  end

  return bound, failures
end

return M
