extends Node
## Spawns currency pickups and a small visual at enemy death. Pickups attract to player and add run currency.

const CURRENCY_PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/currency_pickup.tscn")

@export var drop_radius: float = 6.0
@export var float_height: float = 28.0
@export var duration: float = 0.35
@export var drop_color: Color = Color(1.0, 0.88, 0.4, 0.9)

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Node, at_position: Vector2) -> void:
	_spawn_currency_pickup(enemy, at_position)
	_spawn_visual_drop(at_position)


func _spawn_currency_pickup(enemy: Node, at_position: Vector2) -> void:
	var pickup: Node = CURRENCY_PICKUP_SCENE.instantiate()
	if pickup is CurrencyPickup:
		var v: int = 1
		if "currency_drop" in enemy:
			v = int(enemy.get("currency_drop"))
		(pickup as CurrencyPickup).set_value(v)
	pickup.global_position = at_position
	var parent: Node = get_tree().current_scene.get_node_or_null("World")
	if not parent:
		parent = get_tree().current_scene
	parent.add_child(pickup)


func _spawn_visual_drop(at_position: Vector2) -> void:
	var drop := Node2D.new()
	drop.global_position = at_position
	drop.z_index = 15
	var radius := drop_radius
	var color := drop_color
	if RunState and RunState.is_opening_phase():
		radius *= RunState.opening_visual_scale
		color = Color(color.r, color.g, color.b, minf(1.0, color.a * 1.2))
	var poly := Polygon2D.new()
	var points: PackedVector2Array = []
	for i in 10:
		var a := TAU * i / 10.0
		points.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = points
	poly.color = color
	poly.material = load("res://resources/materials/additive_material.tres") as Material
	drop.add_child(poly)
	get_tree().current_scene.add_child(drop)
	var tween := drop.create_tween()
	tween.set_parallel(true)
	tween.tween_property(drop, "position:y", drop.position.y - float_height, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(drop, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void: drop.queue_free())
