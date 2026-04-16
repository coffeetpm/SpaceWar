# Enemy Presence & Motion Identity — Deliverables

**Goal:** Enemies feel like characters with presence; player feels heroic.  
**Not changed:** stage system, hitstop, art_direction, camera framing.

---

## TASK 1 — Enemy scale & presence

- **Enemy visual scale:** `Visual` scale `1.15` → `1.38` (~20% increase) on all three enemy scenes.
- **Player visual scale:** `Visual` scale `1.25` so player remains slightly larger than enemies.
- **Collision:** Unchanged (no gameplay change).

**Scenes:** `enemy_basic.tscn`, `enemy_scout.tscn`, `enemy_tank.tscn`, `player.tscn`.

---

## TASK 2 — Enemy motion identity

**Script:** `scripts/enemies/enemy_base.gd`

- **Exports:** `dart_amount`, `strafe_amount`, `trail_length`.
- **Scout:** `dart_amount = 52`, fast perpendicular dither (`sin(t * 8)`), `trail_length = 14`, light trail.
- **Fighter (Basic):** `strafe_amount = 35`, side motion (`sin(t * 4.5)`), `trail_length = 8`.
- **Tank:** no dart/strafe (direct move), no trail; **camera rumble when near** (see below).

Movement: `velocity = dir * move_speed + perp * (dart_amount * sin(8t) + strafe_amount * sin(4.5t))`.

---

## TASK 3 — Enemy visual layering

| Layer | Node | Notes |
|-------|------|--------|
| **A** | `Visual/Outline` | Outer body silhouette (unchanged). |
| **B** | `Visual/Core` | Inner energy core (unchanged). |
| **C** | `Visual/Trail` (Scout, Fighter) / `Visual/Aura` (Tank) | Motion trail or aura. |
| **D** | Core scale + modulate tween on hit | `_pulse_core()` in `enemy_base.gd`. |

**Node changes:**
- **Scout:** Added `Visual/Trail` (Line2D, z_index -2, width 3, soft green).
- **Fighter:** Added `Visual/Trail` (Line2D, z_index -2, width 2.5, short red tint).
- **Tank:** Added `Visual/Aura` (Polygon2D, z_index -3, hex slightly larger than Outline, dim blue).

Trail points updated in `_process()` from `_trail_points` (length from `trail_length` export).

---

## TASK 4 — Core behaviour

**Script:** `enemy_base.gd` — `_update_core_visual()`, `_pulse_core()`, `_die()`.

| State | Behaviour |
|-------|-----------|
| **Idle** | Core modulate slow pulse: `0.94 + 0.06 * sin(Time * 0.002)`. |
| **On attack** | When firing: `_attack_brighten_until = now + 0.18`; core modulate `* 1.35`. |
| **On hit** | `_pulse_core()`: scale 1.28→1, modulate 2.2→1 over 0.08s; `_hit_pulse_until` prevents idle/attack overwrite. |
| **On death** | `_die()`: set `_death_started`, disable collision, tween Core scale to 0 over 0.06s, then `_finish_death()` → explosion, `queue_free()`. |

No new scripts; all in existing `enemy_base.gd`.

---

## TASK 5 — Player hero presence

- **Scale:** `player.tscn` → `Visual` scale `1.25`.
- **Thruster glow pulse:** Already in `thruster_fx.gd` (scale + alpha pulse).
- **Cockpit core:** Already Tier 1 in `thruster_fx.gd`.
- **Trailing light ribbon:** `player.tscn` Trail width `4` → `5.5`, default_color slightly brighter; `player_controller.gd` already updates trail from position history (TRAIL_LENGTH 24, gradient).

---

## TASK 6 — Combat readability

- **Player:** Largest (1.25), cyan/blue, trailing ribbon, cockpit Tier 1.
- **Scout:** Darting, green diamond, light trail.
- **Fighter:** Strafing, red asymmetric shape, short trail.
- **Tank:** Slow, blue hex, aura, camera rumble when close.
- **Bullets:** Unchanged (player cyan, enemy yellow-green).

Groups: `enemy`, `enemy_scout`, `enemy_fighter`, `enemy_tank` (set in scene root for camera/targeting).

---

## Camera rumble (tank near)

**Script:** `scripts/vfx/camera_shake.gd`

- **Exports:** `tank_rumble_radius = 280`, `tank_rumble_min = 0.04`.
- **Logic:** `_is_tank_nearby()` returns true if any node in group `enemy_tank` is within `tank_rumble_radius` of player. If true, `_trauma = max(_trauma, tank_rumble_min)` so decay never goes below a subtle rumble.

---

## Files touched

| Area | Files |
|------|--------|
| Enemies | `enemy_base.gd`, `enemy_basic.tscn`, `enemy_scout.tscn`, `enemy_tank.tscn` |
| Player | `player.tscn` |
| Camera | `camera_shake.gd` |

No new paid assets; no new autoloads or stage/hitstop/art_direction changes.
