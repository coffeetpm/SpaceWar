# Silhouette & Light Language Pass — Deliverables

Close-range neon shooter: **Hybrid A+B** (Geometry Wars silhouette clarity + Tetris Effect light & particles).  
**Not changed:** camera, spawn density, art_direction system, hitstop system. No new assets.

---

## RULE 1 — Shape first (4 layers)

- **Layer 1 (shape):** Clear polygon silhouette, readable without glow.  
- **Layer 2 (core):** Small bright center, brightest element.  
- **Layer 3 (light wrap):** Soft bloom around silhouette (`neon_sprite.gdshader` edge falloff).  
- **Layer 4 (particles):** Optional; must not hide silhouette (see RULE 6).

---

## TASK 1 — Bullet redesign (RULE 2)

### Visual structure
- **Head = solid shape** — `Visual/Core` (Polygon2D), z_index 0, on top.
- **Glow around head** — `Visual/Glow` (Polygon2D), z_index -1 (light wrap).
- **Tapered trail** — `Trail` (Line2D), z_index -2; **trail opacity lower than core** (TIER3 head alpha 0.52 / 0.5 vs core 0.96).

### Colors (ArtDirection)
- Core: `TIER2_BULLET_CORE_PLAYER` / `TIER2_BULLET_CORE_ENEMY`.
- Glow: `TIER2_BULLET_GLOW_PLAYER` / `TIER2_BULLET_GLOW_ENEMY`.
- Trail gradient: `TIER3_TRAIL_HEAD_*` → `TIER3_TRAIL_TAIL_*` (reduced alpha so trail never competes with core).

### Glow flicker
- **`bullet.gd`** — `_process()`: Glow alpha pulse `0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.008)`.

### Scene (`bullet.tscn`)
- Draw order: Trail (back) → Glow → Core (front). Default trail color alpha 0.5.

---

## TASK 2 — Enemy silhouette upgrade

### Structure (per enemy)
- **Outer body** — `Visual/Outline` (Polygon2D), dim (Tier 3 style).
- **Inner energy core** — `Visual/Core` (Polygon2D), brightest element.
- **Optional outline** — `Visual/OutlineLine` (Line2D), thin edge.

### Light hierarchy
- Outline (body) dimmed in scene colors.  
- Core left brighter (existing per-variant colors).  
- On hit: **`scripts/enemies/enemy_base.gd`** — `_pulse_core()` already pulses core scale and brightness; unchanged.

### Scene changes (body dimmer only)
- **`enemy_basic.tscn`** — `Outline` color: `(0.28, 0.08, 0.14, 0.72)`.
- **`enemy_scout.tscn`** — `Outline` color: `(0.2, 0.28, 0.12, 0.68)`.
- **`enemy_tank.tscn`** — `Outline` color: `(0.12, 0.14, 0.35, 0.7)`.

---

## TASK 3 — Player ship lighting

### Node changes (`scenes/player/player.tscn`)
- **CockpitGlow** (new) — Polygon2D, z_index -1, diamond slightly larger than Cockpit; color from `ArtDirection.TIER1_COCKPIT_GLOW` in script.
- **Cockpit** — Color set in **`thruster_fx.gd`** to `ArtDirection.TIER1_PLAYER_CORE` (player core always brighter than enemy cores).
- **TopEdge** (new) — Line2D along top of ship: points `(0,-14) → (-8,12) → (8,12) → (0,-14)`; additive material; color from `ArtDirection.TIER1_COCKPIT_GLOW` (alpha 0.88).
- **Thruster** — **`scripts/player/thruster_fx.gd`**: existing scale pulse kept; added **thruster glow pulse** by modulating only alpha between `thruster_alpha_min` (0.72) and `thruster_alpha_max` (0.98) with same sine timing.

### Brightness rule
- Player core (Cockpit + CockpitGlow) uses Tier 1 constants; enemy cores remain Tier 2 in hierarchy.

---

## TASK 4 — Light contrast tiers

### **`scripts/autoload/art_direction.gd`**
- **Tier 1 (brightest):** `TIER1_PLAYER_CORE`, `TIER1_COCKPIT_GLOW`, `TIER1_EXPLOSION_CORE`.
- **Tier 2:** `TIER2_BULLET_CORE_PLAYER`, `TIER2_BULLET_CORE_ENEMY`, `TIER2_BULLET_GLOW_*`; enemy cores (per-scene hues).
- **Tier 3:** `TIER3_TRAIL_HEAD_*`, `TIER3_TRAIL_TAIL_*`; enemy bodies (Outline colors dimmed in scenes).
- **Tier 4:** Background (reference; keep dark).

Enforcement: bullets, player, explosion use these constants; enemy bodies darkened in tscn; no new materials/shaders for tiers.

---

## TASK 5 — Close-range pressure feel

### Vignette
- **`resources/shaders/pressure_vignette.gdshader`** — New: fullscreen overlay, `intensity` uniform (0–0.5), darkens edges.
- **`resources/materials/pressure_vignette_material.tres`** — ShaderMaterial using above, default intensity 0.
- **`scenes/main/main.tscn`** — New node **PressureVignette** (script `pressure_vignette.gd`) with child **PressureLayer** (CanvasLayer, layer 45) and **ColorRect** (fullscreen, material = pressure_vignette_material).
- **`scripts/vfx/pressure_vignette.gd`** — Counts enemies in group `"enemy"` within `radius` (380) of player; when count ≥ `enemy_count_threshold` (4), sets vignette `intensity` up to `vignette_max` (0.18).

### Bloom
- Same script duplicates **WorldEnvironment.environment** in `_ready()` and assigns it back so the scene resource is not modified. In `_process()`, sets `environment.glow_intensity = _base_glow + pressure * bloom_boost_max` (0.06 max) when many enemies are near.

---

## Summary of files touched

| Area | Files |
|------|--------|
| Bullet | `bullet.gd`, `art_direction.gd` |
| Enemy | `enemy_basic.tscn`, `enemy_scout.tscn`, `enemy_tank.tscn` |
| Player | `player.tscn`, `thruster_fx.gd`, `art_direction.gd` |
| Tiers | `art_direction.gd`, `explosion_vfx.gd` |
| Pressure | `pressure_vignette.gd`, `pressure_vignette.gdshader`, `pressure_vignette_material.tres`, `main.tscn` |

No new paid assets; all changes use existing or new in-project shaders/materials.

---

## RULE 6 — Particles secondary

Particles decorate motion; they must not define or overpower silhouettes.

### Brightness adjustments (ArtDirection + scenes)
- **`PARTICLE_THRUSTER`** — ThrusterParticles (player): applied in `thruster_fx.gd` _ready(); scene fallback `(0.18, 0.45, 0.7, 0.35)`.
- **`PARTICLE_EXPLOSION_BASE`** — Rainbow burst in `explosion_vfx.gd`: `(0.7, 0.7, 0.8, 0.5)`.
- **`PARTICLE_BEAT_DUST`** — BeatDust in `main.tscn`: `(0.55, 0.55, 0.7, 0.38)`.
- **`PARTICLE_AMBIENT`** — StarDust in `main.tscn`: `(0.22, 0.22, 0.3, 0.22)`.

### Material / shader tweaks
- **`neon_sprite.gdshader`** — Light wrap: `smoothstep(0.2, 1.25, length(center))`, `mix(0.35, 1.0, edge)` for slightly softer bloom around silhouettes.
