# Hammerspoon Config

macOS 用の Hammerspoon 設定です。利用者が変更する設定値は `init.lua`、動作の実装は `modules/` に分けています。

> [!IMPORTANT]
> 初期設定では、読み込み時に物理 `caps_lock` を `left_control`、物理 `left_control` を `left_command` へ remap します。初回の **Reload Config** 前に、`init.lua` の `config.hidRemap` が自分の keyboard 環境に合うことを確認してください。

## セットアップ

1. [Hammerspoon](https://www.hammerspoon.org/go/) をインストールします。Homebrew を使う場合は次を実行します。

   ```sh
   brew install --cask hammerspoon
   ```

2. この repo の内容を `~/.hammerspoon` に配置します。Hammerspoon は `~/.hammerspoon/init.lua` を読み込みます。
3. Hammerspoon を起動する前に、後述の手順で `init.lua` を自分の環境に合わせます。
4. Automated Verification に使う `lua` と `luac` がない場合はインストールします。

   ```sh
   brew install lua
   ```

5. Hammerspoon を起動して Accessibility access を許可し、「変更を反映・検証する」の手順を実行します。

## 現在の操作

### Keyboard

| 操作                            | 動作                            |
| ------------------------------- | ------------------------------- |
| 物理 `caps_lock`                | `left_control`                  |
| 物理 `left_control`             | `left_command`                  |
| 左 Command key の単体押し       | `英数`                          |
| 右 Command key の単体押し       | `かな`                          |
| `ctrl+i/j/k/l`                  | `up/left/down/right`            |
| `F5`                            | frontmost app へ `cmd+r` を送信 |
| Chrome が frontmost の `cmd+d`  | 無効                            |

### App Switcher

App Switcher Hotkey は、対象 app が未起動なら起動、frontmost なら app 全体を hide、それ以外なら focus します。複数 window がある場合は、各 display で現在表示中の Space にある window だけを cycle します。現在表示中の Space に対象 window がない場合だけ、別の Space にある window へ移動します。

| Hotkey   | App           |
| -------- | ------------- |
| `ctrl+m` | Typora        |
| `ctrl+f` | Finder        |
| `ctrl+o` | メール        |
| `ctrl+t` | cmux          |
| `ctrl+r` | Zed           |
| `ctrl+g` | Google Chrome |
| `ctrl+n` | Notion        |

Typora は、未起動時に `~/Desktop/memo` 直下の file をまとめて開きます。directory が利用できない場合は通常起動します。

### Unicode Converter

初期設定では無効です。`config.unicodeConverter.enabled = true` にすると `cmd+shift+u` で開きます。

- `あ` -> `U+3042`
- `U+3042`、`0x3042`、`3042` -> `あ`

## 設定を変更する

通常は `init.lua` の `config` だけを変更します。

| 設定                         | 変更内容                                      |
| ---------------------------- | --------------------------------------------- |
| `config.hidRemap`            | modifier remap の ON/OFF と mapping           |
| `config.commandKeys`         | Command key 単体押しの ON/OFF と出力 key code |
| `config.controlLayer.arrows` | cursor 操作用 Hotkey                          |
| `config.reload`              | frontmost app へ `cmd+r` を送る Hotkey        |
| `config.appHotkeyBlocker`    | 対象 app で無効化する Hotkey と app 名        |
| `config.appSwitchers`        | App Switcher の app、Hotkey、directory        |
| `config.unicodeConverter`    | Unicode Converter の ON/OFF と Hotkey         |

Hotkey の共通 field は modifier 配列の `mods` と通常 key の `key` です。`id` は省略時に各 feature が導出します。用途の説明は `init.lua` のコメントで十分で、`description` は不要です。`enabled = false` を指定すると登録しません。`enabled` を省略した場合は有効です。`mods` は各 entry で `{ "ctrl" }` のように明示します。

### Modifier remap を変更する

`config.hidRemap.enabled = false` にすると、reload 時にこの設定が適用した remap を解除します。mapping を変える場合は、`mappings` の `from` と `to` を編集します。現在指定できる key は `caps_lock`、`left_control`、`left_command` です。

### App Switcher を変更する

各 entry は対象 app の `appName`、`mods`、`key` を書きます。未起動時に開く directory がある場合だけ `dirToOpen` を足します。`id` は省略時に App Switcher が導出します。

たとえば `ctrl+r` は変えず、対象を `/Applications/ChatGPT.app` から `/Applications/Codex.app` へ変更する場合は、`appName` だけを書き換えます。

```diff
-  { appName = "ChatGPT", mods = { "ctrl" }, key = "r" },
+  { appName = "Codex", mods = { "ctrl" }, key = "r" },
```

- `appName` は実際の app bundle 名に合わせます。別名の app は別 bundle として扱います。
- ショートカットの key を変える場合は `key` を変更します。modifier を変える場合は `mods` を変更します。
- 追加する場合は `{ appName = "...", mods = { "ctrl" }, key = "..." }` を足し、`key`（と `mods`）を一意にします。
- 一時的に止める場合は `enabled = false`、削除する場合は entry 全体を削除します。
- 旧 app 専用の `dirToOpen` は、新しい app で不要なら削除します。

同じ `mods + key` を複数の有効な設定に使うと、Config Preflight が `duplicates Hotkey Identity` error を出して reload を中止します。新しい entry を追加するのではなく、既存の割り当てを置き換える場合は元の entry を編集してください。

### App Hotkey Blocker を変更する

`config.appHotkeyBlocker` は、`appName` が一致する app が frontmost の間だけ指定した Hotkey を有効にし、app 本来の操作を無効化します。初期設定では Google Chrome の `cmd+d` を無効化します。ほかの app が frontmost の間は `cmd+d` を妨げません。`id` は省略時に App Hotkey Blocker が導出します。

一時的に止める場合は `enabled = false` を追加します。Chrome Beta や Chrome Canary を対象にする場合は、実際の app 名に合わせて `appName` を変更します。

### その他の Hotkey を変更する

`config.reload` と `config.unicodeConverter` の対象 entry で `mods` と `key` を変更します。Control arrow は `{ mods = { "ctrl" }, key = "i", arrow = "up" }` のように書き、`id` は省略時に `arrow` から導出します。既存の全 Hotkey と重複しない組み合わせを指定してください。Unicode Converter は `enabled` を `true` / `false` にして切り替えます。

## 変更を反映・検証する

1. repo root で `./scripts/check` を実行します。
2. Hammerspoon menu の **Reload Config** を実行します。`F5` は Hammerspoon の reload ではありません。
3. Console に error がないことを確認します。Config Preflight error がある場合は、表示された `config...` の field path を修正します。
4. 変更した Hotkey と、その変更によって重複する可能性がある Hotkey を実機で確認します。

App Switcher を変更した場合は、対象 app の起動、focus、hide、必要に応じて window cycle と `dirToOpen` を確認します。全機能の checklist は [`docs/verification.md`](docs/verification.md) を参照してください。

modifier remap により操作できなくなった場合は、別の terminal または入力手段から次を実行して解除し、設定を修正してから reload します。

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```
