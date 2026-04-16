# Silhouette & Core Pass — Deliverables

## 1) Bullet design

### Node tree (Bullet scene)

```
Bullet (Area2D)
├── Trail (Line2D)          # width 8, thicker taper via width_curve
├── CollisionShape2D        # unchanged
└── Visual (Node2D)
    ├── Glow (Polygon2D)    # soft outer ring, 12-sided circle radius ~4.5
    └── Core (Polygon2D)    # bright inner dot, 12-sided circle radius ~1.5
```

- **Player bullet:** Glow/Core colors set in `setup()` from `ArtDirection.PLAYER_BULLET_GLOW` and `PLAYER_BULLET_CORE`; root `modulate` = `PLAYER_BULLET`.
- **Enemy bullet:** Same structure; colors from `ArtDirection.ENEMY_BULLET_GLOW` and `ENEMY_BULLET_CORE`; `modulate` = `ENEMY_BULLET`.
- **Trail:** `trail_width` = 8; `width_curve` = Curve(0→0.12, 0.5→0.5, 1→1) for thicker head and thin tail taper. Gradient and pooling unchanged.

### ArtDirection additions

- `PLAYER_BULLET_GLOW`, `PLAYER_BULLET_CORE`
- `ENEMY_BULLET_GLOW`, `ENEMY_BULLET_CORE`

Collisions and hitboxes unchanged. No new textures.

---

## 2) Enemy design language (procedural only)

Each enemy has:

- **(a) Outer silhouette:** `Visual/Outline` (Polygon2D) — dimmer fill.
- **(b) Inner bright core:** `Visual/Core` (Polygon2D) — brighter, smaller.
- **(c) Thin outline:** `Visual/OutlineLine` (Line2D) — closed loop tracing the silhouette, width 1.4, additive material for a premium edge.

### Node tree (per enemy)

```
EnemyXxx (CharacterBody2D)
├── Visual (Node2D)         # scale 1.15
│   ├── Outline (Polygon2D)   # silhouette fill
│   ├── Core (Polygon2D)      # bright core
│   └── OutlineLine (Line2D)  # thin edge, additive
├── CollisionShape2D        # unchanged
└── Pattern
```

### 3 variants

| Variant | Scene | Silhouette (Outline) | Core | OutlineLine |
|--------|--------|----------------------|------|-------------|
| **Scout** | enemy_scout.tscn | Diamond (4 pts) | Small diamond | Same points, closed |
| **Fighter** | enemy_basic.tscn | Boomerang (6 pts) | Diamond | Same points, closed |
| **Tank** | enemy_tank.tscn | Hexagon (6 pts) | Small hex | Same points, closed |

Colors and materials follow existing ArtDirection (neon_enemy_red / green / blue). Size and core brightness unchanged from previous pass; OutlineLine adds the premium edge. Collisions unchanged.

---

## 3) Hit readability — core pulse

- **Trigger:** In `enemy_base.gd` `take_damage()`, after `hit_flash_requested`, call `_pulse_core()`.
- **Behaviour:** `_pulse_core()` gets `Visual/Core` (CanvasItem) and runs a single tween (0.08s, EASE_OUT, QUAD):
  - **Scale:** from `(1.28, 1.28)` to `(1, 1)`.
  - **Modulate:** from `(2.2, 2.2, 2.2, 1)` to `(1, 1, 1, 1)` (brief brighten then back to normal).

No new scripts; logic lives in `enemy_base.gd`. Works with existing hit flash and hitstop.

---

## Summary

- **Bullet:** Bright core + soft glow (Visual/Glow + Visual/Core), thicker trail taper, palette from ArtDirection; pooling and performance unchanged.
- **Enemy:** All three variants have Outline + Core + OutlineLine; colors/size follow ArtDirection; collisions unchanged.
- **Hit:** Core pulse (scale + brighten) in `_pulse_core()` from `take_damage()`; no new nodes or textures.
