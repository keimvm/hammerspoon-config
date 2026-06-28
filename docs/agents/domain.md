# Domain Docs

engineering skills が codebase を探索するとき、この repo の domain documentation をどう読むかを定めます。

## Before exploring, read these

- repo root の **`CONTEXT.md`**。
- repo root に **`CONTEXT-MAP.md`** がある場合は、それが context ごとの `CONTEXT.md` を指します。作業対象に関係するものを読みます。
- **`docs/adr/`**。作業対象に関係する ADR を読みます。multi-context repo では、context 単位の decision を探すために `src/<context>/docs/adr/` も確認します。

これらの file が存在しない場合は、**静かに進めます**。存在しないこと自体を問題として扱ったり、先に作成するよう提案したりしません。`/domain-modeling` skill は、用語や decision が実際に整理されたタイミングで必要な file を lazy に作成します。

## File structure

この repo は single-context layout です。

```text
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-example-decision.md
│   └── 0002-example-decision.md
└── modules/
```

multi-context repo では、root の `CONTEXT-MAP.md` が存在します。

```text
/
├── CONTEXT-MAP.md
├── docs/adr/
└── src/
    ├── frontend/
    │   ├── CONTEXT.md
    │   └── docs/adr/
    └── backend/
        ├── CONTEXT.md
        └── docs/adr/
```

## Use the glossary's vocabulary

issue title、refactor proposal、hypothesis、test name などで domain concept を名付けるときは、`CONTEXT.md` に定義された用語を使います。glossary が避けている synonym に drift しないようにします。

必要な concept が glossary にまだない場合、それは signal です。project が使っていない言葉を作ってしまっている可能性があるなら見直します。本当に gap があるなら、`/domain-modeling` の対象として note します。

## Flag ADR conflicts

出力内容が既存 ADR と矛盾する場合は、静かに上書きせず、明示的に surface します。

```text
Contradicts ADR-0007 (event-sourced orders) -- but worth reopening because...
```
