extends CharacterBody2D
class_name PlayerController
## Player: WASD movement, smooth acceleration, auto-fire weapon.
## Hitbox smaller than sprite; damage + invulnerability frames; triggers screen shake.

const NeonWings := preload("res://scripts/neon_wings.gd")

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
	_spawn_neon_wings()


## 於 _ready 自動生成玩家霓虹翼並掛到飛機後方（機身尾端）。
## 使用 res://scripts/neon_wings.gd 程序化雙層（Core + Glow）HDR Shader。
func _spawn_neon_wings() -> void:
	if get_node_or_null("NeonWings"):
		return  ## 場景已有自訂翼就不覆蓋
	var wings := Node2D.new()
	wings.name = "NeonWings"
	wings.set_script(NeonWings)
	## 幾何：適配 Player 飛機尺寸（Visual scale 1.25，機身 ±14px）
	wings.wing_span = 54.0
	wings.sweep_angle = 32.0
	wings.wing_depth = 18.0
	wings.jag_amount = 0.55
	wings.glow_padding = 12.0
	wings.anchor_offset = Vector2(0, 12)
	## HDR 青藍霓虹；G/B > 1.0 驅動 Bloom
	wings.neon_color = Color(0.38, 2.30, 3.10, 1.0)
	wings.pulse_speed = 3.0
	wings.pulse_strength = 0.32
	wings.core_brightness = 2.4
	wings.glow_softness = 0.6
	wings.edge_sharpness = 0.06
	wings.tip_boost = 1.6
	## Roll：反應玩家 velocity.x
	wings.auto_roll_from_parent = true
	wings.roll_amount = 0.28
	wings.roll_smoothness = 9.0
	## 渲染於 Visual 之下
	wings.z_as_relative = true
	wings.z_index = -1
	add_child(wings)


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
	"wing_gun": "res://scenes/weapons/weapon_wing_gun.tscn",
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


## 手動發射（從雙翼各射一發霓虹子彈）。
## 由輸入 / 測試 / 劇情演出直接呼叫；獨立於自動武器之外。
func shoot(damage_amount: int = 3, speed: float = 620.0) -> void:
	var wings := get_node_or_null("NeonWings") as Node2D
	var dir: Vector2 = Vector2.UP
	var origins: Array[Vector2] = []
	if wings and wings.has_method("get_wing_tip_global"):
		origins.append(wings.get_wing_tip_global(false))
		origins.append(wings.get_wing_tip_global(true))
	else:
		var r: Vector2 = global_transform.x
		origins.append(global_position - r * 18.0)
		origins.append(global_position + r * 18.0)
	for o in origins:
		EventBus.bullet_spawn_requested.emit(o, dir, speed, damage_amount, true, "wing_gun")


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
	set_process(false)
	velocity = Vector2.ZERO
	if _weapon:
		_weapon.set_process(false)
	## 停用碰撞，避免死亡後敵人仍不斷觸發 take_damage
	collision_layer = 0
	collision_mask = 0
	if hitbox:
		hitbox.set_deferred("disabled", true)
	EventBus.player_died.emit()
	died.emit()
	## 視覺淡出；保留節點以供 UI 讀取最終狀態，延遲回收
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.45)
	t.tween_callback(func() -> void:
		visible = false
	)


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
