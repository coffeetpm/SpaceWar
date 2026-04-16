extends Node2D
## Player as energy core for gameplay showcase. Minimal geometric form, sharp, precise. Installation-art tone; no particles.

const NOSE := 24.0
const WING := 16.0
const TAIL := -12.0

var _body: Polygon2D
var _core: Polygon2D


func _ready() -> void:
	_build_ship()


func _build_ship() -> void:
	var mat := load("res://resources/materials/additive_material.tres") as Material
	# Main wedge (nose right)
	_body = Polygon2D.new()
	_body.name = "Body"
	_body.polygon = PackedVector2Array([
		Vector2(NOSE, 0),
		Vector2(TAIL, -WING),
		Vector2(TAIL, WING),
	])
	_body.color = Color(0.28, 0.65, 0.95, 0.9)
	if mat:
		_body.material = mat
	add_child(_body)
	# Core glow
	_core = Polygon2D.new()
	_core.name = "Core"
	_core.polygon = PackedVector2Array([
		Vector2(8, 0),
		Vector2(-4, -6),
		Vector2(-4, 6),
	])
	_core.color = Color(0.45, 0.88, 1.1, 0.95)
	if mat:
		_core.material = mat
	add_child(_core)
