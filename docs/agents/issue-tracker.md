# Issue tracker: GitHub

この repo の issue と PRD は GitHub Issues で管理します。すべての操作には `gh` CLI を使います。

## Conventions

- **issue を作成する**: `gh issue create --title "..." --body "..."`。複数行の body には heredoc を使います。
- **issue を読む**: `gh issue view <number> --comments`。必要に応じて `jq` で comments を絞り込み、labels も確認します。
- **issue を一覧する**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`。目的に応じて `--label` と `--state` を追加します。
- **issue に comment する**: `gh issue comment <number> --body "..."`
- **label を追加 / 削除する**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **close する**: `gh issue close <number> --comment "..."`

repo は `git remote -v` から推定します。clone の中で実行していれば、`gh` が自動で解決します。

## Pull requests as a triage surface

**PRs as a request surface: no.**

この repo では、外部 PR を `triage` skill の request surface として扱いません。`triage` は GitHub Issues を対象にします。

将来、外部 PR も request surface として扱う場合は、この値を `yes` に変更します。その場合、PR は issue と同じ labels / states を通り、次の `gh pr` 系 command を使います。

- **PR を読む**: `gh pr view <number> --comments` と、diff 確認用の `gh pr diff <number>`。
- **triage 対象の外部 PR を一覧する**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` を実行し、`authorAssociation` が `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR`、`NONE` のものだけを残します。`OWNER`、`MEMBER`、`COLLABORATOR` は除外します。
- **comment / label / close**: `gh pr comment`、`gh pr edit --add-label` / `--remove-label`、`gh pr close`。

GitHub は issue と PR で number space を共有します。`#42` のような参照は issue と PR のどちらもあり得るため、必要なら `gh pr view 42` を試し、失敗したら `gh issue view 42` に fall back します。

## When a skill says "publish to the issue tracker"

GitHub issue を作成します。

## When a skill says "fetch the relevant ticket"

`gh issue view <number> --comments` を実行します。
