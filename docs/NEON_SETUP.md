# Neon Look – Editor Setup & Properties

Minimal-asset neon style: glow (bloom), additive blending, neon shader, trails, hit flash, camera shake, dark background.

---

## 1. WorldEnvironment + Glow (Bloom) for 2D

**Nodes**
- In **Main** scene: add **WorldEnvironment** (same level as World, e.g. under root).
- Assign **Environment** resource: `res://resources/environment/neon_glow.tres`.

**Environment resource** (`resources/environment/neon_glow.tres`) – recommended values (neon, not blown out):
- **Background Mode**: `Canvas` (1).
- **Glow**
  - **Enabled**: On
  - **Intensity**: `0.7`
  - **Strength**: `1.35`
  - **Bloom**: `0.15`
  - **Blend Mode**: `Additive` (1)
  - **HDR Threshold**: `0.85`
  - **HDR Scale**: `1.8`
  - **Normalized**: On (if using non-Compatibility renderer)
- **Tonemap** (optional, keeps brights from clipping)
  - **Mode**: `Filmic` (2)
  - **White**: `1.2`
  - **Exposure**: `1.0`

**Project Settings (optional for stronger glow)**
- **Rendering → Viewport**: enable **Use HDR 2D** if available (improves glow on some setups).
- With **GL Compatibility** renderer, glow uses a simpler path but still works.

**Making objects glow**
- Set **raw color channel values above 1.0** (e.g. `Color(1.2, 1.2, 1.2)` or `Color(0.3, 0.9, 1.2)`).
- Player and bullet sprites in the project use values > 1.0 on the main channel where applicable.

---

## 2. Additive Blending (Bullets & Particles)

**Material**
- **Resource**: `res://resources/materials/additive_material.tres`
- **Type**: `CanvasItemMaterial`
- **Blend Mode**: `Additive` (1)
- **Light Mode**: `Unshaded` (1)

**Where it’s used**
- **Bullet** scene: assign this material to **Trail** (Line2D) and **Sprite** (ColorRect) → Material property.
- **Player** scene: assign to **Trail** (Line2D) → Material property.
- **Explosion VFX**: fallback CPUParticles2D has this material set in code; any custom particle scene should use the same material on the node’s **Material** property.

---

## 3. Rainbow Gradient on Bullets (HSV Over Lifetime)

**Logic (in code)**
- In `scripts/weapons/bullet.gd`, over bullet lifetime:
  - `life_ratio = 1 - (timer / lifetime)` (0 → 1).
  - `hue = (life_ratio * 0.85) % 1.0`.
  - `modulate = Color.from_hsv(hue, 0.75, 1.0)`.
- No extra assets; applied each frame to the bullet (sprite + trail).

**Optional shader (alternative)**  
If you prefer a shader on the bullet sprite:
- Create **ShaderMaterial** on the bullet’s sprite.
- **Fragment shader**: sample base color and multiply by `Color.from_hsv(hue, sat, val)` where `hue` is passed as uniform from script (e.g. `life_ratio`).

---

## 4. Trails (Player + Bullets)

**Bullets**
- **Bullet** scene: **Line2D** node `Trail` (child of Bullet).
  - **Width**: 3  
  - **Default Color**: cyan, alpha ~0.6  
  - **Material**: additive material  
  - **Cap / Joint**: Round (1)  
- Script appends `global_position` each frame, keeps last N points, converts to local and fills Line2D.

**Player**
- **Player** scene: **Line2D** node `Trail` (e.g. first child so it draws behind).
  - **z_index**: -1  
  - **Width**: 4  
  - **Default Color**: blue/cyan, alpha ~0.5  
  - **Material**: additive material  
  - **Cap / Joint**: Round (1)  
- `player_controller.gd` appends `position` each frame, keeps last 24 points, sets gradient (tail transparent, head brighter).

**No Trail2D node**  
Using Line2D + script keeps compatibility and control; Trail2D can be swapped in later if desired.

---

## 5. Hit Flash (Enemy) + Camera Shake on Hit

**Hit flash**
- **EventBus**: `hit_flash_requested(target: CanvasItem, duration: float)`.
- **HitFlash** node (under Main): listens and runs a short white flash on `target.modulate`.
- **Enemy**: in `enemy_base.gd` `take_damage()` we call:
  - `EventBus.hit_flash_requested.emit(_get_sprite(), 0.08)`  
  so the enemy sprite flashes white.

**Camera shake**
- **EventBus**: `screen_shake_requested(intensity, duration)`.
- **GameCamera** (Camera2D) has **CameraShake** script that adds trauma and applies random offset each frame.
- **Enemy hit**: in `take_damage()` we call:
  - `EventBus.screen_shake_requested.emit(0.15, 0.08)`  
  so each hit gives a short, small shake.
- **Player hit**: already triggers a stronger shake in `player_controller.gd` (e.g. 0.4, 0.15).

**Editor**
- Ensure **HitFlash** and **Camera2D** (with CameraShake) exist in Main; no extra property changes needed if signals are connected as above.

---

## 6. Neon Sprite Shader + Materials

**Shader file**
- `res://resources/shaders/neon_sprite.gdshader` — CanvasItem shader: soft outer glow (edge fade), additive blend, time-based hue shift (HSV). Parameters: `glow_strength`, `hue_speed`, `base_color`, `alpha`.

