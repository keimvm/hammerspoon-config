# コードベース改善戦略

この文書は、`.hammerspoon` のコードベース全体を継続的に改善するための判断を記録する。個別の実装案を先に固定せず、目的、評価軸、優先順位を合意してから実行単位へ分解する。

## 目的

入力操作を壊さず、安心して設定を変更できる状態にする。

保守性、テスト、module 構成の整理はそれ自体を目的にせず、この「安全な変更可能性」を高める手段として評価する。

## 現状

- `init.lua` が設定値、`modules/` が feature の実装を所有する構成になっている。
- Hotkey Registry により、Hotkey metadata の検証と重複検出は一元化されている。
- `luac -p init.lua modules/*.lua` による syntax check は成功する。
- Hammerspoon process は起動しているが、CLI から IPC message port へ接続できない。この環境では live reload を自動検証の前提にできない。
- Input Remap、config validation、app switcher の検証 seam、repo-local verification entrypoint は改善候補として残っている。

## 判断ログ

### 2026-07-11: 改善の最上位目的

「入力操作を壊さず、安心して設定を変更できる状態」を最上位目的とする。新機能の追加速度や抽象化の統一より、変更時の回帰検出と復旧可能性を優先する。

### 2026-07-11: 二層の検証

検証を次の二層に分ける。

1. **Automated Verification**: `luac`、tracked-file check、fake `hs` adapter を使い、syntax、設定、入力ロジックを再現可能な形で検証する。
2. **Manual Runtime Verification**: 実際の Hammerspoon と macOS 上で、Hotkey、`eventtap`、`hidutil`、app focus など OS integration の挙動を確認する。

Hammerspoon IPC への接続を自動検証の必須条件にはしない。自動検証は decision logic と設定不備の検出を担当し、macOS integration 固有の最終確認だけを短い manual checklist に残す。

### 2026-07-11: 改善中に維持する挙動

architecture 改善中は、次の user-visible behavior を変更しない。挙動変更が必要になった場合は、refactor と混ぜずに別の変更として扱う。

- `caps_lock` を `left_control` として扱う。
- `left_control` を `left_command` として扱う。
- Command key の単体押しで `英数` / `かな` を送信する。
- `ctrl+i/j/k/l` で arrow key を送信し、長押しを repeat する。
- App Switcher が app の起動、focus、hide、window cycle を行う。
- Unicode Converter の文字と code point の相互変換を維持する。

Unicode Converter の ON/OFF は固定された user-visible behavior ではなく、容易に変更できる設定として維持する。

### 2026-07-11: Unicode Converter の ON/OFF

Unicode Converter の ON/OFF は、`init.lua` の `unicodeConverter.enabled` を `true` / `false` に変更し、Hammerspoon を reload して反映する。runtime Hotkey や menubar に別の状態を持たせず、`init.lua` を稼働状態の source of truth とする。

### 2026-07-11: Input Remap の module 構成

`hid_remap`、`command_keys`、`control_layer` は一つの lifecycle module に統合しない。それぞれ `hidutil` task、modifier tap の状態機械、Hotkey 登録という異なる lifecycle と挙動を所有しているため、feature module として維持する。

共通 module は、M1 の検証によって cross-module invariant が実在すると確認できた場合に限って追加する。設定を受け取って既存 module を順番に呼ぶだけの浅い orchestrator は作らない。

### 2026-07-11: Config の preflight validation

Hotkey 登録、`eventtap` の開始、`hidutil` task の開始より前に、設定全体を side-effect-free に検証する。reload の途中で一部の side effect だけが適用される状態を避ける。

最初の対象は次に限定する。

- 必須 field と型
- unknown key / modifier
- Hotkey Identity と `id` の重複
- Input Remap の mapping
- enabled / disabled item の整合性
- `dirToOpen` の型

app や directory が現在存在するかは環境依存なので、config validation error にはしない。

### 2026-07-11: `init.lua` の config shape

`init.lua` は次の三段構成にする。

1. 単一の `config` table に、すべての Desired Hotkey と feature 設定を宣言する。
2. `configValidation.validate(config)` で設定全体を preflight する。
3. validation が成功した場合だけ、各 feature module の `apply` / `bind` を明示的に呼ぶ。

設定値の source of truth は引き続き `init.lua` とする。適用順を隠す大きな orchestrator module は作らない。

