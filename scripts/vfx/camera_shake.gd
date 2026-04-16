extends Node
class_name CameraShake
## Smooth follow, subtle breathing, and screen shake for parent Camera2D.
## No camera limits: infinite movement illusion; world logic and background center on player.

@export var max_offset: Vector2 = Vector2(8, 8)
@export var decay_rate: float = 4.0
## Smooth follow: higher = snappier (e.g. 5–7). Tuned for 1.5x player speed.
@export var follow_smoothing: float = 6.0
## Look-ahead: offset target in velocity direction (pixels per 1 px/frame). Slight lead for readability.
@export var look_ahead_scale: float = 0.06
## Subtle drift/breathing amplitude in pixels (e.g. 1–3).
@export var breath_amplitude: float = 2.0
@export var breath_speed: float = 0.6
@export var tank_rumble_radius: float = 280.0
@export var tank_rumble_min: float = 0.04

var _trauma: float = 0.0
var _duration: float = 0.0
var _camera: Camera2D
var _player: Node2D
var _world_background: CanvasItem

func _ready() -> void:
	_camera = get_parent() as Camera2D
	if not _camera:
		_camera = get_viewport().get_camera_2d()
	# No camera limits: player never reaches a visible edge (infinite illusion).
	if _camera:
		_camera.limit_left = -0x7FFFFFFF
		_camera.limit_top = -0x7FFFFFFF
		_camera.limit_right = 0x7FFFFFFF
		_camera.limit_bottom = 0x7FFFFFFF
		_world_background = _camera.get_parent().get_node_or_null("World/Background") as CanvasItem
		# Low opacity so star layer, nebula, and drifting particles show through (living space, never compete).
		if _world_background:
			_world_background.modulate.a = 0.22
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player and is_instance_valid(_player):
		_camera.global_position = _player.global_position
	EventBus.screen_shake_requested.connect(_on_shake_requested)


func _on_shake_requested(intensity: float, duration: float) -> void:
	_trauma = clampf(_trauma + intensity, 0.0, 1.0)
	_duration = maxf(_duration, duration)


func _process(delta: float) -> void:
	if not _camera:
		return
	# Smooth follow with damping and slight look-ahead
	if _player and is_instance_valid(_player):
		var target := _player.global_position
		if _player is CharacterBody2D:
			var vel: Vector2 = (_player as CharacterBody2D).velocity
			target += vel * look_ahead_scale
		var t := 1.0 - exp(-follow_smoothing * delta)
		_camera.global_position = _camera.global_position.lerp(target, t)
	# Shake
	if _duration > 0:
		_duration -= delta
		_trauma = move_toward(_trauma, 0.0, decay_rate * delta)
	if _is_tank_nearby():
		_trauma = maxf(_trauma, tank_rumble_min)
	var shake := _trauma * _trauma
	var shake_vec := Vector2(
		randf_range(-max_offset.x, max_offset.x) * shake,
		randf_range(-max_offset.y, max_offset.y) * shake
	)
	# Subtle breathing (tiny drift) during play
	var breath := Vector2(
		sin(Time.get_ticks_msec() * 0.001 * breath_speed * 60.0) * breath_amplitude,
		cos(Time.get_ticks_msec() * 0.001 * breath_speed * 60.0 * 0.7) * breath_amplitude * 0.8
	)
	_camera.offset = shake_vec + breath
	# Procedural background: keep World/Background centered on camera so no edge is ever visible.
	if _world_background and is_instance_valid(_world_background):
		# Background rect is 4000x4000 (-2000..2000); origin is top-left so center at position + (2000,2000).
		_world_background.global_position = _camera.global_position - Vector2(2000, 2000)


func _is_tank_nearby() -> bool:
	if not _player or not is_instance_valid(_player):
		return false
	for node in get_tree().get_nodes_in_group("enemy_tank"):
		if is_instance_valid(node) and node is Node2D:
			if _player.global_position.distance_to((node as Node2D).global_position) <= tank_rumble_radius:
				return true
	return false
