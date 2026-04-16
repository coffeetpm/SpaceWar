# Run rhythm: 30–40 second micro-arc

## Goal

Each run forms a **complete micro-arc**. Emotion: short journey, complete cycle, repeatable momentum.

## Timing structure

| Time    | Phase           | Intent |
|---------|-----------------|--------|
| 0–8s    | Stabilize       | Player stabilizes weapon rhythm (opening phase; lower spawn density). |
| 8–18s   | Density up      | Enemy density increases. |
| 18–28s  | Ignition window | Build ignition moments appear (mid-run upgrade at 12s so synergy/ignition can trigger here). |
| 28–35s  | Peak pressure   | Max density. |
| 35–40s  | Release         | Boss spawn or wind-down; then run end. No abrupt cut. |

## Rules

- **No abrupt end:** After timer hits 0 or boss is defeated, a short **release** (default 1.5s) runs before game over. Flow continues into next run (restart / System Lab).
- **Ignition before run ends:** Mid-run upgrade at 12s ensures the player can have a synergy and experience build ignition in the 18–28s window.

## Implementation

- **StageManager:** Single run duration `run_duration` (default 38s). `mid_run_upgrade_at` (12s), `boss_spawn_at` (35s), `release_duration` (1.5s). States: RUNNING → (optional) CHOOSING_UPGRADE at 12s → RUNNING → RELEASE → GAME_OVER.
- **WaveSpawner (aligned to run rhythm):** Enemies support tempo, not chaos. When `_burst_duration` is 35–42s:
  - **0–10s light:** 1 per beat, slow delay (`delay_light`). Light pressure.
  - **10–20s structured:** Wave of 2 every 2nd beat, else 1 (`delay_structured`). Predictable waves.
  - **20–30s dense:** 2 per beat in a cluster (same angle ± small spread) (`delay_dense`).
  - **30–35s peak:** 2 per beat in formation (same base angle + `formation_spread_rad`) (`delay_peak`).
  - **35–40s release:** 1 per beat, slower (`delay_release`) so boss is readable.
  - **Min spawn delay** (`min_spawn_delay`) avoids random spawn bursts. No unreadable chaos.
- **RunState:** Opening phase 8s (`set_opening(4, 8)`) for 0–8s stabilize.
- **Boss:** Spawns at 35s into the run. If boss is defeated, boss clear sequence runs then run end (release → game over). If timer hits 0 with boss still up, run ends (release → game over).

## Exports (StageManager)

- `run_duration`: 38 (30–40s)
- `mid_run_upgrade_at`: 12
- `boss_spawn_at`: 35
- `release_duration`: 1.5
