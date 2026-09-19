## Language

- Respond in Japanese by default.
- Write repository documentation and necessary code comments in Japanese by default, unless the repository already uses another language or the user says otherwise. Do not translate existing text unless asked.
- Keep code, commands, file names, identifiers, API names, and error messages in their original language when appropriate. Use English for new identifiers and file names.

## Environment

- Assume macOS by default unless stated otherwise or the repository clearly indicates another environment.
- Prefer Homebrew, pnpm, and uv when choosing tools or package managers, unless the repository indicates otherwise.

## 作業の入口

- 利用手順と文書一覧は [README.md](README.md)、用語と設計判断の読み方は [docs/agents/domain.md](docs/agents/domain.md) を参照してください。
- 設定値は `init.lua` の `config`、機能の実装は `modules/`、自動テストは `tests/` にあります。
- 設定の変更方法は [docs/configuration.md](docs/configuration.md) にまとめています。現在の割り当てと有効・無効は `init.lua` を確認してください。

## 変更と検証

- 設定と実装の役割を保ち、変更対象の既存コードとテストを確認してから作業してください。
- 変更後はリポジトリのルートで `./scripts/check` と `git diff --check` を実行してください。
- 動作を変えた場合は [docs/verification.md](docs/verification.md) の該当項目を実機で確認し、自動検証と実機確認の結果を分けて報告してください。実機確認ができなければ、その範囲を明記してください。
- 利用方法や設定を変えた場合は対応する文書も更新してください。過去の改善記録は [docs/strategy/codebase-improvement.md](docs/strategy/codebase-improvement.md) にあります。

## Issue 管理

- Issue と PRD は GitHub Issues で管理します。操作方法と triage の対象範囲は [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md) を参照してください。
- triage のラベルは [docs/agents/triage-labels.md](docs/agents/triage-labels.md) に定義しています。
