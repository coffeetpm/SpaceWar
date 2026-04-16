extends RunWeaponBase
## Homing Pulse: curved trails, seeks nearest enemy. Spatial control via homing.

func _ready() -> void:
	weapon_id = "homing"
	super._ready()


func _try_fire() -> void:
	# Omni-direction: initial aim at nearest enemy; bullet then homes
	var direction := _get_direction_toward_nearest_enemy()
	if direction == Vector2.ZERO:
		direction = _get_fire_direction()
	if direction == Vector2.ZERO:
		return
	EventBus.bullet_spawn_requested_homing.emit(global_position, direction, _speed_with_bonus(), _damage_with_bonus(), get_run_weapon_id())
	if EventBus.has_signal("muzzle_flash_requested"):
		EventBus.muzzle_flash_requested.emit(global_position, get_run_weapon_id())
	if SynergyManager:
		SynergyManager.fire_trigger("pulse_fired", {
			"position": global_position,
			"direction": direction,
			"damage": _damage_with_bonus(),
			"speed": _speed_with_bonus(),
			"weapon_tags": get_weapon_tags(),
		})
	fired.emit()
