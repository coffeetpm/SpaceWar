extends Node2D
class_name BossBeamReflection
## Reflection Beam: beam bounces via nodes; cross angles. Telegraph per beam, readable direction, dodge window.

@export var beam_length: float = 380.0
@export var telegraph_duration: float = 0.5
@export var beam_duration: float = 1.4
@export var mirror_offset: Vector2 = Vector2(120, -80)
@export var cross_angle_degrees: float = 50.0

var _beams: Array[BossBeamBase] = []
var _mirror_nodes: Array[Node2D] = []
var _state: String = "idle"
var _timer: float = 0.0
var _pattern_index: int = 0


func _ready() -> void:
	_build_mirrors()
	_build_beams()
	visible = false


func _build_mirrors() -> void:
	for i in 2:
		var m := Node2D.new()
		m.name = "Mirror%d" % i
		var poly := Polygon2D.new()
		poly.color = ArtDirection.BOSS_LIGHT_SHELL
		poly.polygon = PackedVector2Array([Vector2(-8, -12), Vector2(8, 0), Vector2(-8, 12)])
		m.add_child(poly)
		var offset := mirror_offset if i == 0 else Vector2(-mirror_offset.x, mirror_offset.y)
		m.position = offset
		add_child(m)
		_mirror_nodes.append(m)


func _build_beams() -> void:
	for i in 2:
		var beam: BossBeamSweep = BossBeamSweep.new()
		beam.name = "ReflectionBeam%d" % i
		beam.beam_length = beam_length
		beam.telegraph_duration = telegraph_duration
		beam.sweep_angle_degrees = 0.0
		beam.sweep_duration = beam_duration
		var telegraph := load("res://scripts/boss/telegraph_line.gd") as Script
		var tl: Node2D = telegraph.new()
		tl.name = "TelegraphLine"
		tl.set("length", beam_length)
		tl.set("telegraph_duration", telegraph_duration)
		beam.add_child(tl)
		add_child(beam)
		_beams.append(beam)


func start_attack() -> void:
	_state = "active"
	visible = true
	_timer = 0.0
	var angle0 := deg_to_rad(-cross_angle_degrees * 0.5)
	var angle1 := deg_to_rad(cross_angle_degrees * 0.5)
	_beams[0].rotation = angle0
	_beams[1].rotation = angle1
	_beams[0].start_attack()
	_beams[1].start_attack()


func _process(delta: float) -> void:
	if _state != "active":
		return
	_timer += delta
	var all_done := true
	for b in _beams:
		if b.visible:
			all_done = false
			break
	if all_done and _timer > telegraph_duration + beam_duration:
		_state = "idle"
		visible = false
