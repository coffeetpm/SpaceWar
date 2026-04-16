extends Node
## Applies upgrade effects to player/weapon. Stackable; no hard coupling to specific nodes.
## Use the UpgradeManager autoload to call apply().

var _stacks: Dictionary = {}  # id -> count


func clear_run() -> void:
	_stacks.clear()


func apply(upgrade: UpgradeData) -> void:
	if not upgrade:
		return
	var key: String = str(upgrade.id) if upgrade.id else upgrade.display_name
	var count: int = _stacks.get(key, 0)
	if count >= upgrade.max_stacks:
		return
	_stacks[key] = count + 1
	_apply_effect(upgrade, count + 1)
	if SynergyManager:
		SynergyManager.record_upgrade(upgrade)


func _apply_effect(upgrade: UpgradeData, stacks: int) -> void:
	var value := upgrade.effect_value * stacks
	match upgrade.effect_type:
		&"fire_rate":
			EventBus.emit_signal("upgrade_effect_fire_rate", value)
		&"damage":
			EventBus.emit_signal("upgrade_effect_damage", int(value))
		&"max_hp":
			EventBus.emit_signal("upgrade_effect_max_hp", int(value))
		&"projectile_speed":
			EventBus.emit_signal("upgrade_effect_projectile_speed", value)
		&"move_speed":
			EventBus.emit_signal("upgrade_effect_move_speed", value)
		_:
			pass  # Extensible: add new effect types
