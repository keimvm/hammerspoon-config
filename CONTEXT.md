# Hammerspoon Config

この context は、macOS 上で動く Hammerspoon 設定の操作語彙を定義する。Hotkey と低レベルの入力変換を区別し、設定の意図を読みやすく保つために存在する。

## Language

**Hotkey**:
`config.hotkeys` の1項目。Chord と動作を1つずつ持ち、Hammerspoon に登録される。有効な範囲を持つものは、最前面アプリに応じて有効・無効を切り替える。
_Avoid_: Shortcut, keybinding, Desired Hotkey

**Chord**:
`"ctrl+shift+u"` のように修飾キーとキーを `+` でつないだ表記。Hotkey の組み合わせと `send` の送り先の両方に使う。画面には `⌃⇧U` のような記号で表示する。
_Avoid_: Key combo, shortcut string

**Hotkey Identity**:
Hotkey の重複判定に使う、正規化した Chord（例: `shift+cmd+u`）。修飾キーの別名・並び順・大文字小文字が違っても同じ組み合わせなら同じ Hotkey Identity とみなす。
_Avoid_: Binding key, shortcut id

**Action**:
Hotkey が押されたときの動作。`send`（キー入力を送る）、`app`（App Switcher）、`run`（Command または関数）、`block`（何もしない）の4種類。
_Avoid_: Handler, callback

**Scope**:
Hotkey が有効な範囲。`only` は指定したアプリが最前面の間だけ、`except` は指定したアプリが最前面の間を除いて有効にする。範囲が重ならなければ、同じ Hotkey Identity をアプリごとに使い分けられる。
_Avoid_: Context, condition, App Hotkey Blocker

**Command**:
`run` で名前を指定して呼べる組み込みの動作（`palette`、`timer`、`reload`、`console`、`remap-off`）。コマンドパレットにも並ぶ。
_Avoid_: Action（Hotkey の動作の種類を指す）

**Command Palette**:
登録済みの Hotkey と Command を一覧し、選んで実行する画面。一覧は設定から作るため、Hotkey の早見表を兼ねる。
_Avoid_: Launcher, cheat sheet

**Config Preflight**:
副作用を起こす前に `config.lua` 全体を検証し、問題を項目の場所とともにまとめて返す処理。設定データは変更せず、アプリの存在などの環境は調べない。
_Avoid_: Validation step, lint

**Safe Reload**:
`config.lua` の保存を監視し、Config Preflight に通った場合だけ再読み込みする仕組み。通らなければ今の状態を保ったまま問題を表示する。
_Avoid_: Auto reload, hot reload

**Input Remap**:
物理キーを別のキーとして OS に認識させる設定（`config.remap`）。hidutil の `UserKeyMapping` を使い、Hotkey より手前で働く。
_Avoid_: Hotkey, shortcut

**App Switcher**:
`app` の動作。macOS アプリを起動、focus、hide、または window cycle する。window cycle は各 display で現在表示中の Space を優先し、対象 window がないと確認できた場合だけ全 Space を対象にする。Space の取得失敗は window がない場合と区別する。
_Avoid_: App launcher

**Input Source**:
英数またはかな。`config.inputSource` で、アプリが最前面になったときの切り替え先を指定する。
_Avoid_: layout, input method, keyboard layout

**Timer**:
`timer` Command から開始する、同時に1本だけの one-shot countdown。
_Avoid_: Pomodoro, alarm, reminder
