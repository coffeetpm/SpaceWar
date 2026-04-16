# Integration Notes — Arcade Roguelike Upgrade

Safe integration summary for: infinite world, dynamic themes, boss UI, combat variety.

---

## Part 1 — Infinite World Illusion

**What was done**
- **Camera:** No hard limits; CameraShake follows player with look-ahead (already unbounded).
- **Spawn:** Enemies already spawn relative to player (`WaveSpawner._get_spawn_center()` = player position).
- **Parallax:** Three procedural layers driven by camera position:
  - **Layer 1 (Stars):** `ParallaxController/ParallaxLayer/Stars` — shader `parallax_stars.gdshader`, motion scale 0.12.
  - **Layer 2 (Dust/Nebula):** `Dust` — `parallax_dust.gdshader`, motion scale 0.35.
  - **Layer 3 (Fog):** `Fog` — `parallax_fog.gdshader`, motion scale 0.6.
- **Script:** `scripts/vfx/parallax_controller.gd` — reads camera each frame, sets `scroll_offset` on each layer’s material.

**Files**
- `scripts/vfx/parallax_controller.gd`
- `resources/shaders/parallax_stars.gdshader`, `parallax_dust.gdshader`, `parallax_fog.gdshader`
- `resources/materials/parallax_*_material.tres`
- `scenes/main/main.tscn` — `ParallaxController` + `ParallaxLayer` (CanvasLayer -100) with Stars/Dust/Fog ColorRects

**Rollback**
- Remove `ParallaxController` node and its children from main.tscn.
- Remove the four parallax ext_resources and the three material resources.
- Delete the three shader files and three material .tres if no longer used.

---

## Part 2 — Dynamic Background Themes

**What was done**
- **ThemeManager (autoload):** `scripts/autoload/theme_manager.gd` — themes SPACE, TIME_FIELD, VOID_FRACTURE, ORBITAL_CORE; `set_theme()`, `advance_theme_after_boss()` (once per run), `theme_changed(theme_id, transition_duration)`.
- **First boss defeat:** In `StageManager._run_boss_clear_sequence()` after `_grant_boss_reward()`, call `ThemeManager.advance_theme_after_boss()`.
- **Parallax reaction:** `parallax_controller.gd` connects `ThemeManager.theme_changed`, tweens star/dust/fog shader colors over the given duration.

**Files**
- `scripts/autoload/theme_manager.gd`
- `project.godot` — autoload `ThemeManager`
- `scripts/vfx/parallax_controller.gd` — theme_changed + _apply_theme_colors
- `scripts/stage_manager.gd` — `ThemeManager.advance_theme_after_boss()` in clear sequence

**Rollback**
- Remove ThemeManager autoload from project.godot.
- Remove `theme_changed` connect and theme color logic from parallax_controller.gd.
- Remove `ThemeManager.advance_theme_after_boss()` from stage_manager.gd.
- Optionally delete theme_manager.gd.

---

## Part 3 — Boss Top UI

**What was done**
- **Boss HP:** RefractionCore has `max_hp` (420), `current_hp`, `take_damage(amount)`. Emits `EventBus.boss_hp_changed(current, max)` and on death `EventBus.boss_defeated`.
- **Boss hitbox:** `scenes/boss/refraction_core.tscn` — added `Hitbox` (Area2D), collision_layer 4, collision_mask 2; CircleShape2D radius 38. Player bullets (Area2D) hit via `bullet.gd` `_on_area_entered` (boss = area.get_parent() in group "boss").
- **Early kill:** StageManager connects `EventBus.boss_defeated`; on signal sets `burst_timer = 0` and calls `_on_burst_end()` so the same clear sequence runs.
- **Boss HUD:** `UI/BossHUD` in main.tscn — script `scripts/ui/boss_hud.gd`. Shows on `EventBus.boss_spawned`, hides on `EventBus.boss_despawned`. Updates bar from `boss_hp_changed`, phase flash from `boss_phase_changed`. Style: neon panel + horizontal progress bar.

**EventBus**
- `boss_spawned(boss: Node)` — StageManager emits when spawning boss.
- `boss_despawned` — StageManager emits in `_remove_boss()` before queue_free.
- `boss_hp_changed(current, maximum)`
- `boss_phase_changed(phase)`
- `boss_defeated` — RefractionCore emits when current_hp <= 0.

