extends Node
## Light Language controller: pulse on fire, dim between shots, build synergy (light echo + harmonic glow).
## Ensures glow is never constant; gameplay silhouettes stay sharp; light never hides hitboxes.

const LAYER_LIGHT_FX := 35
const ECHO_RING_POINTS := 48
const ECHO_RING_WIDTH := 3.2
const ECHO_COLOR := Color(0.7, 0.9, 1.0, 0.28)
const WEAPON_PULSE_DURATION := 0.10
const WEAPON_PULSE_MAX_RADIUS := 72.0

var _layer: CanvasLayer
var _echo_rings: Array[Node2D] = []


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER_LIGHT_FX
	_layer.name = "WeaponLightLayer"
	add_child(_layer)
	if EventBus.has_signal("build_ignited"):
		EventBus.build_ignited.connect(_on_build_ignited)
	if EventBus.has_signal("upgrade_weapon_pulse_requested"):
		EventBus.upgrade_weapon_pulse_requested.connect(_on_upgrade_weapon_pulse_requested)


func _on_build_ignited(_effect_id: String, _display_name: String, _duration_sec: float) -> void:
	# Light echo radiates outward (system coming online). World brightness + tint handled by BuildIgnitionFX.
	_spawn_light_echo()


func _on_upgrade_weapon_pulse_requested() -> void:
	# Single weapon core pulse when upgrade is applied (0.10s).
	_play_weapon_core_pulse()


func _play_weapon_core_pulse() -> void:
	var center: Vector2 = _get_echo_center()
	var speed: float = WEAPON_PULSE_MAX_RADIUS / WEAPON_PULSE_DURATION if WEAPON_PULSE_DURATION > 0 else 700.0
	_draw_one_echo_ring(center, WEAPON_PULSE_MAX_RADIUS, speed)


func _spawn_light_echo() -> void:
	if not LightLanguage:
		return
	var count: int = LightLanguage.BUILD_SYNERGY_ECHO_RINGS
	var speed: float = LightLanguage.BUILD_SYNERGY_ECHO_SPEED
	var max_radius: float = LightLanguage.BUILD_SYNERGY_ECHO_MAX_RADIUS
	var center: Vector2 = _get_echo_center()
	for i in count:
		var delay: float = i * 0.06
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			_draw_one_echo_ring(center, max_radius, speed)
		)


func _get_echo_center() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and is_instance_valid(player):
		return player.global_position
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.global_position
	return get_viewport().get_visible_rect().size * 0.5


var _unit_circle: PackedVector2Array = []


func _draw_one_echo_ring(center: Vector2, max_radius: float, speed: float) -> void:
	if _unit_circle.size() != ECHO_RING_POINTS + 1:
		_unit_circle.clear()
		for i in ECHO_RING_POINTS:
			var a := TAU * float(i) / float(ECHO_RING_POINTS)
			_unit_circle.append(Vector2(cos(a), sin(a)))
		_unit_circle.append(Vector2(1, 0))
	var line := Line2D.new()
	line.name = "EchoRing"
	line.width = ECHO_RING_WIDTH
	line.default_color = ECHO_COLOR
	line.position = center
	line.z_index = 0
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		line.material = mat
	line.points = _scale_unit_circle(0.0)
	_layer.add_child(line)
	_echo_rings.append(line)
	var duration: float = max_radius / speed if speed > 0 else 0.4
	var tween := line.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(func(r: float) -> void:
		if is_instance_valid(line):
			line.points = _scale_unit_circle(r)
	, 0.0, max_radius, duration)
	tween.tween_property(line, "default_color:a", 0.0, 0.08)
	tween.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
		_echo_rings.erase(line)
	)


func _scale_unit_circle(radius: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for i in _unit_circle.size():
		out.append(_unit_circle[i] * radius)
	return out
