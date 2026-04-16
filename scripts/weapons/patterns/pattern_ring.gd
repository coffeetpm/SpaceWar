extends Node
class_name PatternRing
## Reusable pattern: ring of bullets (evenly spaced).

@export var bullet_count: int = 16
@export var bullet_speed: float = 180.0
@export var damage: int = 1
@export var is_player: bool = false
@export var rotation_offset: float = 0.0


func fire(origin: Vector2, _direction: Vector2) -> void:
	for i in bullet_count:
		var angle := (float(i) / float(bullet_count)) * TAU + rotation_offset
		var dir := Vector2.from_angle(angle)
		EventBus.bullet_spawn_requested.emit(origin, dir, bullet_speed, damage, is_player, "")
