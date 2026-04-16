extends CanvasLayer
## 6–8s activation intro: system powering on. Technological, precise, minimal.
## Sequence: darkness → faint pulse → geometric structures → beam calibration → rhythm stabilizes → overlay fades → gameplay.
## No cinematic camera, no dialogue, no menus; transitions directly into run.

signal intro_finished

const DURATION_TOTAL := 7.0
const DARKNESS_HOLD := 0.7
const PULSE_START := 0.8
const PULSE_END := 1.8
const GEOMETRY_START := 1.6
const GEOMETRY_END := 2.9
const CALIBRATION_START := 2.8
const CALIBRATION_END := 4.1
const RHYTHM_START := 4.0
const RHYTHM_END := 5.2
const FADE_OUT_START := 5.2
const FADE_OUT_END := 6.6

const PULSE_COLOR := Color(0.25, 0.65, 0.95, 0.22)
const LINE_COLOR := Color(0.35, 0.82, 1.0, 0.48)
const CALIBRATION_COLOR := Color(0.4, 0.88, 1.05, 0.38)

var _overlay: Control
var _pulse: Control
var _geometry: Node2D
var _calibration: Node2D
var _rhythm_line: Line2D
var _t: float = 0.0
var _running: bool = false
var _allow_skip: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process_input(false)
	_build_overlay()


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.02, 0.03, 0.06, 1.0)
	dark.name = "Darkness"
	_overlay.add_child(dark)
	# Pulse: center circle
	_pulse = Control.new()
	_pulse.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pulse.anchor_top = 0.5
	_pulse.anchor_bottom = 0.5
	_pulse.offset_left = -60
	_pulse.offset_top = -60
	_pulse.offset_right = 60
	_pulse.offset_bottom = 60
	_pulse.modulate.a = 0.0
	var pulse_circle := Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(60 + 58 * cos(a), 60 + 58 * sin(a)))
	pulse_circle.polygon = pts
	pulse_circle.color = PULSE_COLOR
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		pulse_circle.material = mat
	_pulse.add_child(pulse_circle)
	_overlay.add_child(_pulse)
	# Geometry: Line2D container (world-space lines drawn in viewport coords)
	_geometry = Node2D.new()
	_geometry.visible = false
	_overlay.add_child(_geometry)
	_calibration = Node2D.new()
	_calibration.visible = false
	_overlay.add_child(_calibration)
	_rhythm_line = Line2D.new()
	_rhythm_line.width = 1.5
	_rhythm_line.default_color = Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.0)
	_rhythm_line.visible = false
	if mat:
		_rhythm_line.material = mat
	_overlay.add_child(_rhythm_line)
	visible = false


func run_intro() -> void:
	visible = true
	_t = 0.0
	_running = true
	_allow_skip = SaveManager != null and not SaveManager.is_first_run()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_overlay.modulate.a = 1.0
	_pulse.modulate.a = 0.0
	_geometry.visible = false
	_geometry.modulate.a = 0.0
	_calibration.visible = false
	_calibration.modulate.a = 0.0
	_rhythm_line.visible = false
	_rhythm_line.default_color = Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.0)
	_draw_geometry()
	_draw_calibration()
	_draw_rhythm_line()


func _draw_geometry() -> void:
	for c in _geometry.get_children():
		c.queue_free()
	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x * 0.5
	var cy := vp.y * 0.5
	var r := 80.0
	var add_mat := load("res://resources/materials/additive_material.tres") as Material
	for i in 6:
		var a0 := TAU * float(i) / 6.0 - 0.5
		var a1 := TAU * float((i + 1) % 6) / 6.0 - 0.5
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = LINE_COLOR
		line.add_point(Vector2(cx + cos(a0) * r, cy + sin(a0) * r))
		line.add_point(Vector2(cx + cos(a1) * r, cy + sin(a1) * r))
		if add_mat:
			line.material = add_mat
		_geometry.add_child(line)


