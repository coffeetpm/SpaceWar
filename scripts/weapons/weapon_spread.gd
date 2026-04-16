extends RunWeaponBase
## Spread Shot: multi-trail cone. Gameplay: wide coverage, close-range payoff.

func _ready() -> void:
	weapon_id = "spread"
	super._ready()


func _try_fire() -> void:
	var direction := _get_fire_direction()
	if direction == Vector2.ZERO:
		return
	var origin := global_position
	var base_angle := direction.angle()
	var spread_rad := deg_to_rad(28.0)
	var count := 5
	for i in count:
		var t := 0.0 if count <= 1 else (float(i) / float(count - 1) - 0.5) * 2.0
		var angle := base_angle + t * spread_rad * 0.5
		var dir := Vector2.from_angle(angle)
		EventBus.bullet_spawn_requested.emit(origin, dir, _speed_with_bonus(), _damage_with_bonus(), is_player_weapon, get_run_weapon_id())
	if SynergyManager:
		SynergyManager.fire_trigger("pulse_fired", {
			"position": origin,
			"direction": direction,
			"damage": _damage_with_bonus(),
			"speed": _speed_with_bonus(),
			"weapon_tags": get_weapon_tags(),
		})
	if EventBus.has_signal("muzzle_flash_requested"):
		EventBus.muzzle_flash_requested.emit(origin, get_run_weapon_id())
	fired.emit()
