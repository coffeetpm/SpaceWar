extends Node2D
class_name BossBeamGrid
## Precision Grid: beam net with moving safe gaps. Deterministic timing (no random); telegraph per line optional.

@export var grid_width: float = 320.0
@export var grid_height: float = 280.0
@export var beam_count_h: int = 4
@export var beam_count_v: int = 3
@export var beam_width: float = 12.0
@export var telegraph_duration: float = 0.4
@export var beam_on_duration: float = 0.9
@export var gap_movement_speed: float = 0.5

var _beams_h: Array[Node2D] = []
var _beams_v: Array[Node2D] = []
var _state: String = "idle"
var _timer: float = 0.0
var _phase_offset: float = 0.0


func _ready() -> void:
	_build_grid()
	visible = false


func _build_grid() -> void:
	for i in beam_count_h:
		var beam := _make_line_beam(true, i)
		add_child(beam)
		_beams_h.append(beam)
	for i in beam_count_v:
		var beam := _make_line_beam(false, i)
		add_child(beam)
		_beams_v.append(beam)


func _make_line_beam(horizontal: bool, index: int) -> Node2D:
	var root := Node2D.new()
	root.name = "GridBeam_%s_%d" % ["H" if horizontal else "V", index]
	var line := Line2D.new()
	line.width = beam_width
	line.default_color = ArtDirection.BOSS_BEAM_CORE
	line.add_point(Vector2.ZERO)
	if horizontal:
		line.add_point(Vector2(grid_width, 0))
		root.rotation = -PI/2
		root.position.y = -grid_height * 0.5 + (float(index + 1) / float(beam_count_h + 1)) * grid_height
	else:
		line.add_point(Vector2(0, -grid_height))
		root.position.x = -grid_width * 0.5 + (float(index + 1) / float(beam_count_v + 1)) * grid_width
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		line.material = mat
	root.add_child(line)
	root.visible = false
	return root


func start_attack() -> void:
	_state = "active"
	visible = true
	_timer = 0.0
	_phase_offset = 0.0
	for b in _beams_h:
		b.visible = false
	for b in _beams_v:
		b.visible = false


func _process(delta: float) -> void:
	if _state != "active":
		return
	_timer += delta
	var t := _timer - _phase_offset
	if t < 0.0:
		return
	var idx_h := int(t / (telegraph_duration + beam_on_duration)) % beam_count_h
	var idx_v := int(t / (telegraph_duration + beam_on_duration)) % beam_count_v
	var phase := fmod(t, telegraph_duration + beam_on_duration)
	if phase < telegraph_duration:
		pass
	elif phase < telegraph_duration + beam_on_duration:
		if idx_h < _beams_h.size():
			_beams_h[idx_h].visible = true
		if idx_v < _beams_v.size():
			_beams_v[idx_v].visible = true
	else:
		for b in _beams_h:
			b.visible = false
		for b in _beams_v:
			b.visible = false
	if _timer > 8.0:
		_state = "idle"
		visible = false
		for b in _beams_h:
			b.visible = false
		for b in _beams_v:
			b.visible = false
