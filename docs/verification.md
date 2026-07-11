# Verification

この repo は、再現可能な **Automated Verification** と、macOS integration を実機で確認する **Manual Runtime Verification** の二層で検証する。

## Automated Verification

repo root で次を実行する。

```sh
./scripts/check
```

この command は次を検証する。

- production code と test code の Lua syntax
- `init.lua` と `modules/*.lua` が Git で追跡されていること
- fake `hs` adapter を使った behavior contract

Hammerspoon IPC には接続しない。`hs -c` が利用できない環境でも成功することを前提とする。

## Manual Runtime Verification

Automated Verification が成功してから実施する。Hammerspoon menu の **Reload Config** を使い、Console に error がないことを最初に確認する。

### Config Preflight

1. `config.reload.key` を一時的に `F6` へ変更する。
2. 同時に `config.unicodeConverter.enabled = "invalid"` と、先頭の App Switcher に `dirToOpen = 42` を設定する。
3. Hammerspoon menu の **Reload Config** を実行する。Hotkey ではなく menu を使う。
4. Console に一つの `invalid Hammerspoon config:` error が表示され、その中に `config.unicodeConverter.enabled` と `config.appSwitchers[1].dirToOpen` の両方が含まれることを確認する。
5. `F6` を押しても reload 用の `cmd+r` が送信されず、validation 失敗後に新しい Hotkey が登録されていないことを確認する。
6. 3か所を元の値へ戻し、Hammerspoon menu の **Reload Config** を実行する。
7. Console に error がなく、`F5` と以降の対象 checklist が動作することを確認する。

### Input Remap

- [ ] `hidutil property --get 'UserKeyMapping'` に `caps_lock` → `left_control` と `left_control` → `left_command` の2 mapping がある。
- [ ] `hidRemap.enabled = false` に変更して reload すると `UserKeyMapping` が空になり、`true` に戻して reload すると上記2 mapping が復旧する。
- [ ] 物理 `caps_lock+i/j/k/l` がそれぞれ `up/left/down/right` として動く。
- [ ] `caps_lock+i/j/k/l` の長押しで arrow が repeat する。
- [ ] 物理 `left_control` を Command key として使える。
- [ ] 左 Command key の単体押しで `英数`、右 Command key の単体押しで `かな` に切り替わる。
- [ ] Command key を shortcut chord として使った場合、単体押しの入力切替が発火しない。
- [ ] 左右 Command key を同時に押して離しても入力切替が発火せず、その後の左右それぞれの単体押しが動作する。

### Hotkey と App Switcher

- [ ] `F5` が frontmost app へ `cmd+r` を送信する現在の behavior を維持する。
- [ ] 対象 app が未起動の場合、App Switcher Hotkey で起動する。
- [ ] frontmost app で同じ Hotkey を押すと hide する。
- [ ] 非 frontmost app で同じ Hotkey を押すと focus する。
- [ ] 複数 window がある app で focus 対象が cycle する。
- [ ] MarkEdit の directory が利用できない場合でも通常起動へ fallback する。

### Unicode Converter

1. `init.lua` の `unicodeConverter.enabled` が `false` の状態で reload し、`cmd+shift+u` が登録されないことを確認する。
2. `enabled = true` に変更して reload する。
3. `cmd+shift+u` で chooser が開くことを確認する。
4. `U+3042` → `あ` と `あ` → `U+3042` を確認する。
5. 検証後は `enabled = false` に戻して reload する。

## 失敗時

意図しない user-visible behavior があれば、次のマイルストーンへ進まない。変更を修正または取り消してから、Automated Verification と対象 checklist を再実行する。

modifier mapping により操作が難しくなった場合は、別の terminal または入力手段から次を実行すると `hidutil` mapping を解除できる。

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```

その後、問題のある設定を修正して Hammerspoon を reload する。
