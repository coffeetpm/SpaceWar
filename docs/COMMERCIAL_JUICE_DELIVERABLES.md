# Commercial Juice & Art Direction — Deliverables

## Task A — Art Direction (implemented)

**File:** `scripts/autoload/art_direction.gd` (autoload: `ArtDirection`)

**Palette rules:**
- **Player + player bullets:** `PLAYER_PRIMARY`, `PLAYER_ACCENT`, `PLAYER_TRAIL_HEAD/TAIL`, `PLAYER_BULLET` (cyan/blue)
- **Enemies:** `ENEMY_PRIMARY`, `ENEMY_OUTLINE`, `ENEMY_CORE` (magenta/purple)
- **Enemy bullets:** `ENEMY_BULLET`, `ENEMY_BULLET_TRAIL_HEAD/TAIL` (yellow/green)
- **Rainbow:** `ArtDirection.get_explosion_gradient()` — used only for explosions/kill burst
- **Hit flash:** `HIT_FLASH_WHITE`, `PLAYER_DAMAGE_FLASH`

Use these constants in scripts and materials so colors stay consistent.

---

## Task B — Juice Pack (implemented)

### 1) Hitstop
- **EventBus:** `hitstop_requested(duration_sec: float, time_scale: float)`
- **Node:** Main → **Hitstop** (script: `scripts/vfx/hitstop.gd`)
- **Enemy hit:** In `enemy_base.gd` `take_damage()`: `EventBus.hitstop_requested.emit(0.05, 0.1)` (0.03–0.06s at 0.1)
- **Time scale manager:** Hitstop and player damage dip both go through the same node; it keeps min scale and max end time so they don’t override each other.

### 2) Enemy hit flash
- Already in place: `EventBus.hit_flash_requested.emit(_get_sprite(), 0.08)` in `enemy_base.gd`

### 3) Camera shake
- **Enemy hit:** `screen_shake_requested.emit(0.18, 0.08)` in `enemy_base.gd` `take_damage()`
- **Enemy kill:** `screen_shake_requested.emit(0.38, 0.14)` in `enemy_base.gd` `_die()`
- **Player damage:** `screen_shake_requested.emit(0.55, 0.22)` in `player_controller.gd`

### 4) Kill burst (two-stage)
- **explosion_vfx.gd:**  
  - **Stage 1:** `_spawn_core_flash(pos, scale)` — Polygon2D circle, additive, scale 0.25→2.2 + fade out over 0.08s, then `queue_free()`.  
  - **Stage 2:** `_spawn_rainbow_burst()` (or custom particle_scene) — CPUParticles2D with `ArtDirection.get_explosion_gradient()` and additive material.

### 5) Screen impact (player damage)
- **HitFlash:** Full-screen flash uses `ArtDirection.PLAYER_DAMAGE_FLASH` and **vignette shader**.
- **Shader:** `resources/shaders/vignette_flash.gdshader` — multiplies COLOR by radial vignette (darker at edges).
- **Material:** `resources/materials/vignette_flash_material.tres` on HitFlash/FlashLayer/FullScreenFlash (in Main.tscn).
- **Player damage:** `hit_flash_requested(null, 0.15)` + `time_scale_dip_requested(0.15, 0.3)`.

### EventBus additions
- `hitstop_requested(duration_sec: float, time_scale: float)`
- `time_scale_dip_requested(duration_real_sec: float, time_scale: float)` (player damage; handled by same Hitstop node)

---

## Task C — Bullet visuals (implemented)

- **Trail:** Width 6, gradient from palette (`PLAYER_TRAIL_TAIL/HEAD` or `ENEMY_BULLET_TRAIL_*`).  
- **Width curve:** Line2D `width_curve` = Curve (0.25 at tail, 1.0 at head) for thick head / thin tail.  
- **Color:** `modulate` = `ArtDirection.PLAYER_BULLET` or `ENEMY_BULLET` (no rainbow over lifetime).  
- **bullet.tscn:** Trail width 6, default_color from palette; Shape (Polygon2D circle) keeps neon material.

---

## Task D — Background (implemented)

- **Noise:** `resources/shaders/background_noise.gdshader` + `background_noise_material.tres`  
  - Slightly brighter dark/mid colors, `noise_strength` 0.1, `time_scale` 0.12 for slow movement.  
