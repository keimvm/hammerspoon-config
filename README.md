# Hammerspoon Config

macOS 用の個人 Hammerspoon 設定です。Hotkey の宣言は主に `init.lua` に置き、実際の動作は `modules/` 配下の Lua module に分けています。

## 構成

- `init.lua`: 設定の入口。Hotkey、app switcher、入力変換の設定値を管理します。
- `modules/hotkey_registry.lua`: Hotkey metadata の検証と重複検出を行います。
- `modules/bindings.lua`: `init.lua` の設定を app switcher や Unicode converter に接続します。
- `modules/app_switcher.lua`: app の起動、focus、hide、window cycle を扱います。
- `modules/control_layer.lua`: `ctrl` layer の cursor 操作などを扱います。
- `modules/command_keys.lua`: Command key 単体押しを `英数` / `かな` に変換します。
- `modules/hid_remap.lua`: `hidutil` による modifier key remap を適用します。
- `modules/reload.lua`: reload 用 Hotkey の動作を定義します。
- `modules/unicode_converter.lua`: 文字と Unicode code point を相互変換する chooser です。
- `CONTEXT.md`: この repo で使う用語と設計上の境界をまとめています。

## 主な設定

### 入力 remap

読み込み時に `hidutil` で次の modifier remap を適用します。

- `caps_lock` -> `left_control`
- `left_control` -> `left_command`

また、Command key を単体で押して離した場合は JIS keyboard の入力切り替えとして扱います。

- `cmd` -> `英数` (`0x66`)
- `rightcmd` -> `かな` (`0x68`)

### Control layer

`ctrl` と home row で arrow key を送信します。

| Hotkey | 動作 |
| --- | --- |
| `ctrl+i` | `up` |
| `ctrl+j` | `left` |
| `ctrl+k` | `down` |
| `ctrl+l` | `right` |

### App switcher

`ctrl` + 1 key で app を起動、focus、hide、window cycle します。対象 app や key は `init.lua` の `appSwitchers` で管理します。

| Hotkey | App |
| --- | --- |
| `ctrl+m` | MarkEdit |
| `ctrl+f` | Finder |
| `ctrl+o` | メール |
| `ctrl+b` | Google Chrome |
| `ctrl+t` | cmux |
| `ctrl+r` | Codex |
| `ctrl+g` | ChatGPT Atlas |
| `ctrl+n` | Obsidian |

MarkEdit は `~/Desktop/memo` 配下の file をまとめて開く設定になっています。

### Unicode converter

`modules/unicode_converter.lua` は chooser で文字と Unicode code point を相互変換します。現在は `init.lua` の `unicodeConverter.enabled = false` で一時的に無効化しています。

有効化すると `cmd+shift+u` で開き、入力例は次の通りです。

- `あ` -> `U+3042`
- `U+3042` -> `あ`
- `0x1F600` -> `😀`
- `3042` -> `あ`

## 変更するとき

- Hotkey や app 名などの設定値は、まず `init.lua` を変更します。
- 機能の処理は `modules/` に置き、`init.lua` には大きな実装を増やさない方針です。
- 一時的に機能を止めたい場合は、削除せず `enabled = false` で opt-out できる形を優先します。
- Hotkey を追加するときは `id` と `description` を付けます。`modules/hotkey_registry.lua` が重複を検出します。

## 検証

Lua syntax の確認:

```sh
luac -p init.lua modules/*.lua
```

Hammerspoon を起動中なら、設定 reload 後に Console で error が出ていないことも確認します。
