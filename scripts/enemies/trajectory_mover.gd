extends Node
class_name TrajectoryMover
## 敵機軌跡控制器：附加到 CharacterBody2D 敵機上，接管其移動邏輯。
##
## 設計目標：配合 TopDownSpawner 產生「從畫面頂端以不同軌跡下落」嘅經典 shmup 敵機。
## 若父節點有 set_motion_override()（EnemyBase 提供），則保留射擊 AI 只覆蓋移動；
## 否則直接停用父節點 _physics_process。
##
## 掛載方式（由 spawner 自動）：
##   var m := TrajectoryMover.new()
##   m.pattern = TrajectoryMover.Pattern.SINE
##   m.speed = 180.0
##   enemy.add_child(m)

enum Pattern {
	STRAIGHT,   ## 直下：純垂直下墜
	SINE,       ## 正弦：左右搖擺下落
	DIAGONAL,   ## 斜線：固定傾角下滑
	ARC,        ## 弧線：大幅橫向弧線掃過
	SWOOP,      ## 俯衝：先下落後向玩家撲擊
}

@export var pattern: int = Pattern.STRAIGHT  ## 使用 int 以便 spawner 直接 assign
@export var speed: float = 160.0
@export_range(0.0, 400.0, 1.0) var amplitude: float = 90.0          ## SINE / ARC 橫向幅度
@export_range(0.05, 6.0, 0.05) var frequency: float = 1.8           ## SINE / ARC 頻率 (Hz)
@export_range(-60.0, 60.0, 0.5) var diagonal_angle_deg: float = 18.0
@export var swoop_trigger_y: float = 260.0                           ## SWOOP 開始俯衝的 Y 值（世界座標）
@export var despawn_margin: float = 140.0                            ## 離開視窗後 queue_free 緩衝

var _body: CharacterBody2D
var _took_over: bool = false
var _life: float = 0.0
var _base_x: float = 0.0
var _phase_offset: float = 0.0
var _swoop_dir: Vector2 = Vector2.ZERO
var _swoop_locked: bool = false


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_warning("TrajectoryMover: parent must be CharacterBody2D")
		set_physics_process(false)
		return

	## 接管移動：優先使用 EnemyBase 之 motion_override（保留射擊 AI），否則停全部 physics
	if _body.has_method("set_motion_override"):
		_body.set_motion_override(true)
	else:
		_body.set_physics_process(false)
	_took_over = true

	_base_x = _body.global_position.x
	_phase_offset = randf() * TAU


func _physics_process(delta: float) -> void:
	if not _took_over or _body == null or not is_instance_valid(_body):
		return
	if RunState and RunState.gameplay_frozen:
		return
	_life += delta
	_body.velocity = _compute_velocity()
	_body.move_and_slide()
	_check_despawn()


func _compute_velocity() -> Vector2:
	match pattern:
		Pattern.STRAIGHT:
			return Vector2(0.0, speed)

		Pattern.SINE:
			## 橫向位移 = amplitude * sin(t * ω + φ)，對時間微分 → 橫向速度
			var omega: float = frequency * TAU
			var vx: float = amplitude * omega * cos(_life * omega + _phase_offset)
			## 避免 vx 過大導致視覺不穩；限幅
			vx = clampf(vx, -speed * 1.4, speed * 1.4)
			return Vector2(vx, speed)

		Pattern.DIAGONAL:
			var angle: float = deg_to_rad(diagonal_angle_deg)
			return Vector2(sin(angle) * speed, cos(angle) * speed)

		Pattern.ARC:
			## 0→1 週期做單一大幅橫向弧（cos 形），隨時間縮小
			var phase: float = clampf(_life * frequency, 0.0, 2.0)
			var vx: float = sin(phase * PI) * amplitude * 2.2
			return Vector2(vx, speed * (0.7 + 0.3 * cos(phase * PI)))

		Pattern.SWOOP:
			## 先穩定下落到 trigger_y，然後鎖定一個方向向玩家俯衝
			if not _swoop_locked:
				if _body.global_position.y < swoop_trigger_y:
					return Vector2(0.0, speed * 0.55)
				else:
					_lock_swoop_direction()
			return _swoop_dir * speed * 1.9

	return Vector2(0.0, speed)


func _lock_swoop_direction() -> void:
	_swoop_locked = true
	var player: Node2D = null
	if PlayerRef and PlayerRef.has_method("get_player"):
		player = PlayerRef.get_player()
	if player and is_instance_valid(player):
		_swoop_dir = (player.global_position - _body.global_position).normalized()
	else:
		_swoop_dir = Vector2.DOWN


func _check_despawn() -> void:
	var vp: Viewport = _body.get_viewport()
	if vp == null:
		return
	var vp_rect: Rect2 = vp.get_visible_rect()
	var cam: Camera2D = vp.get_camera_2d()
	var bottom_y: float
	var left_x: float
	var right_x: float
	if cam:
		var half_w: float = vp_rect.size.x * 0.5 / maxf(0.0001, cam.zoom.x)
		var half_h: float = vp_rect.size.y * 0.5 / maxf(0.0001, cam.zoom.y)
		bottom_y = cam.global_position.y + half_h + despawn_margin
		left_x = cam.global_position.x - half_w - despawn_margin
		right_x = cam.global_position.x + half_w + despawn_margin
	else:
		bottom_y = vp_rect.size.y + despawn_margin
		left_x = -despawn_margin
		right_x = vp_rect.size.x + despawn_margin
	var pos: Vector2 = _body.global_position
	if pos.y > bottom_y or pos.x < left_x or pos.x > right_x:
		_body.queue_free()
