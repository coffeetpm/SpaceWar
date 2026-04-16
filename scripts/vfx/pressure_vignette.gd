extends Node
## Rhythmic pressure: short vignette + bloom bursts when many enemies are near (not constant glow).

@export var player_path: NodePath = NodePath("../World/Player")
@export var world_env_path: NodePath = NodePath("../WorldEnvironment")
@export var radius: float = 380.0
@export var enemy_count_threshold: int = 4
@export var vignette_max: float = 0.18
@export var bloom_boost_max: float = 0.06
@export var burst_interval: float = 0.45
@export var burst_duration: float = 0.22

var _player: Node2D
var _env: Environment
var _base_glow: float
var _rect: ColorRect
var _mat: ShaderMaterial
var _next_burst_at: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	var we: WorldEnvironment = get_node_or_null(world_env_path) as WorldEnvironment
	if we and we.environment:
		_env = we.environment.duplicate(true)
		we.environment = _env
		_base_glow = _env.glow_intensity
	var layer: CanvasLayer = get_node_or_null("PressureLayer") as CanvasLayer
	if layer:
		_rect = layer.get_node_or_null("ColorRect") as ColorRect
	if _rect and _rect.material:
		_mat = _rect.material as ShaderMaterial
		if _mat and not _mat.is_local_to_scene():
			_rect.material = _mat.duplicate()
			_mat = _rect.material as ShaderMaterial


func _process(_delta: float) -> void:
	var pressure: float = 0.0
	if _player and is_instance_valid(_player):
		var count := 0
		for n in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(n) and n is Node2D:
				if _player.global_position.distance_to((n as Node2D).global_position) <= radius:
					count += 1
		if count >= enemy_count_threshold:
			pressure = clampf(float(count - enemy_count_threshold) / 4.0, 0.0, 1.0)
	var now := Time.get_ticks_msec() * 0.001
	if pressure > 0.0 and now >= _next_burst_at:
		_next_burst_at = now + burst_interval
		_run_pressure_burst(pressure)
	elif pressure <= 0.0:
		if _mat:
			_mat.set_shader_parameter("intensity", 0.0)
		if _env:
			_env.glow_intensity = _base_glow


func _run_pressure_burst(pressure: float) -> void:
	var peak_glow := _base_glow + pressure * bloom_boost_max
	var peak_vignette := pressure * vignette_max
	if _env:
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(_env, "glow_intensity", _base_glow, burst_duration).from(peak_glow)
	if _mat:
		_mat.set_shader_parameter("intensity", peak_vignette)
		var t2 := create_tween()
		t2.set_ease(Tween.EASE_OUT)
		t2.set_trans(Tween.TRANS_QUAD)
		t2.tween_method(_set_vignette_intensity, peak_vignette, 0.0, burst_duration)


func _set_vignette_intensity(value: float) -> void:
	if _mat:
		_mat.set_shader_parameter("intensity", value)
