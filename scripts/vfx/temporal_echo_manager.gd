extends Node
## Temporal Echo: when a player projectile hits, record position; after short delay, trigger a second light impact (time ripple, ghost flash, delayed echo pulse).
## Combat feels influenced by time. Emotion: the world remembers the attack.

const ECHO_DELAY_MIN := 0.3
const ECHO_DELAY_MAX := 0.4
const MAX_PENDING := 24  # not excessive; drop oldest if over

# ----- Echo visual: readable, not excessive -----
const RIPPLE_RADIUS_START := 8.0
const RIPPLE_RADIUS_END := 32.0
const RIPPLE_DURATION := 0.22
const RIPPLE_COLOR := Color(0.35, 0.82, 1.0, 0.28)
const GHOST_FLASH_RADIUS := 12.0
const GHOST_FLASH_DURATION := 0.12
const GHOST_FLASH_COLOR := Color(0.5, 0.9, 1.1, 0.35)
const ECHO_PULSE_RADIUS := 18.0
const ECHO_PULSE_DURATION := 0.18
const ECHO_PULSE_COLOR := Color(0.4, 0.88, 1.05, 0.4)

var _pending: Array[Dictionary] = []  # { position: Vector2, damage: int, trigger_at: float }


func _ready() -> void:
	EventBus.player_projectile_impact.connect(_on_player_projectile_impact)


func _on_player_projectile_impact(global_pos: Vector2, _damage: int) -> void:
	if RunState and RunState.is_opening_phase():
		return
	var trigger_at := Time.get_ticks_msec() * 0.001 + randf_range(ECHO_DELAY_MIN, ECHO_DELAY_MAX)
	_pending.append({"position": global_pos, "trigger_at": trigger_at})
	while _pending.size() > MAX_PENDING:
		_pending.pop_front()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var i := 0
	while i < _pending.size():
		if _pending[i].trigger_at <= now:
			_spawn_echo_visual(_pending[i].position)
			_pending.remove_at(i)
		else:
			i += 1


func _spawn_echo_visual(global_pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var add_mat := load("res://resources/materials/additive_material.tres") as Material
	# 1. Time ripple: expanding ring that fades
	var ripple := _make_ring(RIPPLE_RADIUS_START, RIPPLE_COLOR)
	ripple.global_position = global_pos
	ripple.top_level = true
	if add_mat:
		ripple.material = add_mat
	scene.add_child(ripple)
	var t_ripple := ripple.create_tween()
	t_ripple.tween_method(func(r: float) -> void: _set_ring_radius(ripple, r), RIPPLE_RADIUS_START, RIPPLE_RADIUS_END, RIPPLE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var t_ripple_fade := ripple.create_tween()
	t_ripple_fade.tween_interval(RIPPLE_DURATION * 0.35)
	t_ripple_fade.tween_property(ripple, "modulate:a", 0.0, RIPPLE_DURATION)
	t_ripple_fade.tween_callback(func() -> void: ripple.queue_free())
	# 2. Ghost flash: short dim flash
	var ghost := _make_circle(GHOST_FLASH_RADIUS, GHOST_FLASH_COLOR)
	ghost.global_position = global_pos
	ghost.top_level = true
	if add_mat:
		ghost.material = add_mat
	scene.add_child(ghost)
	var t_ghost := ghost.create_tween()
	t_ghost.tween_property(ghost, "modulate:a", 0.0, GHOST_FLASH_DURATION).from(1.0)
	t_ghost.tween_callback(func() -> void: ghost.queue_free())
	# 3. Delayed echo pulse: small scale-up then fade
	var pulse := _make_circle(ECHO_PULSE_RADIUS, ECHO_PULSE_COLOR)
	pulse.global_position = global_pos
	pulse.top_level = true
	pulse.scale = Vector2(0.2, 0.2)
	if add_mat:
		pulse.material = add_mat
	scene.add_child(pulse)
	var t_pulse := pulse.create_tween()
	t_pulse.set_ease(Tween.EASE_OUT)
	t_pulse.set_trans(Tween.TRANS_QUAD)
	t_pulse.tween_property(pulse, "scale", Vector2(1.0, 1.0), ECHO_PULSE_DURATION * 0.5)
	var t_pulse_fade := pulse.create_tween()
	t_pulse_fade.tween_interval(ECHO_PULSE_DURATION * 0.4)
	t_pulse_fade.tween_property(pulse, "modulate:a", 0.0, ECHO_PULSE_DURATION)
	t_pulse_fade.tween_callback(func() -> void: pulse.queue_free())


func _make_ring(radius: float, color: Color) -> Node2D:
	var node := Node2D.new()
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	var points: PackedVector2Array = []
	const SEGMENTS := 24
	for i in SEGMENTS + 1:
		var a := TAU * float(i) / float(SEGMENTS)
		points.append(Vector2(cos(a), sin(a)) * radius)
	line.points = points
	node.add_child(line)
	node.set_meta("_ring_line", line)
	node.set_meta("_ring_radius", radius)
	return node


func _set_ring_radius(ring_node: Node2D, radius: float) -> void:
	var line: Line2D = ring_node.get_meta("_ring_line", null)
	if not line:
		return
	var points: PackedVector2Array = []
	const SEGMENTS := 24
	for i in SEGMENTS + 1:
		var a := TAU * float(i) / float(SEGMENTS)
		points.append(Vector2(cos(a), sin(a)) * radius)
	line.points = points


func _make_circle(radius: float, color: Color) -> CanvasItem:
	var poly := Polygon2D.new()
	var points: PackedVector2Array = []
	const SEGMENTS := 16
	for i in SEGMENTS:
		var a := TAU * float(i) / float(SEGMENTS)
		points.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = points
	poly.color = color
	return poly
