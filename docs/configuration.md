# 設定ガイド

[init.lua](../init.lua) の `config` を編集します。ここに記載する初期設定を変更済みの場合は、実際の `config` を読み替えてください。導入、設定の反映、操作を戻す手順は [README](../README.md) にあります。

## 共通ルール

Hotkey の設定では `mods` と `key` を指定します。`mods` は `{ "ctrl" }` のように明示し、修飾キーが不要な場合は `{}` にします。省略時の値は機能ごとに異なります。`id` は省略でき、各機能が設定から補います。

- 修飾キーには `ctrl`、`alt`、`shift`、`cmd` を使います。`control`、`option`、`command` も使えます。
- `fn` はこの設定の Hotkey では使用できません。Control Layer の送り先の `to.mods` には使えます。
- 有効な Hotkey どうしで、正規化した `mods + key`（Hotkey Identity）を重複させないでください。修飾キーの並び順、別名、重複表記を変えても同じ組み合わせとして扱います。
- `id` は無効な設定も含めて重複できません。自動で補われる `id` が重複する場合は、別の `id` を明示します。
- `bindings`、`mappings`、アプリのリスト、`mods` は `{ ... }` で順に並べます。辞書形式や途中の番号が抜けたリストは使えません。

`enabled` を省略すると有効です。無効にする位置は機能ごとに異なります。

| 無効にする対象 | `enabled = false` を指定する位置 |
| --- | --- |
| Input Remap | `config.hidRemap` |
| Command キーの単体押し | `config.commandKeys` |
| Control Layer | `config.controlLayer.bindings` の対象項目 |
| App Hotkey Blocker / App Switcher | 各リストの対象項目 |
| App Input Source | `config.appInputSources`、またはその `bindings` の対象項目 |
| Unicode Converter / Timer | `config.unicodeConverter` / `config.timer` |

無効な設定も形式の検証対象です。削除する場合は、リストの対象項目を取り除きます。

## Input Remap

`config.hidRemap.mappings` に、物理キーの変換元 `from` と変換先 `to` を指定します。使えるキーは `caps_lock`、`left_control`、`left_command` です。同じ `from` を二重には指定できません。

```lua
{ from = "caps_lock", to = "left_control" },
```

初期設定は `caps_lock` → `left_control`、`left_control` → `left_command` です。`config.hidRemap.enabled = false` にして再読み込みすると、`UserKeyMapping` を空にして変換を解除します。

## Command キーの単体押し

`config.commandKeys.bindings` に対象の Command キーと送信するキーコードを指定します。

```lua
{ commandKey = "cmd", outputKeyCode = 0x66 },
{ commandKey = "rightcmd", outputKeyCode = 0x68 },
```

`commandKey` は `cmd` / `rightcmd`、`outputKeyCode` は 0〜65535 の整数です。同じ `commandKey` を二重には指定できません。初期設定は JIS キーボードの英数・かなです。ほかのキーと組み合わせた場合は、単体押しの入力切り替えを行いません。

## Control Layer

`config.controlLayer.bindings` に、Hotkey と送り先の `to` を指定します。

```lua
{ mods = { "ctrl" }, key = "h", to = "delete" },
{ mods = {}, key = "F5", to = { mods = { "cmd" }, key = "r" }, repeatable = false },
```

`to` はキー名、または `mods` と `key` を持つテーブルです。後方削除は `delete`、前方削除は `forwarddelete` です。長押しを繰り返し入力にしない場合は `repeatable = false` を指定します。`id` は省略時に `to` から補います。

初期設定は `ctrl+i/j/k/l` で矢印、`ctrl+h/d` で後方・前方削除、`F5` で `cmd+r` の送信です。

## App Hotkey Blocker

`config.appHotkeyBlockers` はアプリごとの設定を並べたリストです。対象アプリが最前面の間だけ、その Hotkey でアプリ本来の操作を無効にします。

```lua
{ appName = "Google Chrome", mods = { "cmd" }, key = "d" },
```

`appName` は実際のアプリ名に合わせます。Chrome Beta など、別名のアプリでは変更が必要です。

