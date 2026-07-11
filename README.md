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
- `docs/strategy/codebase-improvement.md`: 安全に変更できる codebase へ改善するための方針とマイルストーンです。

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
| `ctrl+b` | Safari |
| `ctrl+t` | cmux |
| `ctrl+r` | ChatGPT |
| `ctrl+g` | Google Chrome |
| `ctrl+n` | Obsidian |

MarkEdit は `~/Desktop/memo` 配下の file をまとめて開く設定になっています。

### Unicode converter

`modules/unicode_converter.lua` は chooser で文字と Unicode code point を相互変換します。現在は `init.lua` の `unicodeConverter.enabled = false` で一時的に無効化しています。

有効化すると `cmd+shift+u` で開き、入力例は次の通りです。

- `あ` -> `U+3042`
- `U+3042` -> `あ`
- `0x1F600` -> `😀`
- `3042` -> `あ`

## App Switcher の設定を変更するとき

App Switcher の設定値は `init.lua` の `config.appSwitchers` で管理します。各 entry は次の形です。

```lua
{
  id = "app-switcher.safari",
  description = "Safari を切り替える",
  appName = "Safari",
  mods = { "ctrl" },
  key = "b",
  enabled = true,
  -- dirToOpen = home .. "/Desktop/memo",
},
```

| Field | 意味 |
| --- | --- |
| `id` | repo 内で Hotkey を識別する一意な文字列。app や用途が分かる名前にします。 |
| `description` | Hotkey の目的を表す説明。重複 error の特定にも使われます。 |
| `appName` | Hammerspoon が起動・検索する macOS app 名。通常は `.app` を除いた名前です。 |
| `mods` | modifier key の配列。例: `{ "ctrl" }`、`{ "cmd", "shift" }`。 |
| `key` | modifier と組み合わせる key。例: `"b"`。 |
| `enabled` | `false` のとき Hotkey を登録しません。省略時と `true` は有効です。 |
| `dirToOpen` | 任意。未起動時に指定 directory 直下の file を対象 app で開きます。利用できない場合は通常起動へ fallback します。 |

`appName` は `/Applications` または `~/Applications` にある app bundle 名に合わせます。たとえば `/Applications/ChatGPT.app` なら `appName = "ChatGPT"` です。名前が分からない場合は Finder で app を選び、表示名または bundle の file 名を確認してください。`ChatGPT` と `ChatGPT Atlas` のように別 bundle の app は同じものとして扱いません。

変更方法は次の通りです。

- 既存の割り当てを変更する: 対象 entry の `id`、`description`、`appName`、`mods`、`key` を新しい組み合わせにそろえます。必要な場合だけ `dirToOpen` も変更します。
- 新しい割り当てを追加する: 既存 entry を 1 件コピーして `config.appSwitchers` 内へ追加し、一意な `id` と未使用の `mods` + `key` を設定します。
- 一時的に無効化する: 対象 entry に `enabled = false` を追加します。再度使うときは `true` に戻すか field を削除します。
- 完全に削除する: 対象の `{ ... }` entry 全体を `config.appSwitchers` から削除します。使わない設定を disabled entry やコメントとして残す必要はありません。

`mods` の順序が違っても、同じ modifier と `key` の組み合わせは同じ **Hotkey Identity** です。有効な entry 間で Hotkey Identity が重複すると、Config Preflight が reload を拒否し、途中まで新しい Hotkey を登録することもありません。Console の `duplicates Hotkey Identity` error に表示された field path を直してから、もう一度 reload してください。

## 検証

変更後は Automated Verification、Manual Runtime Verification の順で実行します。まず repo root で次を実行します。

```sh
./scripts/check
```

この command は Lua syntax、production Lua file の tracked state、fake `hs` による behavior contract を検証します。

成功したら次を実機で確認します。

1. Hammerspoon menu の **Reload Config** を実行する。
2. Hammerspoon Console に error がないことを確認する。Config Preflight error が出た場合は、表示された field path を修正してから再度 **Reload Config** を実行する。
3. 対象 app を終了し、App Switcher Hotkey で正しい app が起動することを確認する。
4. 対象 app が frontmost の状態で同じ Hotkey を押し、app が hide されることを確認する。
5. 対象 app が起動中かつ非 frontmost の状態で同じ Hotkey を押し、focus されることを確認する。
6. 対象 app に複数 window がある場合、同じ Hotkey で focus 対象が cycle することを確認する。
7. `dirToOpen` を設定した場合、directory が利用できると file が開き、利用できなくても app が通常起動することを確認する。

現在の既定割り当てを変更した場合は、少なくとも `ctrl+b` の Safari、`ctrl+g` の Google Chrome、`ctrl+r` の `ChatGPT.app` で上記を確認します。全機能の実機 checklist は [`docs/verification.md`](docs/verification.md) にあります。
