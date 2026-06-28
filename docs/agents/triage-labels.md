# Triage Labels

engineering skills は、5 つの canonical triage role を前提に動きます。この file は、その role とこの repo の issue tracker で使う実際の label 文字列を対応付けます。

| Label in mattpocock/skills | Label in our tracker | Meaning |
| -------------------------- | -------------------- | ------- |
| `needs-triage`             | `needs-triage`       | maintainer が issue を評価する必要がある |
| `needs-info`               | `needs-info`         | reporter からの追加情報待ち |
| `ready-for-agent`          | `ready-for-agent`    | 仕様が揃っていて AFK agent が拾える |
| `ready-for-human`          | `ready-for-human`    | 人間による実装が必要 |
| `wontfix`                  | `wontfix`            | 対応しない |

skill が role に言及した場合、たとえば "apply the AFK-ready triage label" と言った場合は、この table の対応する label 文字列を使います。

実際の issue tracker 側の label vocabulary を変更した場合は、右側の column を更新してください。
