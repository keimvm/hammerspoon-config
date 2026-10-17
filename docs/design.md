# 設計

コードを変更する人に向けて、構成、守っている原則、設計判断をまとめます。設定の書き方は [設定ガイド](configuration.md)、用語は [用語集](../CONTEXT.md)、変更後の確認は [検証手順](verification.md) を参照してください。

## 原則

- **入力操作を壊さない。** 設定に問題があれば何も適用せず、一部だけが適用された状態を作らない。副作用より前に Config Preflight を行い、問題は項目の場所とともにまとめて報告する。
- **入力遅延を生まない。** keyDown を常時監視する eventtap は使わず、物理キーの変換は hidutil に任せる。常駐させてよい eventtap は、クリックで閉じる表示のためにマウスの押下だけを見るものに限る。
- **設定と実装を分ける。** 設定は `config.lua` の1か所にまとめ、適用の順序は `init.lua` に明示する。
- **自動検証と実機確認を分ける。** 自動検証が通っても実機確認の代わりにはならない。報告でも区別する。
- **必要になるまで抽象化しない。** 使っていない機能や設定項目は残さない。

## 構成

| パス | 役割 |
| --- | --- |
| `config.lua` | 設定のテーブルを返す。実装は含めない |
| `init.lua` | 起動の順序だけを持つ |
| `modules/preflight.lua` | Config Preflight。各機能の `validate` を呼び、問題を集める |
| `modules/report.lua` | 問題を項目の場所（`hotkeys[3].app` など）とともに集め、打ち間違いの候補を出す |
| `modules/reloader.lua` | Safe Reload。`config.lua` の保存を監視し、検証に通った場合だけ再読み込みする |
| `modules/remap.lua` | Input Remap。hidutil の `UserKeyMapping` を設定する |
| `modules/chord.lua` | Chord の解析、Hotkey Identity への正規化、記号での表示 |
| `modules/hotkeys.lua` | Hotkey の検証と登録、Scope に応じた有効・無効の切り替え |
| `modules/commands.lua` | `run` で呼べる組み込みの Command |
| `modules/app_switcher.lua` | App Switcher |
| `modules/input_source.lua` | アプリごとの Input Source の切り替え |
| `modules/frontmost.lua` | 最前面アプリの変化を各機能へ知らせる |
| `modules/palette.lua` | コマンドパレット |
| `modules/timer.lua` | タイマー |
| `modules/ui.lua` | 通知と chooser の見た目と振る舞い |
| `tests/` | fake `hs`（[fake_hs.lua](../tests/support/fake_hs.lua)）で Hammerspoon の API を置き換えた自動テスト |
| `scripts/check` | 自動検証をまとめて実行する |

### 起動の流れ

`init.lua` は次の順に処理します。

1. `preflight.load` で `config.lua` を読み込み、設定全体を検証する。
2. `reloader.watch` で `config.lua` の監視を始める。検証に失敗した場合もここまでは行い、直して保存すれば復旧できるようにする。
3. 検証に失敗していれば、問題を表示して終える。
4. `remap.apply`、`hotkeys.start`、`inputSource.start`、`frontmost.start`、`palette.use` の順に適用する。`frontmost.start` は開始時に現在の最前面アプリを知らせるため、購読する機能（Scope つきの Hotkey と Input Source）より後に呼ぶ。
5. 登録できなかった Hotkey があれば報告する。Safe Reload による再読み込みだった場合は、完了を表示する。

### 機能を足すとき

- **Command**: [commands.lua](../modules/commands.lua) の `COMMANDS` に `id`、`label`、`run` を足す。`run = "<id>"` とコマンドパレットの両方で使えるようになる。
- **Hotkey の動作**: [hotkeys.lua](../modules/hotkeys.lua) の `ACTIONS` と `FIELDS` に名前を足し、`compile`（検証と変換）、`actionFor`（実行）、`defaultLabel`（表示名）を対応させる。
- **設定の項目**: 機能のモジュールに `validate(value, at)` を用意し、[preflight.lua](../modules/preflight.lua) の `SECTIONS` と `check` に加え、`init.lua` に適用を足す。`at:add(...)` で報告した問題は、項目の場所つきで表示される。

どの場合も `tests/` にテストを足し、[設定ガイド](configuration.md)、[用語集](../CONTEXT.md)、[検証手順](verification.md) を更新します。

## 設計判断

- **設定を `config.lua` に分けた。** Safe Reload で設定だけを読み直して検証するため。`init.lua` は起動の順序だけを持つ。
- **Hotkey を1つのリストにまとめた。** どのキーが何をするかを1か所で読め、Hotkey Identity の重複も1か所で検出できる。組み合わせは `"ctrl+i"` のような Chord で書く。
- **「特定のアプリでだけ有効」を Scope にした。** `only` / `except` をすべての Hotkey に持たせ、範囲が重ならない同じ組み合わせは許可する。これでアプリごとの使い分けができる。切り替えでは先に無効化してから有効化し、同じ組み合わせが同時に有効にならないようにする。
- **最前面アプリの監視は1つにした。** `frontmost.lua` が application watcher を1つだけ作り、Scope と Input Source に知らせる。
- **Safe Reload を設けた。** `config.lua` を保存すると Config Preflight を行い、通った場合だけ再読み込みする。通らなければ今の状態を保つ。再読み込みの前には `init.lua` と読み込み済みモジュールの構文も確かめる。ファイルの監視は入力に影響しないため、「問題があれば副作用を起こさない」の例外として、検証に失敗しても始める。
- **Hotkey の登録失敗は、残りを登録してから報告する。** 他のアプリが確保したキーなど、環境による失敗は Config Preflight では防げない。最初の失敗で止めても、その時点で一部は登録済みになるため、すべて試してからまとめて報告する。
- **問題は日本語で表示し、打ち間違いの候補を添える。** Console を開かなくても、画面の表示だけで直せるようにするため。
- **remap は `物理キー = "変換後のキー"` の形にした。** 変換元の重複は構造上書けず、変換の順序も意味を持たないため。
- **コマンドパレットの一覧は設定から作る。** Hotkey の早見表が設定とずれないようにするため。
- **App Switcher の分岐は実機での不具合対応の積み重ね。** Space と Finder まわりの分岐は、実機で見つかった問題への対応として足してきた。整理するときは [app_switcher_test.lua](../tests/app_switcher_test.lua) と [検証手順の App Switcher](verification.md#app-switcher) を必ず通す。主な前提は次のとおり。
  - 候補は Hammerspoon の標準 window filter と同じ subrole に限る。これで補助パネルや Finder のデスクトップを除く。
  - Space の所属一覧が空の要素（非表示タブなど）は候補から外す。これは Space 情報の取得失敗とは区別し、取得に失敗した場合は別の Space へ移動しない。
  - ウィンドウ一覧が空でも、メインウィンドウとフォーカス中のウィンドウを確かめてから再表示を要求する。別 Space のウィンドウが一覧に出ないアプリがあるため。

### 持たない機能

| 機能 | 理由 |
| --- | --- |
| Command キーの単体押しで英数・かなを切り替える | keyDown を常時監視するため、打ち始めが遅れる。左右 Command を hidutil で英数・かなキーに変換して代替する |
| 項目ごとの `enabled` | 無効にするなら行を消すかコメントアウトすればよく、無効な項目のための検証規則も要らない |

全面書き直し（2026-10-18、コミット `0bf243a`）より前の構成と、それまでの改善の経緯は Git の履歴にあります。