## App Switcher

`config.appSwitchers` に対象アプリの `appName` と Hotkey を指定します。

```lua
{ appName = "Zed", mods = { "ctrl" }, key = "r" },
```

対象を変えるときは `appName`、割り当てを変えるときは `mods` と `key` を編集します。追加する場合は既存の Hotkey と重複させないでください。

- 未起動ならアプリを起動します。
- ウィンドウがなければ、アプリに再表示を要求します。Finder が最前面でデスクトップだけが表示されている場合も対象です。
- 現在表示中の Space の対象ウィンドウが最前面なら、別の Space のウィンドウも含めてアプリ全体を非表示にします。Finder のデスクトップだけが最前面の場合や、対象ウィンドウが最小化されている場合は、非表示にせず対象ウィンドウを選びます。
- それ以外は対象ウィンドウにフォーカスします。候補が複数ある場合は、前回の対象に続くウィンドウへ順に切り替えます。

候補は各ディスプレイで現在表示中の Space を優先し、最小化したウィンドウも対象にします。その範囲に候補がなく、別の Space にだけある場合は、そちらへ移動します。Finder のウィンドウが通常ウィンドウとして判定されなくても候補に含め、デスクトップ自体は除外します。選んだウィンドウを再表示前に指定し、アプリ全体の前面化を先に行わないようにしています。

ID が無効な要素や補助パネルは候補から外します。Space の所属一覧が空の要素（非表示タブなど）も除外し、所属が確認できるウィンドウから選ぶため、補助要素が混ざっていても別 Space へ移動できます。ウィンドウ一覧が空の場合は、アプリのメインウィンドウとフォーカス対象も確認してから新規表示を判断します。

Space 情報の取得そのものが失敗した場合は、現在の Space にあると確認できた候補だけを使います。その候補もない場合や、どの候補にも所属 Space がない場合は切り替えず、もう一度 Hotkey を押すよう案内します。

## App Input Source

`config.appInputSources.bindings` に対象アプリと入力ソースを指定します。

```lua
{ appName = "Zed", source = "eisu" },
```

`source` は `eisu`（英数）または `kana`（かな）です。対象アプリが最前面になったときと、設定の読み込み時にすでに最前面だった場合に切り替えます。初期設定の対象は Zed、cmux、Visual Studio Code で、いずれも英数です。対象外のアプリでは入力ソースを変更しません。

## Unicode Converter

初期設定では無効です。`config.unicodeConverter.enabled = true` にすると、`cmd+shift+u` で変換画面を開きます。割り当ては `mods` と `key` で変更できます。

文字とコードポイントを相互変換します。例は `あ` ↔ `U+3042` で、コードポイントは `U+3042`、`0x3042`、`3042` の形式を受け付けます。

## Timer

初期設定は `ctrl+p` で入力画面を開きます。割り当ては `config.timer.mods` と `key` で変更できます。

- 数値を入力して Enter で開始します。既定の単位は分（1〜180）です。
- `Tab` で数値を保ったまま秒（1〜10800）と分を切り替えます。`s` / `m` でも切り替えられ、数字とこれらの文字以外は受け付けません。
- メニューバーに残り時間を表示します。クリックして「キャンセル」を選ぶと停止します。
- 同時に動く Timer は1本です。新しく開始すると前の Timer を置き換え、**Reload Config** でも実行中の Timer は破棄されます。
- 完了時は `Tink` を音量設定 `0.25` で1回再生し、経過時間を表示します。表示は画面をクリックするまで残ります。

## Config Preflight でエラーになったとき

設定全体の検証は Hotkey の登録や入力変換の開始前に行います。不備は `invalid Hammerspoon config:` の下に、`config...` の項目名とともにまとめて表示されます。

`duplicates Hotkey Identity` は有効な割り当ての重複です。置き換えが目的なら、項目を追加せず元の項目を編集します。`id` の重複や不正な値も、表示された項目を修正してください。検証は設定データを変更せず、対象アプリがインストール済みかどうかは調べません。

修正後は [変更を反映する](../README.md#変更を反映する) に沿って再確認します。
