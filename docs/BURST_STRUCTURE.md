# Arcade Micro-Run: Combat Burst Structure

## Overview

Runs are split into **Combat Bursts** (~30s each) and **Boss Bursts** (60s). After each burst: instant upgrade, then immediate next burst. Goal: rapid power growth, constant danger, instant replay.

---

## Combat Burst (30 seconds)

| Phase | Duration | Spawner phase | Feel |
|-------|----------|---------------|------|
| **Ramp**  | 0–10s  | `delay_ramp`  | Build-up |
| **Chaos** | 10–20s | `delay_chaos`  | Dense action |
| **Peak**  | 20–30s | `delay_peak`  | Maximum pressure |

- **Wave spawner**: `scripts/enemies/wave_spawner.gd` uses `_burst_duration - _burst_time_remaining` as elapsed; phase = elapsed vs `duration/3` and `2*duration/3`.
- **Scaling**: `apply_stage_scaling(burst_index)` on enemies; spawn delay scales down with burst index and is faster in boss bursts.

---

## Boss Burst (60 seconds)

- Trigger: every **N** bursts (e.g. every 3rd: bursts 3, 6, 9…). See `StageManager._is_boss_burst(burst_index)`.
- Duration: **60 seconds** (`boss_burst_duration` in StageManager).
- Phases: same 1/3–1/3–1/3 split → **20s ramp, 20s chaos, 20s peak**. Pattern-driven; spawner uses `is_boss` to apply higher intensity (e.g. `delay *= 0.85`).

---

## Flow

1. **Burst start** → `WaveSpawner.start_burst(burst_index, duration, is_boss)`.
2. **Each frame** → StageManager decrements `burst_timer`, calls `set_burst_time_remaining(burst_timer)` so spawner knows phase.
3. **Burst end** → Stop spawner, ~0.04s delay, show upgrade UI.
4. **Upgrade chosen** → `burst_index += 1`, set next `burst_timer` (30 or 60), resume spawner immediately.

---

## Key Files

- **scripts/stage_manager.gd** — Burst index, timer, boss timing, upgrade flow, HUD (“Burst %d” / “Boss!”), game over (“Bursts cleared”).
- **scripts/enemies/wave_spawner.gd** — `start_burst`, `set_burst_time_remaining`, ramp/chaos/peak by elapsed, boss intensity.
