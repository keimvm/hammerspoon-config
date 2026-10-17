# Hammerspoon Config

macOS 用の Hammerspoon 設定です。物理キーの変換、Hotkey によるキー入力・アプリ切り替え、アプリごとの入力ソース切り替え、タイマー、コマンドパレットを提供します。

設定は [config.lua](config.lua) の1ファイルにまとまっています。保存すると内容を検証し、問題がなければ自動で再読み込みします。問題があれば今の設定のまま、どこが違うかを画面に表示します。

> [!IMPORTANT]
> 初期設定では、物理 `caps_lock` を `left_control`、物理 `left_control` を `left_command`、物理の左右 Command を英数・かなキーに変換します。Hammerspoon を起動する前に、`config.lua` の `remap` が自分のキーボードに合うことを確認してください。

## はじめる

1. [Hammerspoon](https://www.hammerspoon.org/go/) と、検証用の Lua をインストールします。

   ```sh
   brew install --cask hammerspoon
   brew install lua
   ```

2. このリポジトリを `~/.hammerspoon` に置きます。Hammerspoon は `~/.hammerspoon/init.lua` を読み込みます。
3. `config.lua` を自分の環境に合わせます。書き方は [設定ガイド](docs/configuration.md) を参照してください。
4. リポジトリのルートで `./scripts/check` を実行します。
5. Hammerspoon を起動し、アクセシビリティへのアクセスを許可します。

## 初期設定の操作

| Hotkey | 動作 |
| --- | --- |
| `⌃I` `⌃J` `⌃K` `⌃L` | ↑ ← ↓ → を送る（長押しで繰り返す） |
| `⌃H` / `⌃D` | 後方削除 / 前方削除 |
| `F5` | `⌘R` を一度だけ送る |
| `⌃M` `⌃F` `⌃O` `⌃T` `⌃R` `⌃G` | Typora、Finder、Microsoft Outlook、cmux、Zed、Google Chrome を起動・フォーカス・非表示・ウィンドウ切り替え |
| `⌘D`（Google Chrome のみ） | ブックマーク追加を無効にする |
| `⌃P` | タイマー |
| `⌃;` | コマンドパレット（Hotkey の一覧と Command の実行） |

物理キーの変換により、`⌃` は物理 `caps_lock`、`⌘` は物理 `left_control` で押します。Zed、cmux、Visual Studio Code が最前面になると英数に切り替わります。

## 設定を変える

1. `config.lua` を編集して保存します。
2. 画面に「設定を再読み込みしました」と出れば反映済みです。問題があれば、今の設定のまま問題の一覧が出ます。一覧はクリックすると消え、全文は Hammerspoon Console に残ります。
3. [検証手順](docs/verification.md) に沿って、変更した操作を実機で確認します。

`modules/` や `init.lua` を変えた場合は自動では再読み込みしません。コマンドパレットの「設定を再読み込み」か、Hammerspoon のメニューの **Reload Config** を使ってください。

## 操作を戻す

物理キーの変換によって操作できなくなった場合は、コマンドパレットの「キー変換を一時解除」を選ぶか、別のターミナルや入力手段から次を実行します。

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```

変換が解除されます。その後 `config.lua` の `remap` を直して保存してください。

## ドキュメント

| 文書 | 内容 |
| --- | --- |
| [設定ガイド](docs/configuration.md) | `config.lua` の書き方と各機能の挙動 |
| [検証手順](docs/verification.md) | 自動検証と実機確認のチェックリスト |
| [用語集](CONTEXT.md) | このリポジトリで使う用語 |
| [エージェント向け作業ガイド](AGENTS.md) | 作業時の規約と確認事項 |
| [用語・設計判断の参照先](docs/agents/domain.md) | コードを調べる前に読む文書 |
| [Issue 管理](docs/agents/issue-tracker.md) | GitHub Issues の操作と triage の対象範囲 |
| [Triage ラベル](docs/agents/triage-labels.md) | ラベルの意味と対応関係 |
| [コードベース改善の記録](docs/strategy/codebase-improvement.md) | 過去の改善と書き直しの判断理由 |
