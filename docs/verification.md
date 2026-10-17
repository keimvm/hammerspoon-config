# 検証手順

自動検証（Automated Verification）で設定とロジックを確認し、実機確認（Manual Runtime Verification）で Hammerspoon と macOS の動作を確認します。自動検証の成功だけでは、実機確認が済んだことにはなりません。

## 自動検証

`lua` と `luac` が必要です。導入方法は [README](../README.md#はじめる) を参照してください。リポジトリのルートで次を実行します。

```sh
./scripts/check
git diff --check
```

`./scripts/check` は Lua の構文、`init.lua`・`config.lua`・`modules/*.lua` の Git 追跡、fake `hs` による挙動のテスト（`tests/*_test.lua` をすべて）を実行します。Hammerspoon には接続せず、実際のキー変換やアプリ操作は行いません。`git diff --check` は差分の空白エラーなどを確認します。

| 対象 | 主な確認内容 | テスト |
| --- | --- | --- |
| 起動 | 同梱の設定での適用内容、問題がある設定では何も適用せず監視だけ始めること、登録できない Hotkey の報告、keyDown を監視する eventtap を作らないこと | [init_test.lua](../tests/init_test.lua) |
| Config Preflight | 型・項目名・キー名の検証、打ち間違いの候補、問題の集約、Hotkey Identity の重複と範囲による使い分け、設定データを変更しないこと | [preflight_test.lua](../tests/preflight_test.lua)、[chord_test.lua](../tests/chord_test.lua) |
| Hotkey | send の繰り返しと once、run の Command と関数・失敗時の表示、only / except の切り替え、表示名 | [hotkeys_test.lua](../tests/hotkeys_test.lua) |
| Safe Reload | 対象ファイルだけの監視、内容が同じ保存の無視、問題がある変更の拒否、Command からの強制再読み込み | [reloader_test.lua](../tests/reloader_test.lua) |
| Input Remap・Input Source | hidutil に渡す変換、解除、失敗の記録、最前面アプリに応じた英数・かな | [remap_test.lua](../tests/remap_test.lua)、[input_source_test.lua](../tests/input_source_test.lua) |
| App Switcher | 起動、非表示、Space の優先、巡回・再表示、Finder の非 standard window とデスクトップの区別、補助要素の除外、Space 取得失敗時の誤移動防止 | [app_switcher_test.lua](../tests/app_switcher_test.lua) |
| タイマー・コマンドパレット | 入力、単位切り替え、カウントダウン、完了表示・音、パレットの一覧と実行、タイマーの停止 | [timer_test.lua](../tests/timer_test.lua)、[palette_test.lua](../tests/palette_test.lua) |

## 実機確認

自動検証の成功後、変更した機能と影響する機能の項目を実施します。文書だけの変更では、参照先と記載の整合性を確認します。

最初に Hammerspoon のメニューから **Reload Config** を実行し、エラーの表示がないことを確認します。以下は [config.lua](../config.lua) の初期設定を前提としています。割り当てを変更している場合は読み替えてください。一時的に変更する値は控えておき、検証後に元へ戻します。

### Config Preflight と Safe Reload

- [ ] `config.lua` の空白だけを変えて保存すると、何も表示されない。
- [ ] `{ "ctrl+m", app = "Typora" }` を `{ "ctrl+m", app = "Typora", onyl = "Finder" }` に変えて保存すると、「再読み込みしませんでした（今の設定のまま動いています）」と `hotkeys[8].onyl: 不明な項目です（もしかして only）` が表示され、`⌃M` が引き続き動く。
- [ ] 表示は画面をクリックすると消え、クリック先も通常どおり反応する。Console に同じ内容が残っている。
- [ ] 元に戻して保存すると「設定を再読み込みしました（Hotkey 16 件）」と表示される。
- [ ] 問題のある状態のまま Hammerspoon を再起動すると「何も適用していません」と表示され、直して保存すると適用される。
- [ ] `hotkeys` を一時的に `(function() local t = {}; t[2] = { "ctrl+j", send = "left" }; t[4] = { "ctrl+l", send = "right" }; return t end)()` に変えて保存すると、リスト形式の問題が表示され、変更前の Hotkey が引き続き動く。確認後は元に戻す。

### Input Remap

- [ ] `hidutil property --get 'UserKeyMapping'` に `caps_lock` → `left_control`、`left_control` → `left_command`、`left_command` → `eisu`、`right_command` → `kana` の4つの変換がある。
- [ ] 物理 `left_control` を Command キーとして使える。
- [ ] 物理の左 Command で英数、右 Command でかなに切り替わる。
- [ ] コマンドパレットの「キー変換を一時解除」で `UserKeyMapping` が空になり、再読み込みで戻る。
- [ ] しばらく操作しなかった後に打ち始めても、最初の打鍵が遅れない。

### Hotkey

- [ ] 物理 `caps_lock+i/j/k/l` がそれぞれ `up/left/down/right` として動き、長押しで繰り返し入力になる。
- [ ] 物理 `caps_lock+h/d` が後方削除・前方削除として動き、長押しで繰り返し入力になる。
- [ ] `F5` が最前面アプリへ `⌘R` を一度だけ送り、長押ししても繰り返さない。
- [ ] Google Chrome が最前面の間は `⌘D` でブックマーク追加が開かない。
- [ ] Google Chrome 以外では、`⌘D` がそのアプリ本来の操作として動く。
- [ ] テンキーがある環境で `{ "ctrl+pad+", send = "pad+", once = true }` を一時的に追加すると、検証を通り、テキスト入力欄で `⌃` とテンキーの `+` を押すと `+` が1文字入力される。確認後は追加した行を削除する。

### App Switcher

- [ ] 対象アプリが未起動なら、その Hotkey で起動する。
- [ ] Finder のウィンドウをすべて閉じ、Finder が最前面の状態でも Hotkey で新しいウィンドウが開く。
- [ ] 現在の Space の対象ウィンドウが最前面で同じ Hotkey を押すと、別の Space のウィンドウも含めてアプリ全体を非表示にする。
- [ ] Space 1 と Space 2 に対象ウィンドウを用意し、アプリが最前面でない状態から各 Space で Hotkey を押すと、同じ Space のウィンドウにフォーカスする。
- [ ] 現在の Space に複数の対象ウィンドウがある場合、アプリが最前面でない状態から呼び出すたびに、その Space 内で対象が順に切り替わる。
- [ ] 現在の Space の対象ウィンドウが最小化されている場合、別の Space のウィンドウより優先して復帰する。
- [ ] 現在の Space に対象ウィンドウがない場合は、別の Space のウィンドウへ移動する。
- [ ] Finder のデスクトップだけが最前面で、対象ウィンドウは別 Space にだけある場合も、1回の Hotkey でそちらへ移動する。
- [ ] cmux などで補助要素がウィンドウ一覧に含まれていても、別 Space の実際のウィンドウへ移動する。
- [ ] 複数のディスプレイでは、各ディスプレイで現在表示中の Space にあるウィンドウを優先する。

### Input Source

- [ ] Zed、cmux、Visual Studio Code をそれぞれ最前面にすると、英数に切り替わる。
- [ ] Typora や Notion など対象外のアプリでは、現在の入力ソースを維持する。

### タイマー

- [ ] `⌃P` で入力画面が開き、入力欄の案内が「分（1〜180）」になる。
- [ ] `25` と入力して Enter を押すと、メニューバーに `25:00` が出て減っていく。
- [ ] 入力中の `Tab` で数値を保ったまま「秒（1〜10800）」へ切り替わり、もう一度押すと分へ戻る。
- [ ] `1.5` は `15` に変換されず、「数字と s / m だけ入力してください」と表示される。
- [ ] `181` 分、または秒へ切り替えた `10801` では許容範囲が表示され、タイマーは開始しない。
- [ ] メニューバーをクリックして「キャンセル」を選ぶと停止し、通知は出ない。
- [ ] 期限に達するとメニューバーが消え、短い完了音が1回だけ鳴り、「○分が経過しました」（秒指定なら「○秒が経過しました」）と表示される。表示は画面をクリックすると消える。

### コマンドパレット

- [ ] `⌃;` でパレットが開き、各行に `⌃I` や `⌘D · Google Chrome のみ` のような Hotkey が表示される。
- [ ] 「Chrome」と入力すると、Google Chrome に関係する行に絞り込まれる。
- [ ] 「Typora に切り替え」を選ぶと、パレットが閉じてから Typora に切り替わる。
- [ ] 「↑ を送る」を選ぶと、元のアプリでカーソルが上へ動く。
- [ ] タイマーの実行中は「タイマーを停止」が残り時間とともに並び、選ぶと止まる。
- [ ] もう一度 `⌃;` を押すとパレットが閉じる。

## 失敗した場合

意図しない挙動があれば、変更を修正または取り消してから、自動検証と対象項目の実機確認をやり直します。報告時は自動検証と実機確認の結果を分け、未確認の項目があれば明記してください。

物理キーの変換で操作が難しくなった場合は、[README の「操作を戻す」](../README.md#操作を戻す) に沿って変換を解除し、設定を修正します。
