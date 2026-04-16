extends RunWeaponBase
## Rear Cannon: fires only when moving above threshold. Skill expression; TIME identity.

@export var min_speed_to_fire: float = 32.0

func _ready() -> void:
	weapon_id = "rear"
	fire_backward_when_moving = true
	super._ready()


func _get_direction_backward() -> Vector2:
	var body := get_parent()
	if body is CharacterBody2D:
		var vel: Vector2 = (body as CharacterBody2D).velocity
		var thresh_sq := min_speed_to_fire * min_speed_to_fire
		if vel.length_squared() > thresh_sq:
			return -vel.normalized()
	return Vector2.ZERO


func _try_fire() -> void:
	var direction := _get_fire_direction()
	if direction == Vector2.ZERO:
		return
	_fire_single(global_position, direction)
	if SynergyManager:
		SynergyManager.fire_trigger("pulse_fired", {
			"position": global_position,
			"direction": direction,
			"damage": _damage_with_bonus(),
			"speed": _speed_with_bonus(),
			"weapon_tags": get_weapon_tags(),
		})
	fired.emit()
