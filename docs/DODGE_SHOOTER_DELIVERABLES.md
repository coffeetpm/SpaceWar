# Skill-based Dodge Shooter — Deliverables

**Visual priority:** Player > Enemies > Bullets > Explosions > Background.  
**Not changed:** stage system, enemy personality pass, art_direction, camera framing.

---

## TASK 1 — Player readability boost

- **Stronger cockpit core glow:** `CockpitGlow` polygon slightly larger (0,-9 / 6,0 / 0,7 / -6,0), color alpha 0.62; `thruster_fx.gd` sets same in `_ready()`.
- **Thin outline edge:** New `Visual/BodyOutline` (Line2D), width 1.2, additive, color (0.45, 0.85, 1.2, 0.9), points = ship silhouette (0,-14 → -8,12 → 8,12 → 0,-14).
- **Trailing ribbon:** Existing `Trail` (width 5.5, gradient) unchanged; player remains clearest object.
- **Brightness:** Player core still uses `ArtDirection.TIER1_PLAYER_CORE` (brighter than enemy cores).

**Scene:** `player.tscn` — added `BodyOutline`; `CockpitGlow` size and alpha increased.

---

## TASK 2 — Movement language

- **Acceleration / inertia:** Already present; `FRICTION` increased 800 → 920 for slightly more decisive stop.
- **Micro tilt/lean:** In `player_controller.gd`, after `move_and_slide()` call `_update_lean(delta)`: `Visual.rotation` lerps toward `velocity.angle()` (clamped ±0.2 rad) when speed > 18; otherwise returns to 0. Speed threshold and clamp keep it subtle.
- **Thruster pulse by speed:** In `thruster_fx.gd` _process, read `(get_parent() as CharacterBody2D).velocity.length()`, compute `speed_ratio = clamp(velocity/300, 0, 1)`. Scale and alpha pulse bias toward stronger when moving (`pulse_bias = 0.2 + 0.6 * speed_ratio`), so thruster feels more alive at speed.

**Scripts:** `player_controller.gd`, `thruster_fx.gd`.

---

## TASK 3 — Dodge feedback (visual/audio only)

- **Detection:** In `bullet.gd` _physics_process, for **enemy** bullets only: if distance to player < `DODGE_NEAR_RADIUS` (26) and bullet direction dot (player - bullet) < -0.25 (moving away), trigger once per bullet (`_dodge_triggered`), emit `EventBus.near_dodge_feedback`.
- **Light ripple:** `dodge_feedback.gd` listens to `near_dodge_feedback`, spawns a short-lived Polygon2D circle at player position (additive, radius 28), tween scale 0.4→1.6 and alpha→0 over 0.12s, then queue_free.
- **Micro vibration:** Same handler calls `EventBus.screen_shake_requested.emit(0.06, 0.04)`.
- **Sound hook:** `DodgeFeedback/DodgeSound` (AudioStreamPlayer2D) with no stream assigned; script calls `play()` so a future sound can be wired without code change.

**Files:** `event_bus.gd` (signal `near_dodge_feedback`), `bullet.gd` (distance check + emit), `scripts/vfx/dodge_feedback.gd`, `main.tscn` (DodgeFeedback node + DodgeSound child).

---

## TASK 4 — Focus anchor

- **Node:** Under Player, `FocusAnchor` (Node2D, z_index -5), script `focus_anchor.gd`; child `Glow` (Polygon2D, 12-point circle radius 95, additive, faint blue).
- **Behaviour:** Each frame count nodes in group `"enemy"` within `enemy_radius` (420) of player. Set `Glow.modulate.a = lerp(alpha_min, alpha_max, t)` where `t = clamp(enemy_count / enemy_count_for_max, 0, 1)` (alpha_min 0.08, alpha_max 0.22, enemy_count_for_max 5). Glow fades when safe, increases when enemies near.

**Scene:** `player.tscn`. **Script:** `scripts/player/focus_anchor.gd`.

---

## TASK 5 — Bullet readability balance

- **No art_direction change.** In `bullet.gd` only: constant `BULLET_GLOW_ALPHA_SCALE := 0.72`. When setting `_visual_glow.color` (in `setup()` and `_process()` flicker), multiply alpha by this so outer glow is slightly reduced; core color/alpha unchanged.

---

## Deliverables summary

| Item | Location |
|------|----------|
| Player visual nodes | `player.tscn`: BodyOutline, CockpitGlow tweak, FocusAnchor/Glow |
| Movement / lean | `player_controller.gd`: _update_lean(), FRICTION |
| Thruster by speed | `thruster_fx.gd`: speed_ratio, pulse_bias |
| Dodge detection | `bullet.gd`: DODGE_NEAR_RADIUS, _dodge_triggered, emit on near-miss |
| Dodge feedback | `dodge_feedback.gd`, Main/DodgeFeedback, DodgeSound |
| Focus anchor | `focus_anchor.gd`, Player/FocusAnchor/Glow |
| Bullet glow | `bullet.gd`: BULLET_GLOW_ALPHA_SCALE |
| Camera hook | `EventBus.screen_shake_requested` used by dodge feedback (minimal) |

No new paid assets; stage, enemy personality, art_direction, and camera framing unchanged.
