extends Node2D
## Faint radial glow around player; increases when enemies are near to help eyes lock to player.

@export var enemy_radius: float = 420.0
@export var alpha_min: float = 0.08
@export var alpha_max: float = 0.22
@export var enemy_count_for_max: float = 5.0

var _glow: CanvasItem


func _ready() -> void:
	_glow = get_node_or_null("Glow") as CanvasItem
	if not _glow:
		_glow = self


func _process(_delta: float) -> void:
	if not _glow:
		return
	var body := get_parent() as Node2D
	if not body or not is_instance_valid(body):
		return
	var count := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node) and node is Node2D:
			if body.global_position.distance_to((node as Node2D).global_position) <= enemy_radius:
				count += 1
	var t := clampf(count / enemy_count_for_max, 0.0, 1.0)
	var a := lerpf(alpha_min, alpha_max, t)
	_glow.modulate = Color(1.0, 1.0, 1.0, a)