**Material**
- `res://resources/materials/neon_sprite_material.tres` — ShaderMaterial using the above shader. Applied to:
  - **Player** → `Sprite` (ColorRect): Material = neon_sprite_material
  - **Enemy (EnemyBasic)** → `Sprite` (ColorRect): Material = neon_sprite_material
  - **Bullet** → `Sprite` (ColorRect): Material = neon_sprite_material  
  Trails keep additive_material.

**Editor**
- In each scene (player.tscn, enemy_basic.tscn, bullet.tscn): add ExtResource for `res://resources/materials/neon_sprite_material.tres`, set the Sprite node’s **Material** to that resource.

---

## 7. Dark, Low-Detail Background (Noise + Star Dust)

**Background**
- **World/Background** (ColorRect): **Material** = `res://resources/materials/background_noise_material.tres`.
- Shader: `res://resources/shaders/background_noise.gdshader` — procedural animated noise gradient (dark_color, mid_color, noise_scale, noise_strength, time_scale). Keeps background subdued.

**Star dust**
- **World/StarDust** (CPUParticles2D): z_index -99, amount 36, lifetime 6, emission_rect_extents (1800,1200), slow velocity 4–12, small scale, dim color. No texture; procedural.

**Editor**
- Main.tscn: Background → Material = background_noise_material.tres; add StarDust node under World with the above properties.

---

## 8. Hit Feedback (Enemy + Player)

**Enemy hit**
- `enemy_base.gd` `take_damage()`: `hit_flash_requested(_get_sprite(), 0.08)`, `screen_shake_requested(0.15, 0.08)` — unchanged.

**Enemy death**
- `explosion_vfx.gd` fallback: CPUParticles2D uses **color_ramp** (GradientTexture1D) with rainbow gradient (red → orange → green → blue → purple), additive material. No new signal.

**Player hit**
- `player_controller.gd` `take_damage()`:
  - `screen_shake_requested(0.55, 0.2)` — stronger shake.
  - `hit_flash_requested(sprite, 0.1)` — sprite flash.
  - `hit_flash_requested(null, 0.15)` — **full-screen vignette/flash**.
  - `Engine.time_scale = 0.3` for **0.15 s real time**, then restore to 1.0 (restore in `_physics_process` using `Time.get_ticks_msec()`).

**HitFlash node (Main)**
- **FlashLayer/FullScreenFlash** (CanvasLayer + ColorRect): full rect, mouse_filter Ignore, color transparent. When `hit_flash_requested(null, duration)` is received, script sets FullScreenFlash color to `fullscreen_flash_color` (e.g. red tint) then back to transparent after duration.

**GDScript**
- `scripts/vfx/hit_flash.gd`: `_on_hit_flash_requested` — if `target == null`, call `_run_fullscreen_flash(duration)` using `$FlashLayer/FullScreenFlash`.
- `scripts/player/player_controller.gd`: constants `TIME_SCALE_DIP`, `TIME_SCALE_DIP_REAL_SEC`; in `_physics_process` check `_time_scale_restore_at` and restore `Engine.time_scale`.

---

## Summary Checklist

| Item                    | Where / What |
|-------------------------|--------------|
| WorldEnvironment        | Main scene, assign neon_glow.tres |
| Environment glow        | Intensity 0.7, Strength 1.35, Bloom 0.15, HDR 0.85/1.8, Tonemap Filmic |
| Neon shader             | resources/shaders/neon_sprite.gdshader |
| Neon material           | resources/materials/neon_sprite_material.tres → Player/Enemy/Bullet Sprite |
| Additive material       | Bullet/Player Trail, explosion particles |
| Player trail            | Line2D under Player, player_controller.gd |
| Bullet trail            | Line2D under Bullet, bullet.gd |
| Enemy hit               | hit_flash_requested(sprite) + screen_shake_requested |
| Enemy death             | explosion_requested → CPUParticles2D with rainbow color_ramp |
| Player hit              | stronger shake, sprite flash, hit_flash_requested(null), time_scale 0.3 for 0.15s |
| HitFlash full-screen     | HitFlash/FlashLayer/FullScreenFlash in Main.tscn |
| Background              | World/Background + background_noise_material.tres |
| Star dust               | World/StarDust CPUParticles2D |

---

## Deliverables (paths + editor steps)

**New files**
- `resources/shaders/neon_sprite.gdshader`
- `resources/shaders/background_noise.gdshader`
- `resources/materials/neon_sprite_material.tres`
- `resources/materials/background_noise_material.tres`

**Main.tscn changes**
- WorldEnvironment: environment = neon_glow.tres (unchanged).
- World/Background: material = ExtResource("13_bg_mat") → background_noise_material.tres.
- World/StarDust: new CPUParticles2D (z_index -99, emission_shape 1, emission_rect_extents (1800,1200), amount 36, lifetime 6, slow velocity, dim color).
- HitFlash/FlashLayer/FullScreenFlash: new CanvasLayer + ColorRect (full rect, transparent).

**Scene changes (player, enemy_basic, bullet)**
- Add ext_resource for neon_sprite_material.tres; set Sprite node **Material** to that resource.

**GDScript**
- `hit_flash.gd`: support `target == null` → full-screen flash via FullScreenFlash.
- `player_controller.gd`: on take_damage emit hit_flash_requested(null, 0.15), set Engine.time_scale = 0.3, set _time_scale_restore_at; in _physics_process restore time_scale when real time elapsed.
- `explosion_vfx.gd`: fallback particles use color_ramp (rainbow GradientTexture1D) and additive material.

No external textures; procedural shaders and built-in nodes only.
