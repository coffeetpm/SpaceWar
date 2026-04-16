extends Node2D
class_name TelegraphLine
## Refraction Examiner: clean, sharp telegraph. Readable direction + dodge window. Minimal noise, high readability.

@export var length: float = 400.0
@export var width: float = 18.0
@export var telegraph_duration: float = 0.6
@export var grow_from_center: bool = true
@export var sharp_style: bool = true

var _line: Line2D
var _glow: Line2D
var _timer: float = 0.0
var _angle: float = 0.0
var _active: bool = false

func _ready() -> void:
	visible = false
	_draw_visuals()


func _draw_visuals() -> void:
	var mat := load("res://resources/materials/additive_material.tres") as Material
	_line = Line2D.new()
	_line.name = "Line"
	_line.width = width
	_line.default_color = ArtDirection.BOSS_TELEGRAPH_SHARP if sharp_style else ArtDirection.BOSS_TELEGRAPH
	_line.add_point(Vector2.ZERO)
	_line.add_point(Vector2(0, -length))
	if mat:
		_line.material = mat
	add_child(_line)
	_glow = Line2D.new()
	_glow.name = "Glow"
	_glow.width = width * (1.4 if sharp_style else 2.0)
	_glow.z_index = -1
	_glow.default_color = ArtDirection.BOSS_TELEGRAPH_EDGE
	_glow.add_point(Vector2.ZERO)
	_glow.add_point(Vector2(0, -length))
	if mat:
		_glow.material = mat
	add_child(_glow)


## Call to show telegraph in current direction (rotation of this node). Runs for telegraph_duration then hides.
func show_telegraph() -> void:
	visible = true
	_timer = telegraph_duration
	_active = true
	if grow_from_center:
		_set_length(0.0)
	else:
		_set_length(length)


func _set_length(l: float) -> void:
	var end := Vector2(0, -l)
	_line.set_point_position(1, end)
	_glow.set_point_position(1, end)


func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if grow_from_center and _line:
		var t := 1.0 - (_timer / telegraph_duration)
		_set_length(length * t)
	if _timer <= 0.0:
		_active = false
		visible = false
		_set_length(length)