func _draw_calibration() -> void:
	for c in _calibration.get_children():
		c.queue_free()
	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x * 0.5
	var cy := vp.y * 0.5
	var half := 120.0
	var add_mat := load("res://resources/materials/additive_material.tres") as Material
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var line := Line2D.new()
		line.width = 1.2
		line.default_color = CALIBRATION_COLOR
		line.add_point(Vector2(cx, cy))
		line.add_point(Vector2(cx + dir.x * half, cy + dir.y * half))
		if add_mat:
			line.material = add_mat
		_calibration.add_child(line)


func _draw_rhythm_line() -> void:
	var vp := get_viewport().get_visible_rect().size
	_rhythm_line.clear_points()
	_rhythm_line.add_point(Vector2(vp.x * 0.3, vp.y * 0.5))
	_rhythm_line.add_point(Vector2(vp.x * 0.7, vp.y * 0.5))


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	# 1) Darkness (0–0.8)
	# 2) Faint pulse (0.8–1.8)
	if _t >= PULSE_START and _t <= PULSE_END:
		var local := (_t - PULSE_START) / (PULSE_END - PULSE_START)
		_pulse.modulate.a = 0.0 if local < 0.3 else (0.85 if local > 0.7 else lerpf(0.0, 0.85, (local - 0.3) / 0.4))
		_pulse.scale = Vector2.ONE * (0.6 + 0.5 * (1.0 - abs(local - 0.5) * 2.0))
	elif _t > PULSE_END:
		_pulse.modulate.a = 0.0
	# 3) Geometric structures (1.6–2.9)
	if _t >= GEOMETRY_START:
		_geometry.visible = true
		if _t <= GEOMETRY_END:
			var local := (_t - GEOMETRY_START) / (GEOMETRY_END - GEOMETRY_START)
			_geometry.modulate.a = clampf(local * 1.2, 0.0, 1.0)
		else:
			_geometry.modulate.a = 1.0
	# 4) Beam calibration (2.8–4.1)
	if _t >= CALIBRATION_START:
		_calibration.visible = true
		if _t <= CALIBRATION_END:
			var local := (_t - CALIBRATION_START) / (CALIBRATION_END - CALIBRATION_START)
			_calibration.modulate.a = clampf(local * 1.1, 0.0, 1.0)
		else:
			_calibration.modulate.a = 1.0
	# 5) Rhythm stabilizes (4.0–5.2)
	if _t >= RHYTHM_START:
		_rhythm_line.visible = true
		if _t <= RHYTHM_END:
			var local := (_t - RHYTHM_START) / (RHYTHM_END - RHYTHM_START)
			var c := _rhythm_line.default_color
			_rhythm_line.default_color = Color(c.r, c.g, c.b, clampf(local * 0.9, 0.0, 0.7))
		else:
			_rhythm_line.default_color = Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.7)
	# 6–7) Overlay fades out, then finish (5.2–6.6)
	if _t >= FADE_OUT_START:
		if _t <= FADE_OUT_END:
			var local := (_t - FADE_OUT_START) / (FADE_OUT_END - FADE_OUT_START)
			_overlay.modulate.a = 1.0 - local
		else:
			_overlay.modulate.a = 0.0
			_running = false
			process_mode = Node.PROCESS_MODE_DISABLED
			set_process_input(false)
			visible = false
			layer = -100
			intro_finished.emit()


func _input(event: InputEvent) -> void:
	if not _running or not _allow_skip:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed:
			get_viewport().set_input_as_handled()
			skip_intro()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			get_viewport().set_input_as_handled()
			skip_intro()


func skip_intro() -> void:
	if _running:
		_running = false
		process_mode = Node.PROCESS_MODE_DISABLED
		set_process_input(false)
		_overlay.modulate.a = 0.0
		visible = false
		layer = -100
		intro_finished.emit()
