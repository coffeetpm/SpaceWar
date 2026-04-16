# Procedural Ship & Bullet Visuals (Polygon2D + Neon)

Replace square ColorRects with procedural shapes: Polygon2D silhouettes + existing neon shader. Collisions and hitboxes unchanged.

---

## A) Player Ship

### Node tree (under `World/Player`)

```
Player (CharacterBody2D)
├── Trail (Line2D)           # unchanged; additive material
├── Visual (Node2D)           # NEW: script = thruster_fx.gd
│   ├── Thruster (Polygon2D)  # rear flame triangle
│   ├── Body (Polygon2D)      # main triangle
│   ├── WingL (Polygon2D)
│   ├── WingR (Polygon2D)
│   ├── Cockpit (Polygon2D)   # small diamond
│   └── ThrusterParticles (CPUParticles2D)  # optional rear particles
├── CollisionShape2D
├── Hitbox (Area2D)
└── WeaponMount
```

- **Removed**: `Sprite` (ColorRect).
- **Hit flash**: `player_controller.gd` uses `sprite = $Visual` so the whole Visual flashes.
- **Thruster**: `scripts/player/thruster_fx.gd` on Visual pulses `Thruster` polygon scale (pulse_speed, scale_min, scale_max). ThrusterParticles use additive material.

### Swap steps (no collision break)

1. Add `Visual` (Node2D) under Player; attach `res://scripts/player/thruster_fx.gd`.
2. Add Polygon2D children: Thruster, Body, WingL, WingR, Cockpit; set each `material = neon_sprite_material.tres`, set `color` as desired.
3. Optionally add `ThrusterParticles` (CPUParticles2D) under Visual; material = additive_material.
4. In `player_controller.gd` set `@onready var sprite: CanvasItem = $Visual` (was `$Sprite`).
5. Remove the old `Sprite` (ColorRect) node. CollisionShape2D and Hitbox are unchanged.

---

## B) Enemy Silhouettes (3 variants)

### Shared structure (per enemy scene)

```
EnemyXxx (CharacterBody2D, script = enemy_base.gd)
├── Visual (Node2D)
│   ├── Outline (Polygon2D)   # dim color
│   └── Core (Polygon2D)     # bright color
├── CollisionShape2D
└── Pattern (optional)
```

- **Removed**: `Sprite` (ColorRect).
- **Hit flash**: `enemy_base.gd` `_get_sprite()` returns `Visual` if present, else `Sprite`. So flash applies to Visual.

### Variants

| Type    | Scene                 | Shape outline        | Core    | Material (base_color)     |
|---------|------------------------|------------------------|---------|----------------------------|
| Scout   | enemy_scout.tscn      | Small diamond (4 pts) | Diamond | neon_enemy_green.tres      |
| Fighter | enemy_basic.tscn      | Boomerang (6 pts)      | Diamond | neon_enemy_red.tres        |
| Tank    | enemy_tank.tscn       | Hexagon (6 pts)        | Hexagon | neon_enemy_blue.tres       |

- **Scout**: Outline (0,-8),(8,0),(0,8),(-8,0); Core (0,-4),(4,0),(0,4),(-4,0). Smaller collision (radius 8), faster, less HP.
- **Fighter**: Outline (0,-6),(-12,0),(-6,6),(0,3),(6,6),(12,0); Core (0,-3),(-5,0),(0,3),(5,0).
- **Tank**: Outline hexagon radius 10; Core hexagon radius 4. Larger collision (radius 14), slower, more HP.

### Swap steps (no collision break)

1. In each enemy scene, add `Visual` (Node2D) with children `Outline` and `Core` (Polygon2D).
2. Set polygon arrays and `color` (dim for Outline, bright for Core); set `material` to the appropriate neon_enemy_*.tres.
3. Ensure `enemy_base.gd` has `_get_sprite()` that returns `Visual` when present (already updated).
4. Remove the old `Sprite` (ColorRect). CollisionShape2D and Pattern are unchanged.

### Using Scout/Tank in waves

- Wave spawner currently uses a single `enemy_scene`. To mix types, either:
  - Change `enemy_scene` to a random choice from `[enemy_scout, enemy_basic, enemy_tank]`, or
  - Use a spawn table (e.g. wave 1 = scout, 2 = scout+fighter, 3 = all three).

---

## C) Bullet Visual

### Node tree (under Bullet Area2D)

```
Bullet (Area2D)
├── Trail (Line2D)      # unchanged
├── CollisionShape2D    # unchanged (rectangle)
└── Shape (Polygon2D)  # NEW: 12-sided circle, neon material
```

- **Removed**: `Sprite` (ColorRect).
- **Rotation / modulate**: Bullet node’s `rotation` and `modulate` (HSV over lifetime) apply to children; Shape and Trail inherit them. No script change.

### Swap steps (no collision break)

1. Add `Shape` (Polygon2D) under Bullet; set `polygon` to a circle (e.g. 12 points, radius 3), `material = neon_sprite_material.tres`, `color` as desired.
2. Remove the old `Sprite` (ColorRect). CollisionShape2D and Trail unchanged.

---

## Scripts

| Script               | Purpose |
|----------------------|--------|
| thruster_fx.gd       | On Player/Visual: pulses Thruster polygon scale for flame effect. Exports: thruster_path, pulse_speed, scale_min, scale_max. |

No other new scripts. `player_controller.gd` only change: `sprite = $Visual`. `enemy_base.gd` only change: `_get_sprite()` returns `Visual` if present.

---

## Materials

- **Player / Bullet**: `res://resources/materials/neon_sprite_material.tres` (existing).
- **Enemy Fighter**: `res://resources/materials/neon_enemy_red.tres`.
- **Enemy Scout**: `res://resources/materials/neon_enemy_green.tres`.
- **Enemy Tank**: `res://resources/materials/neon_enemy_blue.tres`.
- **Trails / particles**: `res://resources/materials/additive_material.tres` (unchanged).

All use the same `neon_sprite.gdshader`; enemy materials only differ by `base_color`.
