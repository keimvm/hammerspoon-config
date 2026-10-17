## 作業の入口

- 利用手順とファイル・文書の一覧は [README.md](README.md)、構成・原則・設計判断は [docs/design.md](docs/design.md)、用語は [CONTEXT.md](CONTEXT.md) を参照してください。
- 設定値は `config.lua`、起動の順序は `init.lua`、機能の実装は `modules/`、自動テストは `tests/` にあります。
- 設定の変更方法は [docs/configuration.md](docs/configuration.md) にまとめています。現在の割り当ては `config.lua` を確認してください。
- `config.lua` は保存すると Hammerspoon が検証して自動で再読み込みします（Safe Reload）。作業中の途中状態でも、検証に通る内容なら実機に反映される点に注意してください。

## 変更と検証

- 設定と実装の役割を保ち、変更対象の既存コードとテストを確認してから作業してください。
- 変更後はリポジトリのルートで `./scripts/check` と `git diff --check` を実行してください。
- 動作を変えた場合は [docs/verification.md](docs/verification.md) の該当項目を実機で確認し、自動検証と実機確認の結果を分けて報告してください。実機確認ができなければ、その範囲を明記してください。
- 利用方法や設定を変えた場合は、対応する文書も更新してください。概念を名付けるときは `CONTEXT.md` の用語を使い、足りなければ用語集に加えてください。
- 設計判断を変える場合は、どの判断をなぜ見直すのかを [docs/design.md](docs/design.md) に残してください。
