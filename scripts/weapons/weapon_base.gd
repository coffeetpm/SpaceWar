extends Node2D
class_name WeaponBase
## Base auto-fire weapon. Fire rate, projectile speed, upgrade-ready.

signal fired

@export var fire_rate: float = 12.6  # Brotato-style: x1.5 for immediate power
@export var projectile_speed: float = 518.0
@export var damage: int = 4  # x1.8 for dominant early game
@export var is_player_weapon: bool = true

var _time_until_shot: float = 0.0
var _fire_rate_bonus: float = 0.0
var _damage_bonus: int = 0
var _speed_bonus: float = 0.0


func _ready() -> void:
	EventBus.upgrade_effect_fire_rate.connect(_on_fire_rate_upgrade)
	EventBus.upgrade_effect_damage.connect(_on_damage_upgrade)
	EventBus.upgrade_effect_projectile_speed.connect(_on_speed_upgrade)


func _on_fire_rate_upgrade(value: float) -> void:
	_fire_rate_bonus += value


func _on_damage_upgrade(value: int) -> void:
	_damage_bonus += value


func _on_speed_upgrade(value: float) -> void:
	_speed_bonus += value


func _process(delta: float) -> void:
	_time_until_shot -= delta
	if _time_until_shot <= 0.0:
		_try_fire()
		var rate := fire_rate + _fire_rate_bonus
		_time_until_shot = 1.0 / maxf(rate, 0.5)


func _try_fire() -> void:
	var direction := _get_fire_direction()
	if direction == Vector2.ZERO:
		return
	var origin := global_position
	EventBus.bullet_spawn_requested.emit(origin, direction, projectile_speed + _speed_bonus, damage + _damage_bonus, is_player_weapon, "")
	fired.emit()


func _get_fire_direction() -> Vector2:
	# Override for aim; default: up (negative Y in Godot 2D)
	if get_parent() is Node2D:
		return -get_parent().global_transform.y
	return Vector2.UP
