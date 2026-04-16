# Commercial Framing Pass — Deliverables

## 1) Camera2D — Exact property changes

**Scene:** `scenes/vfx/game_camera.tscn`

| Property | Value |
|----------|--------|
| **zoom** | `Vector2(0.84, 0.84)` |

**Script:** `scripts/vfx/camera_shake.gd` (same node)

| Export / behaviour | Value / note |
|--------------------|--------------|
| **follow_smoothing** | `5.0` (higher = snappier; 4–8 range, ~5 = premium lag) |
| **breath_amplitude** | `2.0` (pixels; subtle drift) |
| **breath_speed** | `0.6` |
| **Smooth follow** | Camera `global_position` lerps toward player with `t = 1 - exp(-follow_smoothing * delta)`. |
| **Initial position** | In `_ready()`, if player exists, `_camera.global_position = _player.global_position`. |
| **Breathing** | `offset += Vector2(sin(time), cos(time*0.7)*0.8) * breath_amplitude`; applied every frame on top of shake. |

No change to art direction or hitstop.

---

## 2) Spawn density & 3-phase ramp — Exact parameters

**StageManager** (`scripts/stage_manager.gd`)

- In `_process()` when `State.RUNNING`: call `_set_spawner_stage_time()`.
- `_set_spawner_stage_time()`: `_wave_spawner.set_stage_time_remaining(stage_timer)`.

**WaveSpawner** (`scripts/enemies/wave_spawner.gd`)

- **Removed:** Fixed total spawn cap (`base_enemy_count + (wave-1)*count_per_wave`) and `spawn_delay` single value.
- **Added:** `set_stage_time_remaining(remaining: float)` — called each frame by StageManager with current stage timer (remaining seconds).
- **3-phase spawn delay (seconds between spawns):**

| Phase | Elapsed time in stage | Export | Default |
|-------|------------------------|--------|---------|
| Light | 0–20 s | `delay_light` | `0.95` |
| Medium | 20–45 s | `delay_medium` | `0.55` |
| Peak | 45–60 s | `delay_peak` | `0.32` |

- **Spawning:** Every `_get_phase_spawn_delay()` seconds, spawn one enemy; no per-stage count limit (stage runs 60 s, then `stop()`).
- **Not on player:** Spawn radius uses `min_radius_ratio` so distance from player is at least `spawn_radius * min_radius_ratio`.

| Parameter | Value |
|-----------|--------|
| **spawn_radius** | `320.0` |
| **min_radius_ratio** | `0.55` (spawn at 55–100% of radius; avoids spawning on top of player) |

---

## 3) Visual scaling

- **Enemy visuals:** In `enemy_basic.tscn`, `enemy_scout.tscn`, `enemy_tank.tscn`, the **Visual** node has **scale** = `Vector2(1.15, 1.15)` (~15% larger).
- **Bullet visual:** In `bullet.tscn`, the **Shape** (Polygon2D) node has **scale** = `Vector2(1.15, 1.15)` (~15% larger). Collision and trail unchanged.

---

## Before/after checklist (verify improvement)

**Camera**

- [ ] **Before:** Default zoom 1.0; camera fixed or no smooth follow; no breathing.  
- [ ] **After:** Zoom 0.84 (tighter frame); camera smoothly follows player with slight lag; very small drift/breathing on offset.

**Spawn / pacing**

- [ ] **Before:** Fixed number of enemies per stage; same spawn rate all stage.  
- [ ] **After:** Enemies spawn for full 60 s; 0–20 s lighter (slower), 20–45 s medium, 45–60 s peak (faster); screen rarely empty in mid/late phase.

**Spawn position**

- [ ] **Before:** Spawn ring could be close to player.  
- [ ] **After:** Spawns at 55–100% of `spawn_radius` (min_radius_ratio 0.55), so not on top of player.

**Readability**

- [ ] **Before:** Enemy and bullet shapes default size.  
- [ ] **After:** Enemy Visual and bullet Shape scaled to 1.15; bullets and enemies read better at 0.84 zoom without changing art direction or hitstop.
