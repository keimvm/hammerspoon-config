-- 画面に出すもの（通知と chooser）の見た目と振る舞いをそろえる。
local M = {}

local MAX_PROBLEM_LINES = 8
local CHOOSER_FG = { red = 0.96, green = 0.97, blue = 0.98, alpha = 1 }
local CHOOSER_SUBTEXT = { red = 0.66, green = 0.70, blue = 0.76, alpha = 1 }

local stickyIds = {}
local dismissTap
local log

local function logger()
  log = log or hs.logger.new("config", "warning")
  return log
end

local function dismissSticky()
  for _, id in ipairs(stickyIds) do
    hs.alert.closeSpecific(id, 0)
  end
  stickyIds = {}

  if dismissTap then
    dismissTap:stop()
    dismissTap = nil
  end
end

-- 少しのあいだだけ表示する。
function M.toast(text, seconds)
  return hs.alert.show(text, seconds or 1.5)
end

-- 画面をクリックするまで表示する。クリックはそのまま対象へ通す。
function M.sticky(text)
  local id = hs.alert.show(text, "indefinite")
  if not id then return nil end

  table.insert(stickyIds, id)
  if dismissTap then return id end

  local types = hs.eventtap.event.types
  dismissTap = hs.eventtap.new({
    types.leftMouseDown,
    types.rightMouseDown,
    types.otherMouseDown,
  }, function()
    dismissSticky()
    return false
  end)
  dismissTap:start()
  return id
end

-- 問題の一覧を Console に残し、先頭の数件を画面に出す。
function M.problems(title, problems)
  logger().e(title)
  for _, problem in ipairs(problems) do logger().e("  " .. problem) end

  local lines = { title }
  for index = 1, math.min(#problems, MAX_PROBLEM_LINES) do
    table.insert(lines, "・" .. problems[index])
  end
  if #problems > MAX_PROBLEM_LINES then
    table.insert(lines, string.format("ほか %d 件は Console を参照してください", #problems - MAX_PROBLEM_LINES))
  end
  return M.sticky(table.concat(lines, "\n"))
end

-- 暗い背景の chooser を作る。options: width, rows, placeholder, searchSubText。
function M.chooser(callback, options)
  options = options or {}
  local chooser = hs.chooser.new(callback)
  chooser:width(options.width or 36)
  chooser:rows(options.rows or 1)
  chooser:bgDark(true)
  chooser:fgColor(CHOOSER_FG)
  chooser:subTextColor(CHOOSER_SUBTEXT)
  if options.placeholder then chooser:placeholderText(options.placeholder) end
  if options.searchSubText then chooser:searchSubText(true) end
  return chooser
end

return M
