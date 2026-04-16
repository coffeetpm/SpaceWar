extends Node
## Beat-synced environmental reactions: world subtly responds to gameplay rhythm. A heartbeat, not fireworks.
## Weapon cadence, combo, and boss phase trigger world ripples (brightness pulse, color shift wave, distant dust). Never strong.

# ----- World ripple: universe reacts to player actions. Like ripples in space. -----
const RIPPLE_SHOT_THROTTLE := 0.10
const RIPPLE_SHOT_DURATION := 0.12
const RIPPLE_SHOT_GLOW := 1.012
const RIPPLE_SHOT_OVERLAY := 0.0025
const RIPPLE_SHOT_TINT := Color(0.92, 0.96, 1.0)
const RIPPLE_COMBO_DURATION := 0.14
const RIPPLE_COMBO_GLOW := 1.014
const RIPPLE_COMBO_OVERLAY := 0.003
const RIPPLE_COMBO_TINT := Color(0.95, 0.93, 1.0)
const RIPPLE_COMBO_DUST_AT := 3
const RIPPLE_BOSS_PHASE_DURATION := 0.16
const RIPPLE_BOSS_PHASE_GLOW := 1.015
const RIPPLE_BOSS_PHASE_OVERLAY := 0.003
const RIPPLE_BOSS_PHASE_TINT := Color(0.92, 0.98, 1.0)

# ----- Legacy environmental pulse (wave/stage clear, boss spawn) -----
const WAVE_START_DURATION := 0.18
const WAVE_START_GLOW := 1.02
const WAVE_START_OVERLAY_ALPHA := 0.006
const WAVE_START_DUST := true
const BOSS_SPAWN_DURATION := 0.2
const BOSS_SPAWN_GLOW := 1.05
const BOSS_SPAWN_OVERLAY_ALPHA := 0.008
const BOSS_SPAWN_DUST := true
const WAVE_CLEAR_DURATION := 0.2
const WAVE_CLEAR_GLOW := 1.03
const WAVE_CLEAR_OVERLAY_ALPHA := 0.007
const WAVE_CLEAR_DUST := true
const STAGE_CLEAR_DURATION := 0.22
const STAGE_CLEAR_GLOW := 1.04
const STAGE_CLEAR_OVERLAY_ALPHA := 0.008
const STAGE_CLEAR_DUST := true

var _last_shot_ripple_at: float = -999.0


func _ready() -> void:
	EventBus.bullet_spawn_requested.connect(_on_bullet_spawn_requested)
	EventBus.combo_increased.connect(_on_combo_increased)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.stage_cleared.connect(_on_stage_cleared)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)


func _world_ripple(duration: float, glow: float, overlay_alpha: float, trigger_dust: bool, overlay_tint: Color) -> void:
	if BeatConductor and BeatConductor.has_method("request_world_ripple"):
		BeatConductor.request_world_ripple(duration, glow, overlay_alpha, trigger_dust, overlay_tint)


func _environmental_pulse(duration: float, glow: float, overlay_alpha: float, trigger_dust: bool) -> void:
	if BeatConductor and BeatConductor.has_method("request_environmental_pulse"):
		BeatConductor.request_environmental_pulse(duration, glow, overlay_alpha, trigger_dust)


func _on_bullet_spawn_requested(_pos: Vector2, _dir: Vector2, _speed: float, _damage: int, is_player: bool, _weapon_id: String) -> void:
	if not is_player:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_shot_ripple_at < RIPPLE_SHOT_THROTTLE:
		return
	_last_shot_ripple_at = now
	_world_ripple(RIPPLE_SHOT_DURATION, RIPPLE_SHOT_GLOW, RIPPLE_SHOT_OVERLAY, false, RIPPLE_SHOT_TINT)


func _on_combo_increased(combo_count: int) -> void:
	var trigger_dust: bool = combo_count >= RIPPLE_COMBO_DUST_AT
	_world_ripple(RIPPLE_COMBO_DURATION, RIPPLE_COMBO_GLOW, RIPPLE_COMBO_OVERLAY, trigger_dust, RIPPLE_COMBO_TINT)


func _on_wave_started(_wave: int) -> void:
	_environmental_pulse(WAVE_START_DURATION, WAVE_START_GLOW, WAVE_START_OVERLAY_ALPHA, WAVE_START_DUST)


func _on_wave_cleared(_wave: int) -> void:
	_environmental_pulse(WAVE_CLEAR_DURATION, WAVE_CLEAR_GLOW, WAVE_CLEAR_OVERLAY_ALPHA, WAVE_CLEAR_DUST)


func _on_boss_spawned(_boss: Node) -> void:
	_environmental_pulse(BOSS_SPAWN_DURATION, BOSS_SPAWN_GLOW, BOSS_SPAWN_OVERLAY_ALPHA, BOSS_SPAWN_DUST)


func _on_boss_phase_changed(_phase: int) -> void:
	_world_ripple(RIPPLE_BOSS_PHASE_DURATION, RIPPLE_BOSS_PHASE_GLOW, RIPPLE_BOSS_PHASE_OVERLAY, false, RIPPLE_BOSS_PHASE_TINT)


func _on_stage_cleared(_stage: int) -> void:
	_environmental_pulse(STAGE_CLEAR_DURATION, STAGE_CLEAR_GLOW, STAGE_CLEAR_OVERLAY_ALPHA, STAGE_CLEAR_DUST)
