extends Node
## System Powering On VFX: level-up trigger, upgrade selection confirm, resume phase.
## REFRACT sci-fi: precise, rhythmic, no confetti. Listens to EventBus.level_up, upgrade_selected_for_vfx, upgrade_resume_phase.

const LAYER := 42
const CALIBRATION_DURATION := 0.08
const RING_DURATION := 0.20
const RING_POINTS := 64
const RING_WIDTH := 2.0
const CHROMATIC_DURATION := 0.12
const LINK_STAGGER := 0.06
const LINK_COLLAPSE_DURATION := 0.18
const PHASE_PULSE_DURATION := 0.08
const PHASE_PULSE_BRIGHTNESS := 0.06

const CALIBRATION_COLOR := Color(0.6, 0.82, 1.0, 0.14)
const RING_COLOR := Color(0.5, 0.78, 1.0, 0.35)
const CHROMATIC_COLOR := Color(0.45, 0.75, 1.0, 0.05)
const LINK_COLOR := Color(0.55, 0.85, 1.0, 0.7)
const PHASE_PULSE_COLOR := Color(1.0, 1.0, 1.0, PHASE_PULSE_BRIGHTNESS)

var _layer: CanvasLayer
var _calibration: ColorRect
var _chromatic: ColorRect
var _phase_pulse: ColorRect
var _ring_container: Node2D
var _link_container: Node2D
var _additive_mat: Material


func _ready() -> void:
	_additive_mat = load("res://resources/materials/additive_material.tres") as Material
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.name = "LevelUpVFXLayer"
	add_child(_layer)

	_calibration = _fullscreen_rect("Calibration", CALIBRATION_COLOR)
	_calibration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_calibration)
	_calibration.modulate.a = 0.0

	_chromatic = _fullscreen_rect("Chromatic", CHROMATIC_COLOR)
	_chromatic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_chromatic)
	_chromatic.modulate.a = 0.0

	_phase_pulse = _fullscreen_rect("PhasePulse", PHASE_PULSE_COLOR)
	_phase_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_phase_pulse)
	_phase_pulse.modulate.a = 0.0

	_ring_container = Node2D.new()
	_ring_container.name = "RingContainer"
	_layer.add_child(_ring_container)

	_link_container = Node2D.new()
	_link_container.name = "LinkContainer"
	_layer.add_child(_link_container)

	EventBus.level_up.connect(_on_level_up)
	EventBus.upgrade_resume_phase.connect(_on_upgrade_resume_phase)

	var upgrade_ui: Control = get_node_or_null("/root/Main/UI/UpgradeChoice") as Control
	if not upgrade_ui:
		upgrade_ui = get_parent().get_node_or_null("UI/UpgradeChoice") as Control
	if upgrade_ui and upgrade_ui.has_signal("upgrade_selected_for_vfx"):
		upgrade_ui.upgrade_selected_for_vfx.connect(_on_upgrade_selected_for_vfx)


func _fullscreen_rect(name: String, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = name
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.offset_left = -500
	r.offset_top = -500
	r.offset_right = 2000
	r.offset_bottom = 2000
	r.color = col
	return r


func _on_level_up(_level: int) -> void:
	_play_calibration_pulse()
	_play_ring_pulse()
	_play_chromatic_shimmer()


func _play_calibration_pulse() -> void:
	if not is_instance_valid(_calibration):
		return
	var t := _calibration.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(_calibration, "modulate:a", 1.0, CALIBRATION_DURATION * 0.4)
	t.tween_property(_calibration, "modulate:a", 0.0, CALIBRATION_DURATION * 0.6)


func _play_ring_pulse() -> void:
	var center := _player_screen_center()
	if center.x < -10000:
		return
	var unit: PackedVector2Array = []
	for i in RING_POINTS:
		var a := TAU * float(i) / float(RING_POINTS)
		unit.append(Vector2(cos(a), sin(a)))
	unit.append(Vector2(1, 0))

	var line := Line2D.new()
	line.name = "LevelUpRing"
	line.width = RING_WIDTH
	line.default_color = RING_COLOR
	line.position = center
	line.z_index = 0
	if _additive_mat:
		line.material = _additive_mat
	var max_r := 120.0
	var pts: PackedVector2Array = []
	for i in unit.size():
		pts.append(unit[i] * 0.0)
	line.points = pts
	_ring_container.add_child(line)

	var t := line.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_method(func(r: float) -> void:
		if is_instance_valid(line):
			var p: PackedVector2Array = []
			for i in unit.size():
				p.append(unit[i] * r)
			line.points = p
	, 0.0, max_r, RING_DURATION * 0.65)
	t.parallel().tween_property(line, "default_color:a", 0.0, RING_DURATION * 0.35)
	t.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)


func _player_screen_center() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var cam := get_viewport().get_camera_2d()
	var vp_size := get_viewport().get_visible_rect().size
	if player and is_instance_valid(player) and cam:
		return (player.global_position - cam.global_position) + vp_size * 0.5
	return vp_size * 0.5


func _play_chromatic_shimmer() -> void:
	if not is_instance_valid(_chromatic):
		return
	var t := _chromatic.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(_chromatic, "modulate:a", 1.0, CHROMATIC_DURATION * 0.25)
	t.tween_property(_chromatic, "modulate:a", 0.0, CHROMATIC_DURATION * 0.75)


func _on_upgrade_selected_for_vfx(screen_center: Vector2) -> void:
	_play_energy_links(screen_center)
	# Optional: EventBus.emit("ui_confirm_sound_requested") when you add audio.


func _play_energy_links(target: Vector2) -> void:
	var vp := get_viewport().get_visible_rect()
	var size := vp.size
	var edges: PackedVector2Array = [
		Vector2(0, size.y * 0.5),
		Vector2(size.x, size.y * 0.5),
		Vector2(size.x * 0.5, 0),
	]
	var num_links := mini(3, edges.size())
	for i in num_links:
		var delay := i * LINK_STAGGER
		_draw_one_link(edges[i], target, delay)


func _draw_one_link(from: Vector2, to: Vector2, delay: float) -> void:
	var line := Line2D.new()
	line.name = "EnergyLink"
	line.width = 2.0
	line.default_color = LINK_COLOR
	line.z_index = 1
	if _additive_mat:
		line.material = _additive_mat
	line.points = [from, to]
	line.modulate.a = 0.0
	_link_container.add_child(line)

	var show_t := line.create_tween()
	show_t.tween_interval(delay)
	show_t.tween_property(line, "modulate:a", 1.0, 0.04)

	var collapse_t := line.create_tween()
	collapse_t.tween_interval(delay + 0.06)
	collapse_t.set_ease(Tween.EASE_IN)
	collapse_t.set_trans(Tween.TRANS_QUAD)
	collapse_t.tween_method(func(t_val: float) -> void:
		if is_instance_valid(line):
			var a := from.lerp(to, t_val)
			line.points = [a, to]
	, 0.0, 1.0, LINK_COLLAPSE_DURATION)
	collapse_t.tween_property(line, "modulate:a", 0.0, 0.04)
	collapse_t.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)


func _on_upgrade_resume_phase() -> void:
	_play_phase_pulse()
	if EventBus.has_signal("upgrade_weapon_pulse_requested"):
		EventBus.upgrade_weapon_pulse_requested.emit()


func _play_phase_pulse() -> void:
	if not is_instance_valid(_phase_pulse):
		return
	var t := _phase_pulse.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(_phase_pulse, "modulate:a", 1.0, PHASE_PULSE_DURATION * 0.4)
	t.tween_property(_phase_pulse, "modulate:a", 0.0, PHASE_PULSE_DURATION * 0.6)
