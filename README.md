# Hammerspoon Config

macOS 用の Hammerspoon 設定です。キー入力の変換、アプリの切り替え、入力ソースの切り替え、タイマーなどを提供します。設定値は [init.lua](init.lua) の `config`、機能の実装は `modules/` にあります。

> [!IMPORTANT]
> 初期設定では、設定の読み込み時に物理 `caps_lock` を `left_control`、物理 `left_control` を `left_command`、物理の左右 Command を英数・かなキーに変換します。Hammerspoon を起動する前に、`config.hidRemap` が自分のキーボードに合うことを確認してください。

## はじめる

1. [Hammerspoon](https://www.hammerspoon.org/go/) と、検証用の Lua をインストールします。Homebrew を使う場合は次を実行します。

   ```sh
   brew install --cask hammerspoon
   brew install lua
   ```

2. このリポジトリを `~/.hammerspoon` に置きます。Hammerspoon は `~/.hammerspoon/init.lua` を読み込みます。
3. 起動前に `init.lua` の `config` を自分の環境に合わせます。特に `hidRemap` と `appSwitchers` を確認してください。詳細は [設定ガイド](docs/configuration.md) を参照してください。
4. リポジトリのルートで `./scripts/check` を実行します。
5. Hammerspoon を起動し、アクセシビリティへのアクセスを許可します。
6. Hammerspoon のメニューから **Reload Config** を実行し、Console にエラーがないことを確認します。

## 主な機能

現在の割り当てと有効・無効は `init.lua` で確認してください。

| 設定 | 役割 |
| --- | --- |
| `config.hidRemap` | 物理キーを別のキーへ変換する Input Remap |
| `config.commandKeys` | Command キーの単体押しで英数・かなを切り替える |
| `config.controlLayer.bindings` | Hotkey で別のキーや修飾キー付きの入力を送る Control Layer |
| `config.appHotkeyBlockers` | 対象アプリが最前面の間だけ、指定した Hotkey でアプリ本来の操作を無効にする |
| `config.appSwitchers` | アプリの起動、フォーカス、非表示、ウィンドウの切り替えを行う App Switcher |
| `config.appInputSources.bindings` | 対象アプリが最前面になったときに入力ソースを切り替える |
| `config.unicodeConverter` | 文字とコードポイントを相互変換する |
| `config.timer` | 同時に1本のカウントダウンを実行する |

## 変更を反映する

1. `init.lua` の `config` を編集します。通常の設定変更では `modules/` を触る必要はありません。
2. リポジトリのルートで `./scripts/check` を実行します。
3. Hammerspoon のメニューから **Reload Config** を実行します。Control Layer の `F5` は `cmd+r` の送信であり、Hammerspoon の設定を再読み込みする操作ではありません。
4. Console にエラーがないことを確認します。`invalid Hammerspoon config:` が出た場合は、表示された `config...` の項目を修正します。
5. [検証手順](docs/verification.md) に沿って、変更した操作と影響する既存の操作を実機で確認します。

## 操作を戻す

物理キーの変換によって操作できなくなった場合は、別のターミナルや入力手段から次を実行します。

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```

`UserKeyMapping` が空になり、物理キーの変換が解除されます。その後、`config.hidRemap` を修正するか `enabled = false` にしてから **Reload Config** を実行してください。

## ドキュメント

| 文書 | 内容 |
| --- | --- |
| [設定ガイド](docs/configuration.md) | 設定の書き方、各機能の操作と制約 |
| [検証手順](docs/verification.md) | 自動検証と実機確認のチェックリスト |
| [用語集](CONTEXT.md) | このリポジトリで使う用語 |
| [エージェント向け作業ガイド](AGENTS.md) | 作業時の規約と確認事項 |
| [用語・設計判断の参照先](docs/agents/domain.md) | コードを調べる前に読む文書 |
| [Issue 管理](docs/agents/issue-tracker.md) | GitHub Issues の操作と triage の対象範囲 |
| [Triage ラベル](docs/agents/triage-labels.md) | ラベルの意味と対応関係 |
| [コードベース改善の記録](docs/strategy/codebase-improvement.md) | 完了済みの改善と、その判断理由 |
