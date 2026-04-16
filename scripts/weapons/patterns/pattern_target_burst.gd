extends Node
class_name PatternTargetBurst
## Reusable pattern: burst toward target (e.g. player) with spread.

@export var bullet_count: int = 5
@export var spread_degrees: float = 15.0
@export var bullet_speed: float = 220.0
@export var damage: int = 1
@export var is_player: bool = false


func fire(origin: Vector2, direction: Vector2) -> void:
	var base_angle := direction.angle()
	var half_spread := deg_to_rad(spread_degrees) * 0.5
	for i in bullet_count:
		var t := 0.0 if bullet_count <= 1 else float(i) / float(bullet_count - 1) - 0.5
		var angle := base_angle + t * half_spread * 2.0
		var dir := Vector2.from_angle(angle)
		EventBus.bullet_spawn_requested.emit(origin, dir, bullet_speed, damage, is_player, "")
