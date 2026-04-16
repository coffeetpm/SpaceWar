extends Node
class_name BossClearVFX
## Boss clear: one clean radial light pulse. No explosion spam, minimal, precise. Emotion: "I mastered the fight."

@export var pulse_duration: float = 0.45
@export var ring_radius_start: float = 0.15
@export var ring_radius_end: float = 1.2
@export var ring_width: float = 4.0
@export var ring_color: Color = Color(1.0, 0.92, 0.75, 0.5)

var _layer: CanvasLayer
var _ring: Line2D


func _ready() -> void:
	_build_ring()
	if EventBus.has_signal("boss_clear_radial_pulse"):
		EventBus.boss_clear_radial_pulse.connect(_on_pulse)


func _build_ring() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "BossClearLayer"
	add_child(_layer)
	_ring = Line2D.new()
	_ring.name = "PulseRing"
	_ring.width = ring_width
	_ring.default_color = ring_color
	_draw_circle(_ring, 64, 1.0)
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		_ring.material = mat
	_layer.add_child(_ring)
	_ring.visible = false


func _draw_circle(line: Line2D, points: int, radius: float) -> void:
	line.clear_points()
	for i in points + 1:
		var a := (float(i) / float(points)) * TAU
		line.add_point(Vector2(cos(a), sin(a)) * radius * 320.0)


func _on_pulse() -> void:
	if not _ring:
		return
	var vp := get_viewport().get_visible_rect()
	_ring.position = vp.size / 2.0
	_ring.visible = true
	_ring.scale = Vector2(ring_radius_start, ring_radius_start)
	_ring.modulate.a = 0.8
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_ring, "scale", Vector2(ring_radius_end, ring_radius_end), pulse_duration)
	var c := ring_color
	tween.parallel().tween_property(_ring, "modulate", Color(c.r, c.g, c.b, 0.0), pulse_duration)
	await tween.finished
	_ring.visible = false
	_ring.modulate.a = 0.8
