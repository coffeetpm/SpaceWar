extends Node2D
## Abstract construct for showcase: light-based machine, geometric system.
## Polygon forms, rotating segments, energy core, refraction surfaces.
## Motion: smooth, intentional, sculptural. Emotion: controlled threat, technological presence.
## Avoid: organic motion, creature-like behaviour, traditional ships.

const HALF_WIDTH := 18.0
const HALF_HEIGHT := 14.0
const SPLIT_DISTANCE := 22.0
const SPLIT_DURATION := 0.22
const FADE_DURATION := 0.2
## Rad/s for rotating segments — slow, intentional.
const ROTATE_SPEED_1 := 0.22
const ROTATE_SPEED_2 := -0.15

var _left: Polygon2D
var _right: Polygon2D
var _segments_node: Node2D
var _segment1: Node2D
var _segment2: Node2D
var _core: Polygon2D
var _refraction: Polygon2D
var _split := false

func _ready() -> void:
	_build_construct()

func _process(delta: float) -> void:
	if _split:
		return
	if _segment1:
		_segment1.rotation += ROTATE_SPEED_1 * delta
	if _segment2:
		_segment2.rotation += ROTATE_SPEED_2 * delta

func _build_construct() -> void:
	var mat := load("res://resources/materials/additive_material.tres") as Material
	# Refraction surface — outer ring, cool tint, low alpha
	_refraction = Polygon2D.new()
	_refraction.name = "Refraction"
	_refraction.z_index = -1
	_refraction.polygon = _hex_ring(20.0, 24.0)
	_refraction.color = Color(0.35, 0.45, 0.7, 0.2)
	if mat:
		_refraction.material = mat
	add_child(_refraction)

	# Main body — two halves (polygon forms), split on beam
	_left = Polygon2D.new()
	_left.name = "Left"
	_left.polygon = PackedVector2Array([
		Vector2(-HALF_WIDTH, -HALF_HEIGHT),
		Vector2(0, -HALF_HEIGHT),
		Vector2(0, HALF_HEIGHT),
		Vector2(-HALF_WIDTH, HALF_HEIGHT),
	])
	_left.color = Color(0.42, 0.18, 0.38, 0.88)
	if mat:
		_left.material = mat
	add_child(_left)

	_right = Polygon2D.new()
	_right.name = "Right"
	_right.polygon = PackedVector2Array([
		Vector2(0, -HALF_HEIGHT),
		Vector2(HALF_WIDTH, -HALF_HEIGHT),
		Vector2(HALF_WIDTH, HALF_HEIGHT),
		Vector2(0, HALF_HEIGHT),
	])
	_right.color = Color(0.42, 0.18, 0.38, 0.88)
	if mat:
		_right.material = mat
	add_child(_right)

	# Rotating segments — geometric, light-driven
	_segments_node = Node2D.new()
	_segments_node.name = "Segments"
	add_child(_segments_node)

	_segment1 = Node2D.new()
	_segment1.name = "Segment1"
	_segments_node.add_child(_segment1)
	var p1 := Polygon2D.new()
	p1.polygon = PackedVector2Array([
		Vector2(-14, -3),
		Vector2(14, -3),
		Vector2(14, 3),
		Vector2(-14, 3),
	])
	p1.color = Color(0.5, 0.22, 0.42, 0.75)
	if mat:
		p1.material = mat
	_segment1.add_child(p1)

	_segment2 = Node2D.new()
	_segment2.name = "Segment2"
	_segment2.rotation = 1.57
	_segments_node.add_child(_segment2)
	var p2 := Polygon2D.new()
	p2.polygon = PackedVector2Array([
		Vector2(-10, -2.5),
		Vector2(10, -2.5),
		Vector2(10, 2.5),
		Vector2(-10, 2.5),
	])
	p2.color = Color(0.45, 0.2, 0.4, 0.6)
	if mat:
		p2.material = mat
	_segment2.add_child(p2)

	# Energy core — central, bright
	_core = Polygon2D.new()
	_core.name = "Core"
	_core.polygon = PackedVector2Array([
		Vector2(0, -5),
		Vector2(4.5, 3),
		Vector2(-4.5, 3),
	])
	_core.color = Color(0.85, 0.5, 0.75, 0.95)
	if mat:
		_core.material = mat
	add_child(_core)

func _hex_ring(inner_r: float, outer_r: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for i in 6:
		var a := TAU * i / 6.0
		out.append(Vector2(cos(a), sin(a)) * outer_r)
	for i in range(5, -1, -1):
		var a := TAU * i / 6.0
		out.append(Vector2(cos(a), sin(a)) * inner_r)
	return out

func split() -> void:
	if _split:
		return
	_split = true
	# Body halves slide apart and fade
	var t_left := _left.create_tween()
	t_left.set_ease(Tween.EASE_OUT)
	t_left.set_trans(Tween.TRANS_QUAD)
	t_left.tween_property(_left, "position:x", -SPLIT_DISTANCE, SPLIT_DURATION * 0.5)
	var t_left_fade := _left.create_tween()
	t_left_fade.tween_interval(SPLIT_DURATION * 0.35)
	t_left_fade.tween_property(_left, "modulate:a", 0.0, FADE_DURATION)
	var t_right := _right.create_tween()
	t_right.set_ease(Tween.EASE_OUT)
	t_right.set_trans(Tween.TRANS_QUAD)
	t_right.tween_property(_right, "position:x", SPLIT_DISTANCE, SPLIT_DURATION * 0.5)
	var t_right_fade := _right.create_tween()
	t_right_fade.tween_interval(SPLIT_DURATION * 0.35)
	t_right_fade.tween_property(_right, "modulate:a", 0.0, FADE_DURATION)
	# Construct elements fade in place (sculptural dissolution)
	if _refraction:
		var tr := _refraction.create_tween()
		tr.tween_interval(SPLIT_DURATION * 0.2)
		tr.tween_property(_refraction, "modulate:a", 0.0, FADE_DURATION)
	if _segments_node:
		var ts := _segments_node.create_tween()
		ts.tween_interval(SPLIT_DURATION * 0.2)
		ts.tween_property(_segments_node, "modulate:a", 0.0, FADE_DURATION)
	if _core:
		var tc := _core.create_tween()
		tc.tween_interval(SPLIT_DURATION * 0.2)
		tc.tween_property(_core, "modulate:a", 0.0, FADE_DURATION)

func reset_split() -> void:
	_split = false
	if _left:
		_left.position = Vector2.ZERO
		_left.modulate.a = 1.0
	if _right:
		_right.position = Vector2.ZERO
		_right.modulate.a = 1.0
	if _refraction:
		_refraction.modulate.a = 1.0
	if _segments_node:
		_segments_node.modulate.a = 1.0
	if _core:
		_core.modulate.a = 1.0
