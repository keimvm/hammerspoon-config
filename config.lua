-- Hammerspoon の設定。保存すると検証し、問題がなければ自動で再読み込みする。
-- 書き方は docs/configuration.md を参照。
return {
  -- 物理キーの変換（hidutil）。物理キー = "変換後のキー"。
  -- 左右 Command は英数・かなキーとして使い、Command は物理 left_control で押す。
  remap = {
    caps_lock = "left_control",
    left_control = "left_command",
    left_command = "eisu",
    right_command = "kana",
  },

  -- Hotkey と動作。同じ組み合わせは、only / except で範囲を分けない限り二重に書けない。
  hotkeys = {
    -- カーソル移動と削除。長押しで繰り返す。
    { "ctrl+i", send = "up" },
    { "ctrl+j", send = "left" },
    { "ctrl+k", send = "down" },
    { "ctrl+l", send = "right" },
    { "ctrl+h", send = "delete" },
    { "ctrl+d", send = "forwarddelete" },
    { "f5", send = "cmd+r", once = true },

    -- アプリの起動・フォーカス・非表示・ウィンドウの切り替え。
    { "ctrl+m", app = "Typora" },
    { "ctrl+f", app = "Finder" },
    { "ctrl+o", app = "Microsoft Outlook" },
    { "ctrl+t", app = "cmux" },
    { "ctrl+r", app = "Zed" },
    { "ctrl+g", app = "Google Chrome" },

    -- Google Chrome ではブックマーク追加を無効にする。
    { "cmd+d", block = true, only = "Google Chrome" },

    { "ctrl+p", run = "timer" },
    { "ctrl+;", run = "palette" },
  },

  -- アプリが最前面になったら入力ソースを切り替える。
  inputSource = {
    eisu = { "Zed", "cmux", "Visual Studio Code" },
  },

  -- 最前面アプリの Dock アイコンをもう一度クリックすると、そのアプリを非表示にする。
  dockToggle = true,
}