- **StarDust:** Main.tscn → World/StarDust (CPUParticles2D)  
  - `emission_shape` = 2 (Rectangle), `emission_rect_extents` = (2200, 1400)  
  - amount 48, lifetime 7, low velocity, subtle color (0.3, 0.3, 0.4, 0.28).

---

## Task E — UI polish (implemented)

**Main.tscn — UI/HUD:**
- New child: **HUDPanel** (Panel), anchored right: offset_left = -220, offset_top = 12, offset_right = -12, offset_bottom = 148.
- **Theme:** `theme_override_styles/panel` = SubResource **StyleBoxFlat_hud**:  
  - bg_color (0.08, 0.08, 0.12, 0.88), border 1px, border_color (0.25, 0.6, 0.95, 0.7), corner_radius 4, content margins 14.
- **Labels** moved under **HUDPanel:** WaveLabel, TimerLabel, HPLabel, EarnedLabel, TotalCurrencyLabel.
- **Hierarchy:**  
  - **Wave + Timer:** font_size 18.  
  - **HP:** font_size 14.  
  - **Earned / Total:** font_size 12.
- **RunCompleteLabel** stays direct child of HUD (center), unchanged.
- **game_hud.gd:** `@onready` paths updated to `$HUDPanel/WaveLabel`, etc.
- **stage_manager.gd:** `_hud.get_node_or_null("HUDPanel/WaveLabel")`, etc.

---

## Main.tscn node changes summary

| Where | Change |
|-------|--------|
| (root) | **Hitstop** node, script `scripts/vfx/hitstop.gd` |
| HitFlash/FlashLayer/FullScreenFlash | **material** = vignette_flash_material.tres |
| UI/HUD | **HUDPanel** (Panel) with StyleBoxFlat_hud |
| UI/HUD/HUDPanel | WaveLabel, TimerLabel, HPLabel, EarnedLabel, TotalCurrencyLabel (reparented, font sizes set) |
| World/Background | (existing noise material; values tuned in material/shader) |
| World/StarDust | emission_shape 2, emission_rect_extents (2200,1400), amount/lifetime/color tuned |

---

## WorldEnvironment (neon, not blown out)

**Resource:** `resources/environment/neon_glow.tres`

Suggested values (already set):
- **glow_enabled** = true  
- **glow_intensity** = 0.7  
- **glow_strength** = 1.35  
- **glow_bloom** = 0.15  
- **glow_blend_mode** = 1 (Additive)  
- **glow_hdr_threshold** = 0.85  
- **glow_hdr_scale** = 1.8  
- **glow_normalized** = true  
- **tonemap_mode** = 2 (Filmic)  
- **tonemap_white** = 1.2  
- **tonemap_exposure** = 1.0  

---

## New / modified files

**New:**
- `scripts/autoload/art_direction.gd`
- `scripts/vfx/hitstop.gd`
- `resources/shaders/vignette_flash.gdshader`
- `resources/materials/vignette_flash_material.tres`

**Modified:**
- `project.godot` (ArtDirection autoload)
- `scripts/autoload/event_bus.gd` (hitstop_requested, time_scale_dip_requested)
- `scripts/enemies/enemy_base.gd` (hitstop, shake on hit/kill)
- `scripts/vfx/explosion_vfx.gd` (two-stage: core flash + rainbow burst)
- `scripts/vfx/hit_flash.gd` (vignette material, ArtDirection flash color)
- `scripts/vfx/hitstop.gd` (unified time-scale handling)
- `scripts/player/player_controller.gd` (time_scale_dip via EventBus, trail palette)
- `scripts/weapons/bullet.gd` (palette, trail gradient, width_curve)
- `scripts/ui/game_hud.gd` (HUDPanel paths)
- `scripts/stage_manager.gd` (HUDPanel/ label paths)
- `scenes/main/Main.tscn` (Hitstop, vignette material, HUDPanel + StyleBox, label reparent/sizes, StarDust)
- `scenes/weapons/bullet.tscn` (trail width 6, shape color)
- `resources/shaders/background_noise.gdshader` (dark/mid, noise_strength, time_scale)
- `resources/materials/background_noise_material.tres` (matching params)
