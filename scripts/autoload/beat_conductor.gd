extends Node
## Visual response to beat grid: glow, background pulse, dust, enemy pulse. Driven by BeatManager.
## Beat guides timing; input stays responsive. Ignition temporarily amplifies pulse strength.

signal beat_pulse

@export var pulse_glow_boost: float = 0.10
@export var pulse_glow_duration: float = 0.1
@export var pulse_bg_alpha: float = 0.016
@export var enable_dust: bool = true
@export var enable_enemy_pulse: bool = true
@export var enemy_pulse_scale: float = 1.03
@export var enemy_pulse_duration: float = 0.1
@export var ignition_boost_mult: float = 1.4
@export var ignition_boost_seconds: float = 1.8

var _paused: bool = false
var _world_env: WorldEnvironment
var _env: Environment
var _pulse_overlay: ColorRect
var _base_glow: float = 0.7
var _ignition_boost_until: float = 0.0


func _ready() -> void:
	_setup_overlay()
	EventBus.explosion_requested.connect(_on_explosion_requested)
	if BeatManager:
		BeatManager.beat_pulse.connect(_on_beat)
		if BeatManager.has_method("set_paused"):
			pass  # BeatConductor.set_paused delegates to BeatManager below
	if EventBus.has_signal("build_ignited"):
		EventBus.build_ignited.connect(_on_build_ignited)


func _on_build_ignited(_a: String, _b: String, _c: float) -> void:
	_ignition_boost_until = Time.get_ticks_msec() * 0.001 + ignition_boost_seconds


func set_paused(p: bool) -> void:
	_paused = p
	if BeatManager and BeatManager.has_method("set_paused"):
		BeatManager.set_paused(p)


func is_paused() -> bool:
	return _paused


func _setup_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.follow_viewport_enabled = true
	add_child(layer)
	_pulse_overlay = ColorRect.new()
	_pulse_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pulse_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse_overlay.color = Color(0, 0, 0, 0)
	layer.add_child(_pulse_overlay)


## Beat timing is driven by BeatManager; no internal timer. _on_beat called from BeatManager.beat_pulse.


func _acquire_environment() -> bool:
	if _env:
		return true
	var scene := get_tree().current_scene
	if not scene:
		return false
	_world_env = scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_env and _world_env.environment:
		_env = _world_env.environment
		_base_glow = _env.glow_intensity
		return true
	return false


func _on_beat() -> void:
	beat_pulse.emit()
	_pulse_glow()
	_pulse_background()
	if enable_dust:
		_pulse_dust()
	if enable_enemy_pulse:
		_pulse_enemies()


func _pulse_glow() -> void:
	if not _acquire_environment():
		return
	var now := Time.get_ticks_msec() * 0.001
	var mult: float = ignition_boost_mult if now < _ignition_boost_until else 1.0
	var boost := _base_glow * (1.0 + pulse_glow_boost * mult)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(_env, "glow_intensity", _base_glow, pulse_glow_duration).from(boost)


func _pulse_background() -> void:
	if not _pulse_overlay:
		return
	var now := Time.get_ticks_msec() * 0.001
	var mult: float = ignition_boost_mult if now < _ignition_boost_until else 1.0
	_pulse_overlay.color = Color(1, 1, 1, pulse_bg_alpha * mult)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(_pulse_overlay, "color:a", 0.0, pulse_glow_duration)


func _pulse_dust() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var dust := scene.get_node_or_null("BeatDust") as CPUParticles2D
	if dust:
		dust.global_position = _get_beat_center()
		dust.restart()
		dust.emitting = true
		get_tree().create_timer(0.03).timeout.connect(func() -> void:
			if is_instance_valid(dust):
				dust.emitting = false
		)


func _pulse_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue
		var vis := node.get_node_or_null("Visual") as Node2D
		if not vis:
			continue
		var t := vis.create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(vis, "scale", vis.scale, enemy_pulse_duration).from(vis.scale * enemy_pulse_scale)


func _on_explosion_requested(_pos: Vector2, _scale: float, _color: Color) -> void:
	if not _acquire_environment():
		return
	var strong := _base_glow * 1.18
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(_env, "glow_intensity", _base_glow, 0.12).from(strong)


func _get_beat_center() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.global_position
	var scene := get_tree().current_scene
	if scene and scene is Node2D:
		return (scene as Node2D).global_position
	return Vector2(576, 324)


## Call from any system to trigger a short glow burst (visual rhythm). strength_mult = peak glow multiplier.
func request_glow_pulse(duration_sec: float, strength_mult: float) -> void:
	if not _acquire_environment():
		return
	var peak := _base_glow * strength_mult
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(_env, "glow_intensity", _base_glow, duration_sec).from(peak)


## Beat-synced environmental heartbeat: soft background pulse + slight color breath + optional distant particle shimmer. Never strong.
func request_environmental_pulse(duration_sec: float, glow_strength: float, overlay_alpha: float = 0.0, trigger_dust: bool = false) -> void:
	request_glow_pulse(duration_sec, glow_strength)
	if _pulse_overlay and overlay_alpha > 0.0:
		var a: float = overlay_alpha
		if EmotionFeedback and EmotionFeedback.has_method("get_emotion_pulse_strength"):
			a *= 1.0 + EmotionFeedback.get_emotion_pulse_strength()
		_pulse_overlay.color = Color(0.97, 0.99, 1.02, a)
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(_pulse_overlay, "color:a", 0.0, duration_sec)
	if trigger_dust and enable_dust:
		_pulse_dust()


## World ripple: universe reacts to player actions. Never strong, never distracting. Like ripples in space.
## Subtle brightness pulse + optional color shift wave + optional distant particle shimmer.
func request_world_ripple(duration_sec: float, glow_strength: float, overlay_alpha: float = 0.0, trigger_dust: bool = false, overlay_tint: Color = Color(1, 1, 1, 1)) -> void:
	request_glow_pulse(duration_sec, glow_strength)
	if _pulse_overlay and overlay_alpha > 0.0:
		var a: float = overlay_alpha
		if EmotionFeedback and EmotionFeedback.has_method("get_emotion_pulse_strength"):
			a *= 1.0 + EmotionFeedback.get_emotion_pulse_strength()
		_pulse_overlay.color = Color(overlay_tint.r, overlay_tint.g, overlay_tint.b, a)
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(_pulse_overlay, "color:a", 0.0, duration_sec)
	if trigger_dust and enable_dust:
		_pulse_dust()


func stage_clear_pulse() -> void:
	if not _pulse_overlay:
		return
	# Stronger glow
	if _acquire_environment():
		var strong_boost := _base_glow * 1.35
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(_env, "glow_intensity", _base_glow, 0.22).from(strong_boost)
	# Chromatic-style flash (soft cyan tint, then fade)
	_pulse_overlay.color = Color(0.75, 0.85, 1.0, 0.12)
	var t2 := create_tween()
	t2.set_ease(Tween.EASE_OUT)
	t2.set_trans(Tween.TRANS_QUAD)
	t2.tween_property(_pulse_overlay, "color:a", 0.0, 0.2)
