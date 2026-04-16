extends Node2D
class_name BulletPool
## Pre-instantiates bullets; get/return to avoid spawn/destroy loops.
## When Refraction Duplication is unlocked, player shots spawn a refracted echo (secondary trajectory, visual + functional).

@export var pool_size: int = 256
@export var bullet_scene: PackedScene

## Refraction echo: angle offset (radians). Alternate +/– per shot so path is readable.
const REFRACTION_ANGLE_RAD := 0.2
const REFRACTION_ECHO_DAMAGE_SCALE := 0.5

var _pool: Array[Bullet] = []
var _next_index: int = 0
var _refraction_alternate: bool = false


func _ready() -> void:
	if not bullet_scene:
		bullet_scene = preload("res://scenes/weapons/bullet.tscn")
	for i in pool_size:
		var b: Bullet = bullet_scene.instantiate() as Bullet
		b.set_process(false)
		b.visible = false
		b.set_pool(self)
		add_child(b)
		_pool.append(b)
	EventBus.bullet_spawn_requested.connect(_on_bullet_spawn_requested)
	EventBus.bullet_spawn_requested_homing.connect(_on_bullet_spawn_requested_homing)


func _on_bullet_spawn_requested(global_pos: Vector2, direction: Vector2, speed: float, damage: int, is_player: bool, weapon_id: String = "") -> void:
	var bullet := get_next()
	if bullet:
		bullet.setup(global_pos, direction, speed, damage, is_player, false, weapon_id, false)
	if is_player and SaveManager and SaveManager.is_refraction_unlocked():
		_spawn_refraction_echo(global_pos, direction, speed, damage, weapon_id, false)


func _on_bullet_spawn_requested_homing(global_pos: Vector2, direction: Vector2, speed: float, damage: int, weapon_id: String = "") -> void:
	var bullet := get_next()
	if bullet:
		bullet.setup(global_pos, direction, speed, damage, true, true, weapon_id, false)
	if SaveManager and SaveManager.is_refraction_unlocked():
		_spawn_refraction_echo(global_pos, direction, speed, damage, weapon_id, true)


func _spawn_refraction_echo(global_pos: Vector2, direction: Vector2, speed: float, damage: int, weapon_id: String, is_homing: bool) -> void:
	var echo := get_next()
	if not echo:
		return
	var angle := REFRACTION_ANGLE_RAD if _refraction_alternate else -REFRACTION_ANGLE_RAD
	_refraction_alternate = not _refraction_alternate
	var refracted_dir := direction.normalized().rotated(angle)
	var echo_damage := maxi(1, int(float(damage) * REFRACTION_ECHO_DAMAGE_SCALE))
	echo.setup(global_pos, refracted_dir, speed, echo_damage, true, is_homing, weapon_id, true)


## Number of bullets currently visible (for motif opacity / combat density).
func get_active_count() -> int:
	var n := 0
	for b in _pool:
		if b.visible:
			n += 1
	return n


func get_next() -> Bullet:
	for i in _pool.size():
		var idx := (_next_index + i) % _pool.size()
		var b := _pool[idx] as Bullet
		if not b.visible:
			_next_index = (idx + 1) % _pool.size()
			return b
	# Pool exhausted; optionally expand or drop shot
	return null


func return_bullet(bullet: Node2D) -> void:
	bullet.visible = false
	bullet.set_process(false)
	bullet.set_physics_process(false)


## Boss clear: stop all projectiles instantly. No explosion spam — minimal, precise.
func clear_all() -> void:
	for b in _pool:
		if b.visible:
			return_bullet(b)
