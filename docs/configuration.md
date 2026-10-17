# 設定ガイド

設定は [config.lua](../config.lua) に書きます。`config.lua` は設定のテーブルを `return` し、`remap`、`hotkeys`、`inputSource` の3項目を持ちます。どれも省略できます。導入と操作を戻す手順は [README](../README.md) にあります。

```lua
return {
  remap = { caps_lock = "left_control" },
  hotkeys = {
    { "ctrl+m", app = "Typora" },
  },
  inputSource = { eisu = { "Zed" } },
}
```

## 保存と再読み込み

`config.lua` を保存すると、Config Preflight で設定全体を検証します。

- 問題がなければ再読み込みし、「設定を再読み込みしました（Hotkey ○ 件）」と表示します。
- 問題があれば再読み込みせず、今の設定のまま問題の一覧を表示します。一覧は画面をクリックすると消え、全文は Hammerspoon Console に残ります。
- 内容が変わっていない保存では何もしません。
- 起動時に設定に問題があった場合は何も適用しません。直して保存すれば、そのまま適用されます。

問題は `hotkeys[3].app: 空でない文字列を指定してください` のように、項目の場所とともにまとめて表示します。打ち間違いと思われる名前には `（もしかして only）` のように候補を添えます。検証は設定データを変更せず、アプリがインストール済みかどうかは調べません。

自動で再読み込みするのは `config.lua` の保存だけです。`modules/` や `init.lua` を変えた場合は、コマンドパレットの「設定を再読み込み」か、Hammerspoon のメニューの **Reload Config** を使います。パレットからの再読み込みも、先に設定と読み込み済みモジュールの構文を検証します。

## remap（物理キーの変換）

`物理キー = "変換後のキー"` の形で書きます。hidutil の `UserKeyMapping` として OS に設定するため、Hammerspoon の Hotkey より手前で変換されます。

```lua
remap = {
  caps_lock = "left_control",
  left_control = "left_command",
  left_command = "eisu",
  right_command = "kana",
},
```

- 使えるキー: `caps_lock`、`escape`、`tab`、`space`、`return`、`delete`（後方削除）、`forwarddelete`、`left_control`、`left_shift`、`left_option`、`left_command`、`right_control`、`right_shift`、`right_option`、`right_command`、`eisu`（英数キー）、`kana`（かなキー）。
- 変換は連鎖しません。上の例では物理 `caps_lock` は `left_control` になり、`left_command` にはなりません。
- `remap = {}` にすると変換を解除します。`remap` 自体を書かなければ、hidutil の設定に触りません。

初期設定では左右 Command を英数・かなキーとして使い、Command は物理 `left_control` で押します。

## hotkeys（Hotkey と動作）

1項目に1つの Hotkey を書きます。先頭に Chord（`"ctrl+i"` のようなキーの組み合わせ）、続けて動作を1つ指定します。

```lua
hotkeys = {
  { "ctrl+i", send = "up" },
  { "f5", send = "cmd+r", once = true },
  { "ctrl+m", app = "Typora" },
  { "cmd+d", block = true, only = "Google Chrome" },
  { "ctrl+p", run = "timer" },
  { "ctrl+;", run = "palette" },
},
```

### Chord の書き方

