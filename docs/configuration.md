# 設定ガイド

設定は [config.lua](../config.lua) の1ファイルに書きます。導入方法、初期設定の割り当て、困ったときの対処は [README](../README.md) を参照してください。

## 書き方の基本

`config.lua` は Lua のファイルで、設定のテーブル（`{ ... }`）を `return` します。項目は `remap`、`hotkeys`、`inputSource` の3つで、どれも省略できます。

```lua
return {
  remap = { caps_lock = "left_control" },
  hotkeys = {
    { "ctrl+m", app = "Typora" },
  },
  inputSource = { eisu = { "Zed" } },
}
```

- 文字列は半角の `"` で囲みます。`“ ”` のような引用符では動きません。
- 項目は `,` で区切ります。最後の項目の後ろに `,` があっても構いません。
- `--` から行末まではコメントです。行頭に `--` を付けると、その行を一時的に無効にできます。

## 保存と再読み込み

`config.lua` を保存すると、設定全体を検証（Config Preflight）してから反映します。

- 問題がなければ再読み込みし、「設定を再読み込みしました（Hotkey ○ 件）」と表示します。
- 問題があれば再読み込みせず、今の設定のまま問題の一覧を表示します。一覧は画面をクリックすると消え、全文は Hammerspoon Console に残ります。
- 内容が変わっていない保存では何もしません。
- 起動時に問題があった場合は何も適用しません。直して保存すれば、その時点で適用します。

問題は `hotkeys[3].app: 空でない文字列を指定してください` のように、項目の場所とともにまとめて表示します。`hotkeys[3]` は `hotkeys` の3番目の項目です。打ち間違いと思われる名前には `（もしかして only）` のように候補を添えます。検証は書き方だけを確かめ、アプリがインストール済みかどうかは調べません。

自動で再読み込みするのは `config.lua` を保存したときだけです。`init.lua` や `modules/` を変えた場合は、コマンドパレットの「設定を再読み込み」か、Hammerspoon のメニューの **Reload Config** を使います。どちらの再読み込みでも、`config.lua` に加えて `init.lua` と読み込み済みモジュールの構文を先に確かめます。

## remap（物理キーの変換）

`物理キー = "変換後のキー"` の形で書きます。hidutil の `UserKeyMapping` として OS に設定するため、Hotkey より手前で変換され、すべてのキーボードに働きます。

```lua
remap = {
  caps_lock = "left_control",
  left_control = "left_command",
  left_command = "eisu",
  right_command = "kana",
},
```

- 使えるキー: `caps_lock`、`escape`、`tab`、`space`、`return`、`delete`（後方削除）、`forwarddelete`、`left_control`、`left_shift`、`left_option`、`left_command`、`right_control`、`right_shift`、`right_option`、`right_command`、`eisu`（英数キー）、`kana`（かなキー）。
- 変換は連鎖しません。上の例では、物理 `caps_lock` は `left_control` になり、`left_command` にはなりません。
- `remap = {}` と書くと、読み込むたびに変換を解除します。`remap` 自体を書かなければ、hidutil の設定に触りません。
- 変換は Hammerspoon を終了しても残り、Mac を再起動すると消えます。

## hotkeys（Hotkey と動作）

1項目に1つの Hotkey を書きます。先頭に Chord（`"ctrl+i"` のようなキーの組み合わせ）を書き、続けて動作を1つ指定します。

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

