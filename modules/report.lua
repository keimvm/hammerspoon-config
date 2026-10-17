-- 設定の問題を、項目の場所（path）とともに集める。
local M = {}

local Report = {}
Report.__index = Report

-- 隣り合う文字の入れ替えも1回の編集と数える編集距離。
local function distance(a, b)
  if a == b then return 0 end
  local beforePrevious, previous = nil, {}
  for j = 0, #b do previous[j] = j end
  for i = 1, #a do
    local current = { [0] = i }
    for j = 1, #b do
      local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
      current[j] = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
      if beforePrevious and j > 1
        and a:sub(i, i) == b:sub(j - 1, j - 1)
        and a:sub(i - 1, i - 1) == b:sub(j, j)
      then
        current[j] = math.min(current[j], beforePrevious[j - 2] + 1)
      end
    end
    beforePrevious, previous = previous, current
  end
  return previous[#b]
end

-- 打ち間違いと思われる場合だけ、最も近い候補を返す。
function M.suggest(word, candidates)
  if type(word) ~= "string" or word == "" then return nil end
  local lowered = string.lower(word)
  local best, bestDistance
  for _, candidate in ipairs(candidates) do
    local d = distance(lowered, string.lower(candidate))
    if not bestDistance or d < bestDistance or (d == bestDistance and candidate < best) then
      best, bestDistance = candidate, d
    end
  end
  if best and bestDistance <= math.max(1, math.floor(#word / 3)) then return best end
  return nil
end

function M.hint(word, candidates)
  local suggestion = M.suggest(word, candidates)
  if not suggestion then return "" end
  return "（もしかして " .. suggestion .. "）"
end

function M.new()
  return setmetatable({ problems = {}, path = "" }, Report)
end

-- 子の場所を指す Report を返す。問題の一覧は親と共有する。
function Report:at(segment)
  local path
  if type(segment) == "number" then
    path = string.format("%s[%d]", self.path, segment)
  elseif self.path == "" then
    path = tostring(segment)
  else
    path = self.path .. "." .. tostring(segment)
  end
  return setmetatable({ problems = self.problems, path = path }, Report)
end

function Report:add(message)
  local path = self.path == "" and "config" or self.path
  table.insert(self.problems, path .. ": " .. message)
  return false
end

function Report:table(value)
  if type(value) == "table" then return true end
  return self:add("テーブル { ... } で指定してください")
end

function Report:string(value)
  if type(value) == "string" and value ~= "" then return true end
  return self:add("空でない文字列を指定してください")
end

-- 1 から順に番号が続くリストであることを確かめる。
function Report:list(value)
  if not self:table(value) then return false end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return self:add("{ ... } に順に並べたリストで指定してください")
    end
    count = count + 1
  end
  for index = 1, count do
    if value[index] == nil then
      return self:add("{ ... } に順に並べたリストで指定してください")
    end
  end
  return true
end

-- 知らない項目名を、打ち間違いの候補とともに報告する。
function Report:fields(value, allowed, positional)
  local names = {}
  local known = {}
  for _, name in ipairs(allowed) do
    known[name] = true
    table.insert(names, name)
  end

  local unknown = {}
  for key in pairs(value) do
    local isPositional = type(key) == "number" and key >= 1 and key <= (positional or 0)
    if not isPositional and not known[key] then table.insert(unknown, key) end
  end
  table.sort(unknown, function(a, b) return tostring(a) < tostring(b) end)

  for _, key in ipairs(unknown) do
    if type(key) == "string" then
      self:at(key):add("不明な項目です" .. M.hint(key, names))
    else
      self:add(string.format("[%s] の値は使えません。項目名 = 値 の形で書いてください", tostring(key)))
    end
  end
  return #unknown == 0
end

return M
