# Issue 管理

Issue と PRD は GitHub Issues で管理し、操作には `gh` CLI を使います。リポジトリ内で実行すれば接続先を自動解決します。確認が必要な場合は `git remote -v` を使ってください。

## 対象範囲

triage の対象は GitHub Issues です。外部 PR は依頼の受付先（request surface）として扱いません。

スキルが「issue tracker に公開する」と指示した場合は Issue を作成し、「関連チケットを取得する」と指示した場合は `gh issue view <number> --comments` で本文とコメントを読みます。

## 操作

`<number>`、`<label>`、`<body-file>` は対象の値や用意したファイルに置き換えてください。複数行の本文やコメントはファイルに書き、`--body-file` で渡します。

| 操作 | コマンド |
| --- | --- |
| 作成 | `gh issue create --title "タイトル" --body-file <body-file>` |
| 本文・ラベル・コメントの確認 | `gh issue view <number> --comments` |
| 未完了の一覧 | `gh issue list --state open` |
| ラベルで絞り込み | `gh issue list --state open --label <label>` |
| コメント | `gh issue comment <number> --body-file <body-file>` |
| ラベルの追加 | `gh issue edit <number> --add-label <label>` |
| ラベルの削除 | `gh issue edit <number> --remove-label <label>` |
| クローズ | `gh issue close <number> --comment "完了理由"` |

一覧を構造化して取得する場合は次を使い、目的に応じて `--label` と `--state` を変更します。

```sh
gh issue list --state open --json number,title,body,labels,comments
```

ラベルの意味は [Triage ラベル](triage-labels.md) を参照してください。

GitHub は Issue と PR で番号を共有します。`#42` のように種類が不明な参照は、必要に応じて `gh pr view 42` と `gh issue view 42` で確認します。PR と判明しても triage の対象範囲は変わりません。
