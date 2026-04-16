extends Node
class_name PatternSpiral
## Reusable pattern: spiral of bullets. Emits bullet_spawn_requested per bullet.

@export var bullet_count: int = 12
@export var total_angle: float = TAU
@export var bullet_speed: float = 200.0
@export var damage: int = 1
@export var is_player: bool = false

var _phase: float = 0.0  # Offset each burst


func fire(origin: Vector2, direction: Vector2) -> void:
	var base_angle := direction.angle()
	for i in bullet_count:
		var t := float(i) / float(bullet_count)
		var angle := base_angle + t * total_angle + _phase
		var dir := Vector2.from_angle(angle)
		EventBus.bullet_spawn_requested.emit(origin, dir, bullet_speed, damage, is_player, "")
	_phase += 0.3  # Rotate next burst