**Files**
- `scripts/boss/refraction_core.gd` — HP, take_damage, phase_changed emit, no hitbox damage (bullet handles hit).
- `scenes/boss/refraction_core.tscn` — Hitbox + CollisionShape2D
- `scripts/weapons/bullet.gd` — `get_damage()`, `_on_area_entered` for boss (area.get_parent() in "boss").
- `scripts/ui/boss_hud.gd`, main.tscn — BossHUD, BossPanel, NameLabel, HealthBar
- `scripts/stage_manager.gd` — boss_spawned/boss_despawned emit, boss_defeated → _on_burst_end()

**Rollback**
- Remove BossHUD node and script from main.tscn; remove boss sub_resources.
- In RefractionCore remove current_hp/max_hp/take_damage and phase/hp emits; remove Hitbox from scene.
- In bullet.gd remove get_damage and boss branch in _on_area_entered.
- In StageManager remove boss_defeated connect and boss_spawned/boss_despawned emits.
- Remove EventBus boss_* signals if nothing else uses them.

---

## Part 4 — Combat Variety (Weapon Behaviours)

**What was done**
- **Omni-direction (auto target):** Homing weapon now uses `_get_direction_toward_nearest_enemy()` for initial fire direction so the first shot aims at nearest enemy; bullet still homes.
- **Behind-fire:** New weapon **Rear** — `weapon_rear.gd` + `weapon_rear.tscn`, `fire_backward_when_moving = true`. RunWeaponBase has `_get_direction_backward()` and export `fire_backward_when_moving`; when set, fire direction is opposite to player velocity when moving.
- **Existing behaviours:** Spread = cone, Beam = beam lock, Drones = orbit, Burst = pulse burst, Homing = omni + homing, Rear = behind-fire.
- **Vocabulary:** "rear" added to SaveManager.ALL_WEAPON_IDS, BuildVocabulary WEAPON_FORCE (TIME), WEAPON_FORCE_TAGS, IGNITION_TRIGGERS, WEAPON_SIGNATURE_BUILD; player WEAPON_SCENES; game_hud WEAPON_DISPLAY; stage_manager pulse_split branch.

**Files**
- `scripts/weapons/run_weapon_base.gd` — `_get_direction_toward_nearest_enemy()`, `_get_direction_backward()`, `fire_backward_when_moving` export.
- `scripts/weapons/weapon_homing.gd` — initial direction from nearest enemy.
- `scripts/weapons/weapon_rear.gd`, `scenes/weapons/weapon_rear.tscn`
- `scripts/player/player_controller.gd` — WEAPON_SCENES["rear"]
- `scripts/autoload/save_manager.gd` — ALL_WEAPON_IDS
- `scripts/autoload/build_vocabulary.gd` — rear in WEAPON_FORCE, WEAPON_FORCE_TAGS, IGNITION_TRIGGERS, WEAPON_SIGNATURE_BUILD
- `scripts/ui/game_hud.gd` — WEAPON_DISPLAY["rear"]
- `scripts/stage_manager.gd` — "rear" in pulse choice lists

**Visual distinction**
- Per-weapon look is already handled by ArtDirection (player bullet / trail colors) and bullet type (homing vs normal). No art direction palette changes.

**Rollback**
- Remove "rear" from WEAPON_SCENES, ALL_WEAPON_IDS, BuildVocabulary, game_hud, stage_manager.
- Delete weapon_rear.gd and weapon_rear.tscn.
- In RunWeaponBase remove fire_backward_when_moving and _get_direction_backward / _get_direction_toward_nearest_enemy if no other weapon uses them; revert weapon_homing to previous _get_fire_direction().

---

## What Was Not Changed

- Build/synergy system (SynergyManager, BuildVocabulary, triggers, force pairs).
- Art direction palette (ArtDirection constants; only theme tints parallax, not gameplay sprites).
- Core loop (burst → upgrade → next burst; boss every N bursts; game over on player death).
- Combat systems (damage, bullets, explosions, hitstop, etc.) except boss now has HP and can be killed early.
