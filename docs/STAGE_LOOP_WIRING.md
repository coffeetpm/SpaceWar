# Stage-based roguelike loop — wiring and checklist

## 1. StageManager script and node

**Script:** `res://scripts/stage_manager.gd`  
**Node:** `Main` → `World` → **StageManager** (Node, script attached)

**Exported NodePaths (set in Inspector or in .tscn):**
- `hud_path` → `../../UI/HUD` (from World/StageManager, so Main/UI/HUD)
- `upgrade_choice_path` → `../../UI/UpgradeChoice`
- `game_over_path` → `../../UI/GameOver`
- `wave_spawner_path` → `../Enemies/WaveSpawner` (World/Enemies/WaveSpawner)

**Signals / events:**
- Listens: `EventBus.player_died` → `_on_player_died`
- Connects to: `UpgradeChoice` → `upgrade_chosen` (or `upgrade_selected`) → `_on_upgrade_chosen`

No other scripts need to reference StageManager by name; Main calls `World/StageManager.start_game()` in `_ready()`.

---

## 2. WaveSpawner changes

**Script:** existing `res://scripts/enemies/wave_spawner.gd` (attached to `World/Enemies/WaveSpawner`)

**Added API (no rewrite):**
- `start_stage(stage_index: int)` — sets current stage, resets counters, sets `_stopped = false`
- `stop()` — sets `_stopped = true` (spawn loop in `_process` exits)

**Removed:** `EventBus.stage_started` connection and `StageMgr` / `StageManager.State` checks. Spawn is driven only by `start_stage()` and `stop()` from StageManager.

**Spawn intensity:** `to_spawn = base_enemy_count + (_current_wave - 1) * count_per_wave` (unchanged).

---

## 3. UpgradeChoiceUI changes

**Script:** existing `res://scripts/upgrades/upgrade_choice_ui.gd` (on `UI/UpgradeChoice`)

**Added:**
- Signal: `upgrade_chosen(upgrade_resource: Resource)` — emitted when the player picks an option (in addition to `upgrade_selected(upgrade: UpgradeData)`).

**Changed:**
- On choice pressed: no longer calls `StageMgr.choose_upgrade(upgrade)`. Only emits `upgrade_selected` and `upgrade_chosen`; StageManager connects to `upgrade_chosen` and applies via `UpgradeManager.apply()`.

**Unchanged:**
- Still listens to `EventBus.upgrade_choice_requested(choices: Array)` to show three options and populate buttons.
- Still uses existing upgrade .tres from `resources/upgrades/`.

---

## 4. SaveManager (autoload)

**Script:** `res://scripts/autoload/save_manager.gd`  
**Autoload name:** `SaveManager` (in Project Settings)

**API:**
- `add_currency(amount: int)` — adds to `total_currency`, then `save()`
- `record_run(stages: int)` — increments `total_runs`, updates `best_stage` if `stages` is higher, then `save()`
- `save()` / `load()` — persist to `user://save.json` (JSON + FileAccess)
- `get_total_currency()`, `get_total_runs()`, `get_best_stage()` — read from loaded meta

**Fields in save:** `total_currency`, `total_runs`, `best_stage`.

StageManager calls `SaveManager.add_currency(stages_cleared * 10)` and `SaveManager.record_run(stages_cleared)` on player death.

---

## 5. UI wiring

**HUD (`UI/HUD`):**
- `WaveLabel`, `TimerLabel`, `EarnedLabel`, `TotalCurrencyLabel` — updated by **StageManager** in `_process` and `_update_hud()` (StageManager gets HUD via `hud_path`).
- `HPLabel` — still updated by HUD from the player node (unchanged).

**UpgradeChoice (`UI/UpgradeChoice`):**
- Show/hide: StageManager stops the stage and emits `EventBus.upgrade_choice_requested(choices)` → UI shows and fills three buttons.
- On pick: UI emits `upgrade_chosen(upgrade_resource)` → StageManager applies upgrade and starts next stage.

**GameOver (`UI/GameOver`, RunEndMenu script):**
- StageManager fills **Panel/StagesClearedLabel**, **Panel/CurrencyEarnedLabel**, **Panel/TotalCurrencyLabel** and then calls `show()` on the GameOver control before emitting `EventBus.game_over`.
- RunEndMenu still listens to `EventBus.game_over` and calls `show()` (so panel is shown; labels already set by StageManager).
- R to restart: unchanged (RunEndMenu handles input and reloads scene).

---

## 6. Scene wiring summary

| Where | What |
|-------|------|
| **Main** | In _ready: `get_node("World/StageManager").start_game()` (or `get_node_or_null` + `has_method("start_game")` then call). |
| **World** | Child node **StageManager** (Node), script `scripts/stage_manager.gd`, four NodePaths set as above. |
| **World/Enemies/WaveSpawner** | Same script; no new nodes. StageManager calls `start_stage(i)` and `stop()`. |
| **UI/UpgradeChoice** | Same script; no new nodes. StageManager connects to `upgrade_chosen` (or `upgrade_selected`) in its `_ready`. |
| **UI/GameOver** | Same script (RunEndMenu); no new nodes. StageManager sets Panel labels and calls `show()` on death. |
| **UI/HUD** | Same script; no new nodes. StageManager updates Wave/Timer/Earned/Total via `hud_path`. |

**Removed:** Autoload `StageMgr` (old `scripts/autoload/stage_manager.gd`) from Project Settings so the only stage flow is the node `World/StageManager`.

---

## 7. Run checklist (editor test)

1. **Open project** and run **Main** (F5 or Play).
2. **Stage 1:** HUD shows "Stage 1", timer counts down from 60, enemies spawn; WaveSpawner runs.
3. **Timer → 0:** Spawning stops, game pauses (time_scale 0), UpgradeChoice appears with 3 options.
4. **Pick one upgrade:** UpgradeChoice hides, timer resets to 60, "Stage 2" appears, spawning resumes with higher intensity.
5. **Die (e.g. run into enemies):** Spawning stops, GameOver panel appears with:
   - Stages cleared
   - Currency earned (stages_cleared * 10)
   - Total currency (from SaveManager)
   Press R to reload.
6. **Persistence:** Run again; total currency and total runs should reflect previous run (check `user://save.json` or HUD "Total").
7. **No duplicate systems:** Only one StageManager (node under World); no autoload StageMgr. Bullets still use pool; player and weapon code unchanged.

If UpgradeChoice does not appear when the timer hits 0, check that `EventBus.upgrade_choice_requested` is emitted and that `UI/UpgradeChoice` is listening. If GameOver labels are empty, check that StageManager’s `game_over_path` points to `UI/GameOver` and that the Panel has `StagesClearedLabel`, `CurrencyEarnedLabel`, `TotalCurrencyLabel`.
