extends Node2D
## Minimal space for installation-art tone: dark void with a few distant light points. Geometric, sparse. No clutter.

const STAR_POSITIONS: Array[Vector2] = [
	Vector2(180, 80),
	Vector2(520, 120),
	Vector2(720, 180),
	Vector2(280, 480),
	Vector2(620, 440),
]
const STAR_SIZE := 2.2
const STAR_ALPHA := 0.18


func _ready() -> void:
	var mat := load("res://resources/materials/additive_material.tres") as Material
	for p in STAR_POSITIONS:
		var poly := Polygon2D.new()
		poly.position = p
		poly.polygon = _quad_around(Vector2.ZERO, STAR_SIZE)
		poly.color = Color(0.7, 0.78, 0.95, STAR_ALPHA)
		if mat:
			poly.material = mat
		add_child(poly)


func _quad_around(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-half, -half),
		center + Vector2(half, -half),
		center + Vector2(half, half),
		center + Vector2(-half, half),
	])
