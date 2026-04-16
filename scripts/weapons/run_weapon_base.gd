extends Node2D
class_name RunWeaponBase
## Brotato-style run weapon base. Each run is defined by the weapon; upgrades enhance it.
## Subclasses override _try_fire() for pattern/timing/spatial behaviour and set weapon_id.

signal fired

@export var weapon_id: String = "default"
@export var fire_rate: float = 9.2
@export var projectile_speed: float = 518.0
@export var damage: int = 3
@export var is_player_weapon: bool = true
## When true, fire opposite to movement direction while moving (behind-fire behaviour).
@export var fire_backward_when_moving: bool = false

var _time_until_shot: float = 0.0
var _fire_rate_bonus: float = 0.0
var _damage_bonus: int = 0
var _speed_bonus: float = 0.0
## Override in subclasses to override vocabulary; default from BuildVocabulary by weapon_id.
var _weapon_tags: Array[String] = []
## Last aim direction when no enemy (keeps combat from snapping back to UP).
var _last_aim_direction: Vector2 = Vector2.UP


func get_run_weapon_id() -> String:
	return weapon_id


## Primary force (LIGHT / TIME / SPACE) for this weapon. Run identity = combination of forces.
func get_weapon_force() -> String:
	if BuildVocabulary:
		return BuildVocabulary.get_weapon_force(weapon_id)
	return "light"


## Tags for synergy: [force, ...force_sub_tags] from BuildVocabulary (e.g. light + refraction, echo).
func get_weapon_tags() -> Array[String]:
	if _weapon_tags.size() > 0:
		return _weapon_tags
	if BuildVocabulary:
		return BuildVocabulary.get_weapon_tags_for_id(weapon_id)
	return [weapon_id]


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
		var rate := _get_effective_fire_rate()
		_time_until_shot = 1.0 / maxf(rate, 0.5)


func _get_effective_fire_rate() -> float:
	var rate := fire_rate + _fire_rate_bonus
	if RunState and RunState.is_opening_burst():
		rate *= 1.8
	return rate


## Override in subclasses: spread, beam, burst, drones, homing.
func _try_fire() -> void:
	var direction := _get_fire_direction()
	if direction == Vector2.ZERO:
		return
	_fire_single(global_position, direction)


func _get_fire_direction() -> Vector2:
	# Rear / backward weapons: prefer movement direction first
	if fire_backward_when_moving:
		var back := _get_direction_backward()
		if back != Vector2.ZERO:
			_last_aim_direction = back
			return back
	# Auto-aim: nearest enemy, then last aim, never hardcoded UP-only
	var toward := _get_direction_toward_nearest_enemy()
	if toward != Vector2.ZERO:
		_last_aim_direction = toward
		return toward
	# No enemy: keep last aim so combat stays multi-directional
	if _last_aim_direction == Vector2.ZERO:
		_last_aim_direction = Vector2.UP
	return _last_aim_direction


## Omni-direction: aim at nearest enemy. Return Vector2.ZERO if none.
func _get_direction_toward_nearest_enemy() -> Vector2:
	if CombatUtil:
		return CombatUtil.get_direction_to_nearest_enemy(global_position, get_tree())
	var nearest: Node2D = null
	var best_dist_sq := 1e10
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue
		var n := node as Node2D
		var d_sq := global_position.distance_squared_to(n.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			nearest = n
	if nearest:
		return (nearest.global_position - global_position).normalized()
	return Vector2.ZERO


## Behind-fire: shoot opposite to movement when moving. Return Vector2.ZERO when idle.
func _get_direction_backward() -> Vector2:
	var body := get_parent()
	if body is CharacterBody2D:
		var vel: Vector2 = (body as CharacterBody2D).velocity
		if vel.length_squared() > 900.0:
			return -vel.normalized()
	return Vector2.ZERO


func _fire_single(origin: Vector2, direction: Vector2, override_weapon_id: String = "") -> void:
	var wid: String = override_weapon_id if override_weapon_id else get_run_weapon_id()
	EventBus.bullet_spawn_requested.emit(origin, direction, projectile_speed + _speed_bonus, damage + _damage_bonus, is_player_weapon, wid)
	if EventBus.has_signal("muzzle_flash_requested"):
		EventBus.muzzle_flash_requested.emit(origin, wid)
	fired.emit()


func _damage_with_bonus() -> int:
	var base_dmg: int = damage + _damage_bonus
	if RunState:
		base_dmg = int(base_dmg * RunState.get_ignition_damage_mult())
	return base_dmg


func _speed_with_bonus() -> float:
	return projectile_speed + _speed_bonus
