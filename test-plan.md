# Noetica MVP-1 — test plan

## Scope

End-to-end runtime test of a single primary flow that proves the MVP works:
the loop **onboarding → create task linked to an axis → complete task → pentagon updates**.

If the pentagon-scoring path (axis linking, XP storage, decay calculation, or
custom-painter rendering) were broken, the resulting screen would visibly differ
from the expected outcome below.

## Pre-conditions

- App built locally: `build/linux/x64/debug/bundle/noetica`.
- DB and SharedPreferences wiped before launch:
  - `rm -f ~/Documents/noetica.db`
  - `rm -rf ~/.local/share/com.groyvi.noetica`

## Steps and assertions

| # | Action | Expected (must match) |
|---|---|---|
| 1 | Launch the binary. | Onboarding screen with title `noetica`, subtitle "Опиши свои оси роста", and 5 prefilled rows: Тело / Ум / Дело / Связи / Душа. Strict B/W, no gradients. |
| 2 | Click `Создать пентаграмму`. | Navigates to bottom-tab shell; "Лента" tab is selected; centred text "Лента пуста" is visible. |
| 3 | Click the floating `+` button. | Bottom sheet opens, titled "Новая запись"; segments "Заметка / Задача" with "Заметка" selected; 5 axis chips visible (◐ Тело, ◇ Ум, ■ Дело, ◯ Связи, ✦ Душа). |
| 4 | Click `Задача` segment. | New rows appear: `Без дедлайна` button and `XP при выполнении` slider with value indicator. |
| 5 | Type `Утренняя пробежка` into the title field, click the `Тело` axis chip, drag the XP slider to ~80. | Title shows the typed text; `Тело` chip becomes inverted (white background); XP value displays a number ≥ 70 and ≤ 90. |
| 6 | Click `Сохранить`. | Sheet closes; the timeline now shows one card with: timestamp, badge `задача`, title `Утренняя пробежка`, chip `◐ Тело`, chip `+80 XP` (or whatever XP was saved). |
| 7 | Tap the `Задачи` tab. | The same task is shown with an empty checkbox on the left. |
| 8 | Click the checkbox to the left of the task. | Checkbox fills (white square with check), task title gets strike-through and muted color. |
| 9 | Tap the `Я` tab. | Pentagon is rendered: 4 concentric reference rings + 5 spokes. **The top vertex (Тело) is visibly extended away from the centre toward the outer ring.** A filled translucent polygon points outward only along that vertex. The streak indicator shows `1 д.` in the top-right. |
| 10 | Inspect the "Текущее состояние" list under the pentagon. | Row `Тело` shows a numeric score in the range **30..50** with a partially filled progress bar. Rows `Ум`, `Дело`, `Связи`, `Душа` show value `0` with empty progress bars. |

## Why this is adversarial

A broken implementation of any of the following would produce a *visibly different* screen:

- **Axis chip → entry link broken**: completing the task would not update any axis, the pentagon would stay flat at 0 and the assertion in step 10 would fail.
- **XP storage broken**: `+80 XP` chip would not appear in step 6 and the score in step 10 would be 0.
- **Decay calc inverted**: the score would either be 100 or 0 instead of ~40 immediately after completion.
- **Custom painter mis-mapped vertex order**: a different vertex than the top one ("Тело") would extend in step 9, contradicting the visible label.
- **Tasks/Notes shared list broken**: step 6 would not show the task in the timeline, OR step 7 would show it as a note without the checkbox.

## Out of scope (deferred to future PRs)

- Date/time picker for `dueAt` (functional but not part of the primary loop).
- Time-gap dividers (require ≥2 entries with different timestamps; visual feature, not part of the scoring loop).
- Heatmap, "year ago", capsules, graph view, voice — none are in MVP-1.
