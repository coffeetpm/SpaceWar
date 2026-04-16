extends Node
## Global event bus. Use signals for decoupled communication.
## No hard references between systems—everything goes through events.

# ----- Game flow -----
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal stage_started(stage_index: int)
signal stage_cleared(stage_index: int)
signal game_over
signal upgrade_choice_requested(choices: Array)
## Emitted when player picks an upgrade (UI feedback hook: pulse, etc.).
signal upgrade_picked
## Emitted when a run starts (after weapon select). weapon_id defines the build for this run.
signal run_started(weapon_id: String)
## Build Ignition: synergy threshold reached (weapon + tag). effect_id, display_name, duration_sec. Visual + audio hook.
signal build_ignited(effect_id: String, display_name: String, duration_sec: float)
## First synergy: run just reached 2 forces. One-shot visual (refraction flicker, beam stability).
signal first_synergy_triggered
## Second synergy: first build ignition in this run. One-shot visual (temporal echo).
signal second_synergy_triggered

# ----- Upgrade effects (stackable) -----
signal upgrade_effect_fire_rate(value: float)
signal upgrade_effect_damage(value: int)
signal upgrade_effect_max_hp(value: int)
signal upgrade_effect_projectile_speed(value: float)
signal upgrade_effect_move_speed(value: float)

# ----- Player -----
signal player_damaged(amount: int, source: Node)
signal player_died
signal screen_shake_requested(intensity: float, duration: float)

# ----- Combat -----
signal bullet_spawn_requested(global_position: Vector2, direction: Vector2, speed: float, damage: int, is_player: bool, weapon_id: String)
## Same as bullet_spawn_requested but bullet will home toward nearest enemy (curved trail).
signal bullet_spawn_requested_homing(global_position: Vector2, direction: Vector2, speed: float, damage: int, weapon_id: String)
signal muzzle_flash_requested(global_position: Vector2, weapon_id: String)
signal enemy_died(enemy: Node, global_position: Vector2)
signal explosion_requested(global_position: Vector2, scale: float, color: Color)
## Temporal Echo: when a player projectile hits, record position; echo triggers after short delay (time ripple, ghost flash, delayed pulse). Combat feels influenced by time.
signal player_projectile_impact(global_position: Vector2, damage: int)
## Run reward: emit when player collects a pickup (amount added to run currency).
signal run_currency_collected(amount: int)
## EXP / Energy XP: drops give exp; player uses for level-up. Emit when pickup collected.
signal exp_collected(amount: int)
## Emitted when player fills EXP bar and levels up (freeze + upgrade choice). level = new level.
signal level_up(level: int)
## Emitted when upgrade choice closes and gameplay unfreezes (level-up flow). VFX: phase pulse + weapon core pulse.
signal upgrade_resume_phase
## One-shot weapon core pulse (e.g. after picking upgrade). Duration handled by WeaponLightController.
signal upgrade_weapon_pulse_requested
## Audio hook: emit on enemy kill for future SFX.
signal sound_kill_requested
## Combo increased (consecutive kills within window). World rhythm / ripple hook. combo_count >= 2.
signal combo_increased(combo_count: int)

# ----- VFX -----
signal hit_flash_requested(target: CanvasItem, duration: float)
signal hitstop_requested(duration_sec: float, time_scale: float)
signal time_scale_dip_requested(duration_real_sec: float, time_scale: float)
## Skill feedback: player narrowly dodged a bullet (visual/audio only, no gameplay).
signal near_dodge_feedback

# ----- Boss: spawn/despawn and UI -----
signal boss_spawned(boss: Node)
signal boss_despawned
signal boss_hp_changed(current: int, maximum: int)
signal boss_phase_changed(phase: int)
## Boss HP reached 0 (trigger clear sequence).
signal boss_defeated
# ----- Boss clear: technical accomplishment — mastery, not spectacle -----
signal boss_clear_radial_pulse
signal boss_clear_show_cleared
signal boss_clear_player_glow
## Boss reward: one gameplay unlock (weapon / synergy / force). unlock_type, unlock_id, display_name. No stat boost.
signal boss_reward_unlocked(unlock_type: String, unlock_id: String, display_name: String)
