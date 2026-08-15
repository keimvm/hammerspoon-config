# Hammerspoon Config

macOS 用の Hammerspoon 設定です。利用者が変える値は `init.lua` の `config`、動作の実装は `modules/` にあります。いま有効な割り当ては `init.lua` を見てください。この文書は始め方と、設定の直し方だけを持ちます。

> [!IMPORTANT]
> 初期設定は、読み込み時に物理 `caps_lock` を `left_control`、物理 `left_control` を `left_command` へ remap します。初回の **Reload Config** の前に、`config.hidRemap` が自分の keyboard に合うことを確認してください。

## はじめる

1. [Hammerspoon](https://www.hammerspoon.org/go/) を入れます。Homebrew なら次です。

   ```sh
   brew install --cask hammerspoon
   ```

2. この repo を `~/.hammerspoon` に置きます。Hammerspoon は `~/.hammerspoon/init.lua` を読みます。
3. Hammerspoon を起動する前に、`init.lua` の `config` を自分の環境に合わせます。最低限、`hidRemap` と `appSwitchers` を確認します。
4. 検証に使う `lua` と `luac` がなければ入れます。

   ```sh
   brew install lua
   ```

5. Hammerspoon を起動し、Accessibility access を許可します。
6. Hammerspoon menu の **Reload Config** を実行し、Console に error がないことを確認します。

操作できなくなったときは、[操作を戻す](#操作を戻す) へ進みます。

## 何が動くか

各機能の割り当てと ON/OFF は `init.lua` の該当 field が正です。ここには、設定を開いたときに迷わないための役割だけを書きます。

| 設定 | 役割 |
| --- | --- |
| `config.hidRemap` | 物理キーの Input Remap。指定できる key は `caps_lock`、`left_control`、`left_command` |
| `config.commandKeys` | Command key の単体押し。初期設定は JIS の `英数` / `かな` |
| `config.controlLayer.bindings` | 修飾付き Hotkey で別キーを送る。初期設定は矢印と削除 |
| `config.reload` | frontmost app へ `cmd+r` を送る Hotkey。Hammerspoon 自身の reload ではない |
| `config.appHotkeyBlocker` | 対象 app が frontmost の間だけ、指定 Hotkey で app 本来の操作を無効化する |
| `config.appSwitchers` | 対象 app の起動、focus、hide、window cycle |
| `config.unicodeConverter` | 文字と code point の相互変換。初期設定では無効 |

App Switcher は、対象 app が未起動なら起動、frontmost なら app 全体を hide、それ以外なら focus します。複数 window がある場合は、各 display で現在表示中の Space にある window だけを cycle します。いまの Space に対象 window がない場合だけ、別の Space へ移動します。

## 設定の直し方

通常は `init.lua` の `config` だけを変えます。`modules/` は実装なので、機能追加や不具合修正のとき以外は触りません。

Hotkey の共通 field は `mods` と `key` です。`mods` は各 entry で `{ "ctrl" }` のように明示します。`id` は省略でき、各 feature が導出します。`enabled = false` を付けると登録しません。`enabled` を省略したときは有効です。

同じ `mods + key` を複数の有効な設定に使うと、Config Preflight が `duplicates Hotkey Identity` error を出して reload を中止します。新しい entry を足すのではなく置き換える場合は、元の entry を編集します。

### App Switcher

各 entry は対象 app の `appName`、`mods`、`key` です。`appName` は実際の app bundle 名に合わせます。

```lua
{ appName = "対象の app 名", mods = { "ctrl" }, key = "r" },
```

- 対象だけ変えるときは `appName` を書き換えます。
- ショートカットを変えるときは `key` または `mods` を変えます。
- 足すときは同じ形の entry を追加し、`mods + key` を一意にします。
- 一時停止は `enabled = false`、削除は entry 全体を消します。

### そのほか

- **Input Remap を止める**: `config.hidRemap.enabled = false`。reload すると、この設定が適用した remap を解除します。mapping を変えるときは `mappings` の `from` と `to` を編集します。
- **App Hotkey Blocker**: 対象 app が frontmost の間だけ有効です。止めるときは `enabled = false`。Chrome Beta など別名の app は、実際の app 名に `appName` を合わせます。
- **Control Layer**: `{ mods = { "ctrl" }, key = "h", to = "delete" }` の形です。`id` は省略時に `to` から導出します。後方削除は `delete`、前方削除は `forwarddelete` です。
- **Unicode Converter**: `enabled` を `true` にすると登録します。変換例は `あ` ↔ `U+3042` です。`U+3042`、`0x3042`、`3042` を受け付けます。

## 変更を反映する

1. repo root で `./scripts/check` を実行します。
2. Hammerspoon menu の **Reload Config** を実行します。`config.reload` の Hotkey は Hammerspoon の reload ではありません。
3. Console に error がないことを確認します。Config Preflight error なら、表示された `config...` の field path を直します。
4. 変えた操作と、重複しそうな既存の操作を実機で確認します。

App Switcher を変えたときは、対象 app の起動、focus、hide、必要なら window cycle を確認します。全機能の checklist は [`docs/verification.md`](docs/verification.md) です。

## 操作を戻す

modifier remap で操作できなくなったら、別の terminal または入力手段から次を実行して解除し、設定を直してから reload します。

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```
