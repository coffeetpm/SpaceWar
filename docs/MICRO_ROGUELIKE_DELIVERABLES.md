# Micro-Roguelike Run Pacing — Deliverables

**Goal:** Short, addictive runs (15–20s per stage), high player power, strong replay urge.

---

## TASK 1 — Stage duration

- **StageManager:** `const STAGE_DURATION := 60.0` replaced with **`@export_range(15.0, 20.0, 1.0) var stage_duration: float = 18.0`**.
- All uses of stage timer now use `stage_duration`; WaveSpawner receives it via `start_stage(stage_index, stage_duration)`.

---

## TASK 2 — Player power boost

**Script:** `scripts/weapons/weapon_base.gd`

| Stat | Before | After | Change |
|------|--------|-------|--------|
| **damage** | 1 | **2** | +60% (1.6 rounded) |
| **fire_rate** | 6.0 | **8.4** | +40% |
| **projectile_speed** | 450 | **518** | +15% |

Player feels strong from the first shot; upgrades stack on top.

---

## TASK 3 — Enemy tuning

**Scenes:** enemy_basic, enemy_scout, enemy_tank

| Enemy | max_hp Before | After |
|-------|----------------|--------|
| Basic (Fighter) | 3 | **2** |
| Scout | 2 | **1** |
| Tank | 6 | **3** |

**Spawn frequency:** WaveSpawner phase delays reduced and renamed:
- `delay_warmup` 0.58s (was delay_light 0.88)
- `delay_chaos` 0.32s (was delay_medium 0.5)
- `delay_peak` 0.18s (was delay_peak 0.28)

Enemies spawn faster and die faster; disposable but dangerous.

---

## TASK 4 — Flow pacing

**WaveSpawner** phases aligned to 18s (or configured stage length):

| Phase | Time | Delay |
|-------|------|--------|
| **Warm-up** | 0–5s | delay_warmup |
| **Chaos** | 5–12s | delay_chaos |
| **Peak** | 12–20s | delay_peak |

`_get_phase_spawn_delay()` uses `_stage_duration` (passed from StageManager) and elapsed time. Later **stages** scale spawn rate: `stage_scale = 1.0 - (stage_index - 1) * 0.06` (clamped 0.55–1.0) so later runs get slightly faster spawns (overwhelming later, per TASK 7).

---

## TASK 5 — Upgrade cadence

- **One upgrade per stage:** `_get_upgrade_choices()` now returns **1** random choice from the pool (shuffle + take first), not 3.
- **Instant return:** After stage clear, BeatConductor pulse delay reduced from 0.25s to **0.08s** before showing upgrade UI. On choice, upgrade is applied and gameplay resumes immediately (no long pause).

---

## TASK 6 — Replay psychology

- **Game over panel:** StageManager now tracks `_upgrades_taken_this_run` (display names), clears on `start_game()`, appends on `_on_upgrade_chosen()`, and passes to `_show_game_over()`.
- **New label:** **UpgradesTakenLabel** added to GameOver panel in main.tscn; text set to `"Upgrades: name1, name2"` or `"Upgrades: —"`.
- **Restart label:** Text set to **"Press R to Restart"** in `_show_game_over()`.
- **Instant restart:** Existing `run_end_menu.gd` already handles R → `get_tree().reload_current_scene()`. Player can restart within ~2 seconds.

---

## TASK 7 — Balance rule

- **Early stages easy:** Warm-up phase (0–5s) uses slowest spawn delay; base player damage/fire rate/speed are high so early clears are comfortable.
- **Later overwhelming:** `_get_phase_spawn_delay()` multiplies delay by `stage_scale` (down to 0.55 by later stages), so spawn frequency increases as stage index grows.
- **Never weak:** Base weapon stats are boosted; upgrades add on top so player never feels underpowered.

---

## Files changed

| Area | Files |
|------|--------|
| **StageManager** | `scripts/stage_manager.gd` (stage_duration, 1 upgrade, upgrade tracking, game over copy) |
| **Player / weapon** | `scripts/weapons/weapon_base.gd` (damage, fire_rate, projectile_speed) |
| **Enemies** | `scenes/enemies/enemy_basic.tscn`, `enemy_scout.tscn`, `enemy_tank.tscn` (max_hp) |
| **Spawn / pacing** | `scripts/enemies/wave_spawner.gd` (duration param, phases 0–5 / 5–12 / 12–end, stage scale) |
| **Game over UI** | `scenes/main/main.tscn` (UpgradesTakenLabel, RestartLabel text) |

No new paid assets; balance only.
