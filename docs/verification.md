# 検証手順

自動検証（Automated Verification）で設定とロジックを確認し、実機確認（Manual Runtime Verification）で Hammerspoon と macOS の動作を確認します。自動検証の成功だけでは、実機確認が済んだことにはなりません。

## 自動検証

`lua` と `luac` が必要です。導入方法は [README](../README.md#はじめる) を参照してください。リポジトリのルートで次を実行します。

```sh
./scripts/check
git diff --check
```

`./scripts/check` は Lua の構文、`init.lua` と `modules/*.lua` の Git 追跡、fake `hs` による挙動のテストを実行します。Hammerspoon IPC には接続せず、実際のキー変換やアプリ操作は行いません。`git diff --check` は差分の空白エラーなどを確認します。

主な検証範囲と対応するテストは次のとおりです。

| 対象 | 主な確認内容 | テスト |
| --- | --- | --- |
| 初期化・Config Preflight | 型、キー、リスト形式、重複、出力キーコードの検証。失敗時はウィンドウアニメーションの設定も変更しない | [init_test.lua](../tests/init_test.lua)、[config_validation_test.lua](../tests/config_validation_test.lua) |
| Hotkey Registry | 修飾キーの別名や重複表記の正規化、`fn` の拒否、登録失敗時の `id` を含むエラー | [hotkey_registry_test.lua](../tests/hotkey_registry_test.lua) |
| Input Remap・Control Layer | HID 変換の解除、Command 単体押しと組み合わせ操作、マウスイベントでキーコードを取得しないこと、繰り返し入力 | [input_remap_test.lua](../tests/input_remap_test.lua) |
| App Switcher | 起動、非表示、Space の優先、ウィンドウの巡回・再表示。候補が1つなら Space を照会せず、並べ替えで元の一覧を変更しない | [app_switcher_test.lua](../tests/app_switcher_test.lua) |
| アプリごとの制御 | 最前面アプリに応じた Hotkey の有効化と入力ソースの切り替え | [app_hotkey_blocker_test.lua](../tests/app_hotkey_blocker_test.lua)、[app_input_source_test.lua](../tests/app_input_source_test.lua) |
| Unicode Converter | 長いコードポイントの整数オーバーフロー防止、通知を省略するときの UTF-8 境界 | [unicode_converter_test.lua](../tests/unicode_converter_test.lua) |
| Timer | 入力、単位切り替え、カウントダウン、キャンセル、完了表示・音 | [timer_test.lua](../tests/timer_test.lua) |

## 実機確認

自動検証の成功後、変更した機能と影響する機能の項目を実施します。文書だけの変更では、参照先と記載の整合性を確認します。

最初に Hammerspoon のメニューから **Reload Config** を実行し、Console にエラーがないことを確認します。以下は [init.lua](../init.lua) の初期設定を前提としています。割り当てを変更している場合は読み替えてください。一時的に変更する値は控えておき、検証後に元へ戻して再読み込みします。

### Config Preflight

1. Control Layer の `F5` 項目（`to = { mods = { "cmd" }, key = "r" }`）の `key` を一時的に `F6` へ変更します。
2. `config.unicodeConverter.enabled = "invalid"` と、先頭の App Switcher に `appName = 42` を設定します。
3. メニューから **Reload Config** を実行します。
4. Console の一つの `invalid Hammerspoon config:` エラーに、`config.unicodeConverter.enabled` と `config.appSwitchers[1].appName` の両方が含まれることを確認します。
5. `F6` を押しても `cmd+r` が送信されず、新しい Hotkey が登録されていないことを確認します。
6. 3か所を元へ戻して再読み込みし、エラーがなく `F5` と対象機能が動作することを確認します。

### Input Remap・Command キー

- [ ] `hidutil property --get 'UserKeyMapping'` に `caps_lock` → `left_control` と `left_control` → `left_command` の2つの変換がある。
- [ ] `config.hidRemap.enabled = false` にして再読み込みすると `UserKeyMapping` が空になり、元へ戻して再読み込みすると変換が復旧する。
- [ ] 物理 `caps_lock+i/j/k/l` がそれぞれ `up/left/down/right` として動き、長押しで繰り返し入力になる。
- [ ] 物理 `caps_lock+h/d` が後方削除・前方削除として動き、長押しで繰り返し入力になる。
- [ ] 物理 `left_control` を Command キーとして使える。
- [ ] 左 Command の単体押しで英数、右 Command の単体押しでかなに切り替わる。
- [ ] Command をほかのキーと組み合わせて使った場合、単体押しの入力切り替えが発火しない。
- [ ] Ctrl / Alt / Shift / Fn のいずれかを先に押し、Command を押して離しても入力が切り替わらず、その後の単体押しでは通常どおり切り替わる。
- [ ] 左右 Command を同時に押して離しても入力が切り替わらず、その後の左右それぞれの単体押しが動作する。
- [ ] Command を押したまま再読み込みし、すべての Command を離すまでは入力が切り替わらず、その後の単体押しが動作する。

### Control Layer・App Hotkey Blocker

- [ ] `F5` が最前面アプリへ `cmd+r` を一度だけ送り、長押ししても繰り返さない。
- [ ] Google Chrome が最前面の間は `cmd+d` でブックマーク追加が開かない。
- [ ] Google Chrome 以外では、`cmd+d` がそのアプリ本来の操作として動く。

### App Switcher

- [ ] 対象アプリが未起動なら、その Hotkey で起動する。
- [ ] 最前面で同じ Hotkey を押すと、別の Space のウィンドウも含めてアプリ全体を非表示にする。
- [ ] Space 1 と Space 2 に対象ウィンドウを用意し、アプリが最前面でない状態から各 Space で Hotkey を押すと、同じ Space のウィンドウにフォーカスする。
- [ ] 現在の Space に複数の対象ウィンドウがある場合、アプリが最前面でない状態から呼び出すたびに、その Space 内で対象が順に切り替わる。
- [ ] アプリを非表示にして別の Space へ移動した後、Hotkey で移動先の対象ウィンドウを表示する。
- [ ] 現在の Space の対象ウィンドウが最小化されている場合、別の Space のウィンドウより優先して復帰する。
- [ ] 現在の Space に対象ウィンドウがない場合は、別の Space のウィンドウへ移動する。
- [ ] 複数のディスプレイでは、各ディスプレイで現在表示中の Space にあるウィンドウを優先する。

### App Input Source

- [ ] Zed、cmux、Visual Studio Code をそれぞれ最前面にすると、英数に切り替わる。
- [ ] Typora や Notion など対象外のアプリでは、現在の入力ソースを維持する。

### Unicode Converter

1. `config.unicodeConverter.enabled = false` で再読み込みし、`cmd+shift+u` が登録されないことを確認します。
2. `enabled = true` にして再読み込みし、`cmd+shift+u` で変換画面が開くことを確認します。
3. `U+3042` → `あ` と `あ` → `U+3042` を確認します。
4. `U+10000000000003042` がエラーになり、`U+00000000000003042` は「あ」になることを確認します。
5. 絵文字を多数含む変換結果をコピーし、通知の末尾に文字化けがないことを確認します。
6. `enabled` を検証前の値に戻して再読み込みします。

### Timer

- [ ] `ctrl+p` で入力画面が開き、入力欄の案内が「分（1〜180）」になる。
- [ ] `25` と入力して Enter を押すと、メニューバーに `25:00` が出て減っていく。
- [ ] 入力中の `Tab` で数値を保ったまま「秒（1〜10800）」へ切り替わり、もう一度押すと分へ戻る。
- [ ] `1.5` は `15` に変換されず、「数字と s / m だけ入力してください」と表示される。
- [ ] `181` 分、または秒へ切り替えた `10801` では許容範囲が表示され、Timer は開始しない。
- [ ] メニューバーをクリックして「キャンセル」を選ぶと停止し、通知は出ない。
- [ ] 期限に達するとメニューバーが消え、短い完了音が1回だけ鳴り、「○分が経過しました」（秒指定なら「○秒が経過しました」）と表示される。表示は時間経過では消えず、画面をクリックすると消える。クリック先も通常どおり反応する。
- [ ] **Reload Config** で実行中の Timer が破棄される。

## 失敗した場合

意図しない挙動があれば、変更を修正または取り消してから、自動検証と対象項目の実機確認をやり直します。報告時は自動検証と実機確認の結果を分け、未確認の項目があれば明記してください。

物理キーの変換で操作が難しくなった場合は、[README の「操作を戻す」](../README.md#操作を戻す) に沿って変換を解除し、設定を修正します。
