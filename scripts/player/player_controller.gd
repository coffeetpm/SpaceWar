extends CharacterBody2D
class_name PlayerController
## Player: WASD movement, smooth acceleration, auto-fire weapon.
## Hitbox smaller than sprite; damage + invulnerability frames; triggers screen shake.

signal died

const ACCELERATION := 1800.0
const FRICTION := 1380.0
var MAX_SPEED := 420.0
var _speed_bonus: float = 0.0

@export var max_hp: int = 5
@export var invulnerability_duration: float = 1.2
@export var hitbox_scale: float = 0.7

## EXP / level (Vampire-Survivors style). Drops fill exp; when exp >= exp_to_next, level up.
var level: int = 1
var exp: int = 0
var exp_to_next: int = 8

var current_hp: int:
	set(v):
		current_hp = clampi(v, 0, max_hp)
		if current_hp <= 0:
			_die()

var _invulnerable_until: float = 0.0
var _weapon: Node2D

@onready var hitbox: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var sprite: CanvasItem = $Visual
@onready var weapon_mount: Node2D = $WeaponMount
@onready var _trail: Line2D = $Trail

const TRAIL_LENGTH := 24
var _trail_points: Array[Vector2] = []


func _ready() -> void:
	current_hp = max_hp
	_apply_hitbox_scale()
	EventBus.player_damaged.connect(_on_player_damaged_signal)
	EventBus.upgrade_effect_max_hp.connect(_on_max_hp_upgrade)
	EventBus.upgrade_effect_move_speed.connect(_on_move_speed_upgrade)
	EventBus.run_started.connect(_on_run_started)
	EventBus.exp_collected.connect(_on_exp_collected)
	if EventBus.has_signal("boss_clear_player_glow"):
		EventBus.boss_clear_player_glow.connect(_on_boss_clear_glow)


func _on_max_hp_upgrade(value: int) -> void:
	max_hp += value
	current_hp = mini(current_hp + value, max_hp)


func _on_move_speed_upgrade(value: float) -> void:
	_speed_bonus += value


func _update_trail() -> void:
	if not _trail:
		return
	_trail_points.append(position)
	while _trail_points.size() > TRAIL_LENGTH:
		_trail_points.remove_at(0)
	_trail.clear_points()
	for p in _trail_points:
		_trail.add_point(p)
	if _trail.get_point_count() > 1 and _trail.gradient == null:
		var g := Gradient.new()
		g.add_point(0.0, ArtDirection.PLAYER_TRAIL_TAIL)
		g.add_point(1.0, ArtDirection.PLAYER_TRAIL_HEAD)
		_trail.gradient = g


func _apply_hitbox_scale() -> void:
	if hitbox and hitbox.shape is CircleShape2D:
		var s := hitbox.shape as CircleShape2D
		s.radius *= hitbox_scale
	elif hitbox and hitbox.shape is RectangleShape2D:
		var s := hitbox.shape as RectangleShape2D
		s.size *= hitbox_scale


const WEAPON_SCENES: Dictionary = {
	"spread": "res://scenes/weapons/weapon_spread.tscn",
	"beam": "res://scenes/weapons/weapon_beam.tscn",
	"drones": "res://scenes/weapons/weapon_drones.tscn",
	"burst": "res://scenes/weapons/weapon_burst.tscn",
	"homing": "res://scenes/weapons/weapon_homing.tscn",
	"rear": "res://scenes/weapons/weapon_rear.tscn",
}


func _on_run_started(weapon_id: String) -> void:
	level = 1
	exp = 0
	exp_to_next = _exp_for_level(1)
	_spawn_weapon(weapon_id)
	if SynergyManager and SynergyManager.has_method("set_run_weapon_force"):
		SynergyManager.set_run_weapon_force(weapon_id)


## First level ~8–12s; then scaling. Base 8 so first level-up happens early.
func _exp_for_level(lvl: int) -> int:
	return int(8.0 + lvl * 5.0 + lvl * lvl * 0.4)


func _on_exp_collected(amount: int) -> void:
	exp += amount
	while exp >= exp_to_next:
		_do_level_up()


func _do_level_up() -> void:
	exp -= exp_to_next
	level += 1
	exp_to_next = _exp_for_level(level)
	EventBus.level_up.emit(level)


func _spawn_weapon(weapon_id: String = "spread") -> void:
	if not weapon_mount:
		return
	for child in weapon_mount.get_children():
		child.queue_free()
	_weapon = null
	var path: String = WEAPON_SCENES.get(weapon_id, "res://scenes/weapons/weapon_spread.tscn")
	var weapon_scene: PackedScene = load(path) as PackedScene
	if weapon_scene:
		_weapon = weapon_scene.instantiate()
		weapon_mount.add_child(_weapon)


func _physics_process(delta: float) -> void:
	if RunState and RunState.gameplay_frozen:
		return
	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * (MAX_SPEED + _speed_bonus), ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	_update_trail()
	_update_lean(delta)


func _update_lean(delta: float) -> void:
	var vis: Node2D = $Visual as Node2D
	if not vis:
		return
	var target_angle: float = velocity.angle() if velocity.length() > 18.0 else 0.0
	target_angle = clampf(target_angle, -0.2, 0.2)
	vis.rotation = lerp_angle(vis.rotation, target_angle, delta * 10.0)


func take_damage(amount: int, _source: Node = null) -> void:
	if _is_invulnerable():
		return
	current_hp -= amount
	_invulnerable_until = Time.get_ticks_msec() / 1000.0 + invulnerability_duration
	EventBus.player_damaged.emit(amount, _source)
	EventBus.screen_shake_requested.emit(0.55, 0.22)
	EventBus.hit_flash_requested.emit(sprite, 0.1)
	EventBus.hit_flash_requested.emit(null, 0.15)
	EventBus.time_scale_dip_requested.emit(0.15, 0.3)


func _is_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _invulnerable_until


func _die() -> void:
	set_physics_process(false)
	if _weapon:
		_weapon.set_process(false)
	EventBus.player_died.emit()
	died.emit()
	# Optional: play death VFX then queue_free or hide


func _on_player_damaged_signal(_amount: int, _source: Node) -> void:
	# Optional: react to own damage from EventBus (e.g. UI)
	pass


func _on_boss_clear_glow() -> void:
	if not sprite:
		return
	var orig := sprite.modulate
	sprite.modulate = Color(1.12, 1.12, 1.06)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.modulate = orig
	)