- 修飾キーとキーを `+` でつなぎます。修飾キーは `ctrl`、`alt`、`shift`、`cmd` で、`control`、`option`、`opt`、`command`、`⌃`、`⌥`、`⇧`、`⌘` も使えます。大文字小文字と並び順は問いません。
- 修飾キーなしでも書けます（例: `"f5"`）。
- キー名は Hammerspoon の `hs.keycodes.map` の名前です。例: `a`〜`z`、`0`〜`9`、`;`、`` ` ``、`f1` などのファンクションキー、`up` `down` `left` `right`、`delete`（後方削除）、`forwarddelete`、`return`、`escape`、`tab`、`space`、`home`、`end`、`pageup`、`pagedown`。
- `fn` は Hotkey には使えません。`send` の送り先には使えます。

### 動作

| 動作 | 例 | 内容 |
| --- | --- | --- |
| `send` | `send = "cmd+r"` | 最前面のアプリへキー入力を送る。長押しで繰り返す。`once = true` なら繰り返さない |
| `app` | `app = "Typora"` | App Switcher。アプリを起動・フォーカス・非表示・ウィンドウ切り替えする |
| `run` | `run = "timer"` | 組み込みの Command、または Lua の関数を実行する |
| `block` | `block = true` | 何もしない。アプリ本来のショートカットを無効にするときに `only` と組み合わせる |

`run` に指定できる Command は次のとおりです。関数を渡すこともでき、失敗したときは `label` の名前とともにエラーを表示します。

| Command | 内容 |
| --- | --- |
| `palette` | コマンドパレットを開く |
| `timer` | タイマーの入力画面を開く |
| `reload` | 設定を検証して再読み込みする |
| `console` | Hammerspoon Console を開く |
| `remap-off` | キー変換を一時的に解除する（再読み込みで戻る） |

### 有効な範囲（only / except）

`only` を付けると、そのアプリが最前面の間だけ有効になります。`except` を付けると、そのアプリが最前面の間は無効になり、アプリ本来の操作が動きます。アプリ名1つか、アプリ名のリストを指定します。

```lua
{ "cmd+d", block = true, only = "Google Chrome" },
{ "ctrl+d", send = "forwarddelete", except = { "cmux", "Terminal" } },
```

アプリ名は最前面アプリの表示名と比べます。Chrome Beta のように別名のアプリには、その名前を書きます。

### 重複

同じ組み合わせ（Hotkey Identity）は二重に書けません。`"Command+Shift+U"` と `"shift+cmd+u"` のように表記が違っても同じとみなします。ただし、`only` / `except` で有効な範囲が重ならなければ、同じ組み合わせをアプリごとに使い分けられます。

```lua
{ "ctrl+r", app = "Zed", except = "Google Chrome" },
{ "ctrl+r", send = "cmd+r", only = "Google Chrome" },
```

### 表示名

コマンドパレットに出る名前は動作から決まります（例: 「↑ を送る」「Typora に切り替え」）。`label = "エディタ"` で変えられます。

## inputSource（アプリごとの入力ソース）

アプリが最前面になったとき、英数・かなキーを送って入力ソースを切り替えます。設定の読み込み時にすでに最前面だった場合も切り替えます。

```lua
inputSource = {
  eisu = { "Zed", "cmux", "Visual Studio Code" },
  kana = { "Typora" },
},
```

同じアプリを両方に書くことはできません。どちらにもないアプリでは入力ソースを変更しません。

## App Switcher（app）

- 未起動ならアプリを起動します。
- ウィンドウがなければ、アプリに再表示を要求します。Finder が最前面でデスクトップだけが表示されている場合も対象です。
- 現在表示中の Space の対象ウィンドウが最前面なら、別の Space のウィンドウも含めてアプリ全体を非表示にします。Finder のデスクトップだけが最前面の場合や、対象ウィンドウが最小化されている場合は、非表示にせず対象ウィンドウを選びます。
- それ以外は対象ウィンドウにフォーカスします。候補が複数ある場合は、前回の対象に続くウィンドウへ順に切り替えます。

候補は各ディスプレイで現在表示中の Space を優先し、最小化したウィンドウも対象にします。その範囲に候補がなく、別の Space にだけある場合は、そちらへ移動します。Finder のウィンドウが通常ウィンドウとして判定されなくても候補に含め、デスクトップ自体は除外します。選んだウィンドウを再表示前に指定し、アプリ全体の前面化を先に行わないようにしています。

ID が無効な要素や補助パネルは候補から外します。Space の所属一覧が空の要素（非表示タブなど）も除外し、所属が確認できるウィンドウから選ぶため、補助要素が混ざっていても別 Space へ移動できます。ウィンドウ一覧が空の場合は、アプリのメインウィンドウとフォーカス対象も確認してから新規表示を判断します。

Space 情報の取得そのものが失敗した場合は、現在の Space にあると確認できた候補だけを使います。その候補もない場合や、どの候補にも所属 Space がない場合は切り替えず、もう一度 Hotkey を押すよう案内します。

## タイマー（run = "timer"）

- 数値を入力して Enter で開始します。既定の単位は分（1〜180）です。
- `Tab` で数値を保ったまま秒（1〜10800）と分を切り替えます。`s` / `m` でも切り替えられ、数字とこれらの文字以外は受け付けません。
- メニューバーに残り時間を表示します。メニューの「キャンセル」か、コマンドパレットの「タイマーを停止」で止めます。
- 同時に動くタイマーは1本です。新しく開始すると前のタイマーを置き換え、再読み込みすると実行中のタイマーは破棄されます。
- 完了時は `Tink` を音量 `0.25` で1回鳴らし、経過時間を表示します。表示は画面をクリックするまで残ります。

## コマンドパレット（run = "palette"）

`config.lua` の Hotkey と組み込みの Command を一覧します。各行には `⌃M` や `⌘D · Google Chrome のみ` のように Hotkey と有効な範囲を表示するため、早見表として使えます。名前や説明（アプリ名など）で絞り込み、Enter で実行します。

- Hotkey のない Command（「設定を再読み込み」など）も並びます。
- タイマーの実行中は「タイマーを停止」と残り時間が並びます。
- 選んだ動作は、パレットが閉じて元のアプリへフォーカスが戻ってから実行します。