- 修飾キーとキーを `+` でつなぎます。修飾キーは `ctrl`、`alt`、`shift`、`cmd` です。`control`、`option`、`opt`、`command`、`⌃`、`⌥`、`⇧`、`⌘` とも書けます。大文字小文字と並び順は問いません。
- 修飾キーなしでも書けます（例: `"f5"`）。
- キー名は Hammerspoon の `hs.keycodes.map` の名前です。例: `a`〜`z`、`0`〜`9`、`;`、`` ` ``、`f1` などのファンクションキー、`up` `down` `left` `right`、`delete`（後方削除）、`forwarddelete`、`return`、`escape`、`tab`、`space`、`home`、`end`、`pageup`、`pagedown`。
- `fn` は Hotkey には使えません。`send` の送り先には使えます。
- `remap` で変換した後のキーで書きます。初期設定では、物理 Caps Lock は `ctrl`、物理の左 Control は `cmd` です。

### 動作

| 動作 | 例 | 内容 |
| --- | --- | --- |
| `send` | `send = "cmd+r"` | 最前面のアプリへキー入力を送る。長押しで繰り返す。`once = true` を付けると繰り返さない |
| `app` | `app = "Typora"` | アプリを起動・前面化・非表示・ウィンドウ切り替えする（[App Switcher](#app-switcherapp)） |
| `run` | `run = "timer"` | 組み込みの Command か、Lua の関数を実行する |
| `block` | `block = true` | 何もしない。`only` と組み合わせて、アプリ本来のショートカットを無効にする |

`run` に指定できる Command は次のとおりです。

| Command | 内容 |
| --- | --- |
| `palette` | コマンドパレットを開く |
| `timer` | タイマーの入力画面を開く |
| `reload` | 設定を検証して再読み込みする |
| `console` | Hammerspoon Console を開く |
| `remap-off` | キー変換を一時的に解除する（再読み込みで戻る） |

関数も渡せます。関数でエラーが起きたときは、`label` の名前とともに画面に表示します。

```lua
{ "ctrl+shift+c", run = function() hs.pasteboard.setContents(os.date("%Y-%m-%d")) end, label = "今日の日付をコピー" },
```

### 有効な範囲（only / except）

`only` を付けると、指定したアプリが最前面の間だけ有効になります。`except` を付けると、指定したアプリが最前面の間は無効になり、アプリ本来の操作が動きます。アプリ名1つか、アプリ名のリストを指定します。`only` と `except` は同時に使えません。

```lua
{ "cmd+d", block = true, only = "Google Chrome" },
{ "ctrl+r", app = "Zed", except = { "ターミナル", "cmux" } },
```

### 重複

同じ組み合わせ（Hotkey Identity）は二重に書けません。`"Command+Shift+U"` と `"shift+cmd+u"` のように表記が違っても、同じ組み合わせとみなします。ただし、`only` / `except` で有効な範囲が重ならなければ、同じ組み合わせをアプリごとに使い分けられます。

```lua
{ "ctrl+r", app = "Zed", except = "Google Chrome" },
{ "ctrl+r", send = "cmd+r", only = "Google Chrome" },
```

### 表示名

コマンドパレットに出る名前は、動作から決まります（例: 「↑ を送る」「Typora に切り替え」）。`label = "エディタ"` のように書くと変えられます。

## アプリ名の書き方

`app`、`only`、`except`、`inputSource` にはアプリの名前を書きます。

- **`app`**: アプリのファイル名から `.app` を除いたものを書きます（例: `"Google Chrome"`、`"Visual Studio Code"`）。macOS 付属のアプリは、Finder で日本語の名前に見えてもファイル名は英語です（例: ターミナルは `"Terminal"`）。ファイル名は `ls /Applications /System/Applications /System/Applications/Utilities` で確かめられます。このようにファイル名と表示名が違うアプリでは、起動と前面化はできても、非表示とウィンドウの切り替えが働かない場合があります。
- **`only`、`except`、`inputSource`**: 最前面アプリの名前と完全に一致するかで判定します。macOS 付属のアプリは日本語の名前になることがあります（例: `"ターミナル"`）。Chrome Beta のように別名のアプリには、その名前を書きます。

最前面アプリの名前は、Hammerspoon Console（メニューの **Console...**）で次を実行し、3秒以内に対象のアプリを前面にすると表示されます。

```lua
hs.timer.doAfter(3, function() print(hs.application.frontmostApplication():name()) end)
```

## inputSource（アプリごとの入力ソース）

アプリが最前面になったとき、英数キーかかなキーを送って入力ソースを切り替えます。設定の読み込み時にすでに最前面だったアプリでも切り替えます。

```lua
inputSource = {
  eisu = { "Zed", "cmux", "Visual Studio Code" },
  kana = { "Typora" },
},
```

同じアプリを `eisu` と `kana` の両方に書くことはできません。どちらにもないアプリでは、入力ソースを変えません。かなに切り替えるには、日本語の入力ソースが追加されている必要があります。

## App Switcher（app）

`app` の Hotkey を押すと、状況に応じて次のように動きます。

| 状況 | 動作 |
| --- | --- |
| アプリが起動していない | 起動する |
| 起動しているが、ウィンドウがない | ウィンドウを開くようアプリに求める（Finder なら新しいウィンドウが開く） |
| 今の Space にあるそのアプリのウィンドウが最前面 | アプリ全体を非表示にする |
| それ以外 | ウィンドウを前面に出す。複数あれば、押すたびに次のウィンドウへ切り替える |

- 候補は、各ディスプレイで今表示している Space のウィンドウを優先します。最小化したウィンドウも候補に含めます。
- 今の Space に候補がなく、別の Space にだけある場合は、その Space へ移動します。
- Space の情報を取得できなかった場合は、誤って別の Space へ移動しないよう切り替えをやめ、「もう一度押してください」と表示します。

## タイマー（run = "timer"）

- 数値を入力して Enter で開始します。単位は分（1〜180）です。
- `Tab` を押すと、入力した数値を保ったまま秒（1〜10800）と分を切り替えます。`s` / `m` を入力しても切り替わります。数字とこれらの文字以外は受け付けません。
- 実行中はメニューバーに残り時間を表示します。メニューバーの「キャンセル」か、コマンドパレットの「タイマーを停止」で止めます。
- 同時に動くタイマーは1本だけです。新しく開始すると前のタイマーは止まります。再読み込みすると、実行中のタイマーは破棄されます。
- 時間になると `Tink` の音を小さく1回鳴らし、経過時間を表示します。表示は画面をクリックするまで残ります。

## コマンドパレット（run = "palette"）

`config.lua` の Hotkey と、組み込みの Command を一覧します。各行には `⌃M` や `⌘D · Google Chrome のみ` のように Hotkey と有効な範囲が出るため、早見表として使えます。名前や説明（アプリ名など）で絞り込み、Enter で実行します。Esc か、もう一度パレットの Hotkey を押すと閉じます。

- Hotkey のない Command（「設定を再読み込み」など）も並びます。
- タイマーの実行中は「タイマーを停止」が残り時間とともに並びます。
- 選んだ動作は、パレットが閉じて元のアプリへフォーカスが戻ってから実行します。
