extends Node2D
## Signature beam impact: clean energy fracture + light shards expand briefly, quick collapse. Technological, precise.

const FRACTURE_LINE_COUNT := 6
const FRACTURE_LENGTH := 24.0
const FRACTURE_WIDTH := 1.8
const SHARD_COUNT := 5
const SHARD_LENGTH := 14.0
const SHARD_WIDTH := 2.0
const EXPAND_DURATION := 0.06
const HOLD_DURATION := 0.04
const COLLAPSE_DURATION := 0.08
const FRACTURE_COLOR := Color(0.4, 0.88, 1.1, 0.9)
const SHARD_COLOR := Color(0.5, 0.95, 1.15, 0.85)


func _ready() -> void:
	_run_impact()


func _run_impact() -> void:
	var add_mat := load("res://resources/materials/additive_material.tres") as Material
	# Clean energy fracture: thin lines (crack)
	for i in FRACTURE_LINE_COUNT:
		var a := TAU * float(i) / float(FRACTURE_LINE_COUNT) + randf() * 0.2
		var line := Line2D.new()
		line.width = FRACTURE_WIDTH
		line.default_color = FRACTURE_COLOR
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2(cos(a), sin(a)) * FRACTURE_LENGTH * (0.7 + randf() * 0.3))
		if add_mat:
			line.material = add_mat
		add_child(line)
		var t := line.create_tween()
		t.tween_interval(EXPAND_DURATION + HOLD_DURATION)
		t.tween_property(line, "default_color:a", 0.0, COLLAPSE_DURATION)
		t.tween_callback(func() -> void: line.queue_free())
	# Light shards: expand then collapse
	for i in SHARD_COUNT:
		var a := TAU * float(i) / float(SHARD_COUNT) + 0.15
		var shard := Line2D.new()
		shard.width = SHARD_WIDTH
		shard.default_color = SHARD_COLOR
		shard.add_point(Vector2.ZERO)
		shard.add_point(Vector2(cos(a), sin(a)) * SHARD_LENGTH)
		if add_mat:
			shard.material = add_mat
		add_child(shard)
		shard.scale = Vector2(0.15, 0.15)
		var t := shard.create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(shard, "scale", Vector2(1.0, 1.0), EXPAND_DURATION)
		t.tween_interval(HOLD_DURATION)
		t.tween_property(shard, "scale", Vector2(0.08, 0.08), COLLAPSE_DURATION)
		t.parallel().tween_property(shard, "default_color:a", 0.0, COLLAPSE_DURATION)
		t.tween_callback(func() -> void: shard.queue_free())
	# Self-free after last effect
	await get_tree().create_timer(EXPAND_DURATION + HOLD_DURATION + COLLAPSE_DURATION + 0.02).timeout
	queue_free()