### 2026-07-11: Config validation error

config validation は最初の不備で停止せず、検出した不備を field path とともに集約し、最後に一つの multi-line error として失敗させる。validator は入力された config を mutate しない。

これにより、一度の automated verification または reload で修正箇所をまとめて把握できるようにする。

### 2026-07-11: Input Remap の lifecycle 評価

M3 では、各 feature module の現行 interface から lifecycle、side effect、cleanup を検証した。確認できた risk は feature 内に閉じる次の2件だった。

- HID mapping を無効化しても OS に既存 mapping が残る cleanup 漏れ。
- 左右 Command key を同時に使うと、aggregate な `cmd` flag だけでは片側の release を識別できず、単体押し判定の状態が残る問題。

HID mapping は明示的な無効化時に空の `UserKeyMapping` を適用し、Command key は key ごとの `flagsChanged` event で状態を遷移させる。Control layer を含む3 module 間には、共有 state、必須の呼び出し順、共通 cleanup は確認されなかった。そのため、feature module を維持し、共通 lifecycle module は追加しない。

### 2026-07-11: App Switcher の検証 seam

最初に現在の `toggleOrCycle(appName, dirToOpen)` interface を fake `hs` 経由でテストする。未起動時の launch、frontmost 時の hide、非 frontmost 時の focus、window cycle、window がない場合の reopen、`dirToOpen` 失敗時の fallback をこの interface から検証する。

現行 interface からのテストが不自然または過度に複雑だと確認できた場合だけ、window selection などの decision logic に internal seam を追加する。テストのためだけに runtime adapter や public method を先に増やさない。

## マイルストーン

### M1: Verification Baseline

architecture を変更する前に、現行挙動を守る検証基盤を作る。

- repo-local な単一検証コマンドを用意する。
- syntax check と tracked-file check を自動化する。
- fake `hs` adapter を使い、維持対象の user-visible behavior を characterization test で固定する。
- Hotkey、`eventtap`、`hidutil`、app focus を確認する短い manual checklist を用意する。
- GitHub issue #5 の現状を再評価し、Acceptance Criteria を満たしたら完了扱いにする。

M1 が完了するまで、Input Remap や App Switcher の architecture refactor には着手しない。

### M2: Config Preflight

すべての runtime side effect より前に設定全体を検証する seam を追加する。GitHub issue #3 は、validation 項目を無制限に増やすのではなく、partial apply を防ぐための preflight として再定義する。

### M3: Input Remap の安全性

M1 の behavior contract と M2 の preflight を使い、Input Remap を feature module ごとに検証する。GitHub issue #2 は lifecycle module の新設を既定路線にせず、実在する cross-module invariant、cleanup 漏れ、ordering dependency があるかを再評価する。問題が確認できなければ module 統合は行わない。

### M4: App Switcher の検証

M1 の fake `hs` adapter を使い、App Switcher を現在の interface から characterization test する。GitHub issue #4 は testability の実測に基づいて再評価し、現行 interface で十分なら architecture refactor を行わない。

## 実行ルール

各マイルストーンは独立した gate とし、次の条件をすべて満たしたときだけ完了とする。

- automated verification がすべて成功する。
- 対象範囲の Manual Runtime Verification が成功する。
- user-visible behavior に意図しない差分がない。

条件を満たせない場合は次のマイルストーンへ進まない。そのマイルストーン内で修正するか、変更を取り消す。複数のマイルストーンを一つの refactor にまとめない。

## Issue mapping

| Milestone | GitHub issue | 役割 |
| --- | --- | --- |
| M1 | #5 Verification Baseline を整備する | Automated / Manual Verification の基準を作る |
| M2 | #3 Config Preflight を追加する | partial side effect を防ぐ |
| M3 | #2 Input Remap の安全性を検証する | feature module ごとに検証し、実在する risk だけを解消する |
| M4 | #4 App Switcher を現行 interface から検証する | 現行 interface を評価し、必要な場合だけ internal seam を追加する |

M1 / issue #5、M2 / issue #3、M3 / issue #2 は、Automated Verification と Manual Runtime Verification の完了 gate を満たして close した。現在の実行点は M4 / issue #4 とする。各 issue は前のマイルストーンの完了 gate を満たしてから開始する。
