# Hammerspoon Config

この context は、macOS 上で動く Hammerspoon 設定の操作語彙を定義する。shortcut 登録と低レベル入力変換を区別し、設定の意図を読みやすく保つために存在する。

## Language

**Hotkey**:
Hammerspoon の `hs.hotkey.bind` で登録される、修飾キーと通常キーの組み合わせによる shortcut。
_Avoid_: Shortcut, keybinding

**Hotkey Registry**:
有効な Hotkey を検証し、重複を検出して登録する入口。Hotkey が実行する feature の挙動は所有しない。
_Avoid_: Shortcut manager, keybinding manager

**Hotkey Identity**:
Hotkey の重複判定に使う、正規化された `mods + key` の組み合わせ。`mods` の並び順が違っても同じ組み合わせなら同じ Hotkey Identity とみなす。
_Avoid_: Binding key, shortcut id

**Desired Hotkey**:
`init.lua` に宣言される、登録したい Hotkey の設定。Hotkey Registry が検証と登録を行う前の意図を表す。
_Avoid_: Hotkey config, shortcut setting

**App Switcher**:
Desired Hotkey に対応する macOS app を起動、focus、hide、または window cycle する feature。window cycle は各 display で現在表示中の Space を優先し、対象 window がない場合だけ全 Space を対象にする。対象 app と Hotkey の選択は `init.lua` の設定が表す。
_Avoid_: App launcher

**Input Remap**:
物理キーや低レベル入力イベントを別の入力に変換する設定。`eventtap` や `hidutil` に寄るものを含み、Hotkey とは別に扱う。
_Avoid_: Hotkey, shortcut
