extends Node2D
class_name WeaponWingGun
## 玩家霓虹翼雙口槍：使用 Timer 節點做 fire rate，每次同時從左右翼尖發射一發。
## 子彈透過 EventBus.bullet_spawn_requested 走現有 BulletPool。
##
## 結構：
##   WeaponWingGun (Node2D, attach to WeaponMount)
##   └─ FireTimer (Timer, autostart=true, one_shot=false)
##
## Fire rate / Damage / Speed 受現有 upgrade_effect_* 訊號影響（與 WeaponBase 同步）。

signal fired

@export var fire_rate: float = 9.0                  ## shots / sec per wing → 實際 18 dps (雙翼)
@export var projectile_speed: float = 620.0
@export var damage: int = 3
@export var is_player_weapon: bool = true
@export var weapon_id: String = "wing_gun"
## 子彈偏移方向（角度）：+ 為向外側擴散；0 為正前方；雙翼鏡像。
@export_range(-20.0, 20.0, 0.1) var wing_spread_degrees: float = 3.0
## 若無 NeonWings 時的 fallback 射擊偏移（px）
@export var fallback_wing_offset_x: float = 18.0

var _fire_rate_bonus: float = 0.0
var _damage_bonus: int = 0
var _speed_bonus: float = 0.0

var _timer: Timer
var _cached_wings: Node2D  # NeonWings 節點（由 duck typing 探測）


func _ready() -> void:
	_timer = Timer.new()
	_timer.name = "FireTimer"
	_timer.one_shot = false
	_timer.autostart = false
	_timer.wait_time = _current_interval()
	_timer.timeout.connect(_on_fire_timer)
	add_child(_timer)
	_timer.start()

	EventBus.upgrade_effect_fire_rate.connect(_on_fire_rate_upgrade)
	EventBus.upgrade_effect_damage.connect(_on_damage_upgrade)
	EventBus.upgrade_effect_projectile_speed.connect(_on_speed_upgrade)


func _current_interval() -> float:
	var rate: float = maxf(0.5, fire_rate + _fire_rate_bonus)
	return 1.0 / rate


func _on_fire_rate_upgrade(value: float) -> void:
	_fire_rate_bonus += value
	if _timer:
		_timer.wait_time = _current_interval()


func _on_damage_upgrade(value: int) -> void:
	_damage_bonus += value


func _on_speed_upgrade(value: float) -> void:
	_speed_bonus += value


func _on_fire_timer() -> void:
	if RunState and RunState.gameplay_frozen:
		return
	_fire_from_wings()


## 取 Player 的 NeonWings 節點並回傳左右翼尖 global 座標。
## 若無，fallback 以 WeaponMount 左右偏移模擬。
func _get_firing_origins() -> Array:
	var player := _get_player_node()
	if player == null:
		var up: Vector2 = -global_transform.y
		var right: Vector2 = global_transform.x
		return [
			global_position - right * fallback_wing_offset_x,
			global_position + right * fallback_wing_offset_x,
		]
	var wings := _find_wings(player)
	if wings and wings.has_method("get_wing_tip_global"):
		return [
			wings.get_wing_tip_global(false),
			wings.get_wing_tip_global(true),
		]
	## 無 NeonWings：以 player 右向量為左右偏移
	var r: Vector2 = player.global_transform.x
	return [
		player.global_position - r * fallback_wing_offset_x,
		player.global_position + r * fallback_wing_offset_x,
	]


func _get_player_node() -> Node2D:
	if PlayerRef and PlayerRef.has_method("get_player"):
		var p := PlayerRef.get_player()
		if p:
			return p
	var parent := get_parent()
	while parent:
		if parent is Node2D and (parent as Node).is_in_group("player"):
			return parent as Node2D
		parent = parent.get_parent()
	return null


func _find_wings(player: Node2D) -> Node2D:
	if _cached_wings and is_instance_valid(_cached_wings):
		return _cached_wings
	var n := player.get_node_or_null("NeonWings") as Node2D
	if n:
		_cached_wings = n
		return n
	## 深度尋找（極少用到）
	for c in player.get_children():
		if c is Node2D and (c as Node).get("get_wing_tip_global") != null:
			_cached_wings = c
			return c
	return null


func _fire_from_wings() -> void:
	var origins: Array = _get_firing_origins()
	if origins.size() < 2:
		return
	var forward: Vector2 = _aim_direction()
	if forward == Vector2.ZERO:
		forward = Vector2.UP

	var spread_rad: float = deg_to_rad(wing_spread_degrees)
	## 左翼：稍偏左外；右翼：稍偏右外
	var dir_left: Vector2 = forward.rotated(-spread_rad)
	var dir_right: Vector2 = forward.rotated(spread_rad)

	var speed: float = projectile_speed + _speed_bonus
	var dmg: int = damage + _damage_bonus

	EventBus.bullet_spawn_requested.emit(origins[0], dir_left, speed, dmg, is_player_weapon, weapon_id)
	EventBus.bullet_spawn_requested.emit(origins[1], dir_right, speed, dmg, is_player_weapon, weapon_id)
	fired.emit()


func _aim_direction() -> Vector2:
	## 預設：Player 向 -y 射擊（遊戲方向）
	var parent := get_parent()
	if parent is Node2D:
		return -(parent as Node2D).global_transform.y
	return Vector2.UP
