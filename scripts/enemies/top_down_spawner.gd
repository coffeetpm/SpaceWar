extends Node2D
class_name TopDownSpawner
## 從畫面頂部隨機生成敵機，並為每隻敵機套用一條不同軌跡。
##
## 設計：
## - 使用 Camera2D（若有）自動對齊「螢幕可視頂部」，令敵機係螢幕外剛好進入。
## - 支援多種軌跡：STRAIGHT / SINE / DIAGONAL / ARC / SWOOP（加權隨機）。
## - 敵機由現有 Bullet 邏輯傷害：Bullet._on_body_entered → body.take_damage()（敵機已 add_to_group("enemy")）。
## - 自動兼容 EnemyBase（保留射擊 AI）與其他 CharacterBody2D（完全接管）。
##
## 使用方式：
##   1) 將此腳本掛到 main.tscn 的任何 Node2D；或用 TopDownSpawner.new() 即時加到場景。
##   2) Inspector 可編輯 enemy_scenes / 權重 / 速度。
##   3) auto_start = true 時自動啟動；或由其他系統呼叫 start() / stop()。

signal enemy_spawned(enemy: Node2D, pattern: int)

const TrajectoryMoverScript := preload("res://scripts/enemies/trajectory_mover.gd")

@export var auto_start: bool = true
@export var enemy_scenes: Array[PackedScene] = []
## 敵機加入場景樹的父節點；若空，則使用 current_scene。
@export var enemy_parent_path: NodePath

@export_group("Spawn Timing")
@export_range(0.05, 5.0, 0.05) var spawn_interval_min: float = 0.55
@export_range(0.05, 8.0, 0.05) var spawn_interval_max: float = 1.35
## 每次 tick 生成的最大數量（用於偶爾「小叢集」）
@export_range(1, 6, 1) var burst_max: int = 1
## burst 機率（0..1）
@export_range(0.0, 1.0, 0.01) var burst_chance: float = 0.15

@export_group("Spawn Area")
@export_range(0.0, 400.0, 4.0) var horizontal_margin: float = 56.0
## 相對螢幕頂部再往上 offset（負值=更高）；敵機會由螢幕外降入
@export var spawn_y_offset: float = -60.0

@export_group("Speed Range")
@export var speed_min: float = 130.0
@export var speed_max: float = 220.0

@export_group("Trajectory Weights")
@export_range(0.0, 10.0, 0.1) var w_straight: float = 1.0
@export_range(0.0, 10.0, 0.1) var w_sine: float = 1.0
@export_range(0.0, 10.0, 0.1) var w_diagonal: float = 1.0
@export_range(0.0, 10.0, 0.1) var w_arc: float = 0.6
@export_range(0.0, 10.0, 0.1) var w_swoop: float = 0.4

@export_group("Difficulty")
## 隨時間縮短 spawn 間隔（每秒 *factor）：0 = 不隨時間加難
@export_range(0.0, 0.1, 0.001) var ramp_per_second: float = 0.006
## 間隔下限：避免爆量
@export var spawn_interval_floor: float = 0.22

var _timer: Timer
var _enabled: bool = false
var _run_time: float = 0.0


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_spawn_timer)
	add_child(_timer)

	if enemy_scenes.is_empty():
		_load_default_enemies()

	if auto_start:
		start()


func _process(delta: float) -> void:
	if _enabled and (RunState == null or not RunState.gameplay_frozen):
		_run_time += delta


func _load_default_enemies() -> void:
	## 預設敵機清單：如檔案存在即加入。
	var paths := [
		"res://scenes/enemies/enemy_basic.tscn",
		"res://scenes/enemies/enemy_scout.tscn",
		"res://scenes/enemies/enemy_shooter.tscn",
		"res://scenes/enemies/enemy_tank.tscn",
	]
	for p: String in paths:
		if ResourceLoader.exists(p):
			var sc: PackedScene = load(p) as PackedScene
			if sc:
				enemy_scenes.append(sc)


func start() -> void:
	if enemy_scenes.is_empty():
		push_warning("TopDownSpawner: enemy_scenes is empty; nothing will spawn.")
		return
	_enabled = true
	_run_time = 0.0
	_schedule_next()


func stop() -> void:
	_enabled = false
	if _timer:
		_timer.stop()


func _schedule_next() -> void:
	if not _enabled:
		return
	var base: float = randf_range(spawn_interval_min, spawn_interval_max)
	## 難度曲線：每秒乘以 (1 - ramp_per_second)，下限 spawn_interval_floor
	var ramp_mult: float = maxf(0.3, 1.0 - ramp_per_second * _run_time)
	var t: float = maxf(spawn_interval_floor, base * ramp_mult)
	_timer.start(t)


func _on_spawn_timer() -> void:
	if not _enabled:
		return
	if RunState == null or not RunState.gameplay_frozen:
		var count: int = 1
		if burst_max > 1 and randf() < burst_chance:
			count = randi_range(2, burst_max)
		for i in count:
			_spawn_one()
	_schedule_next()


func _spawn_one() -> void:
	var scene: PackedScene = enemy_scenes.pick_random() as PackedScene
	if scene == null:
		return
	var enemy: Node2D = scene.instantiate() as Node2D
	if enemy == null:
		return

	var spawn_pos: Vector2 = _pick_spawn_position()
	enemy.global_position = spawn_pos

	var parent: Node = _resolve_parent()
	parent.add_child(enemy)

	var pattern: int = _pick_pattern()
	_attach_trajectory(enemy, pattern)
	enemy_spawned.emit(enemy, pattern)


func _pick_spawn_position() -> Vector2:
	var vp: Viewport = get_viewport()
	var vp_rect: Rect2 = vp.get_visible_rect() if vp else Rect2(Vector2.ZERO, Vector2(1152, 648))
	var cam: Camera2D = vp.get_camera_2d() if vp else null
	var left: float
	var right: float
	var top: float
	if cam:
		var half_w: float = vp_rect.size.x * 0.5 / maxf(0.0001, cam.zoom.x)
		var half_h: float = vp_rect.size.y * 0.5 / maxf(0.0001, cam.zoom.y)
		left = cam.global_position.x - half_w + horizontal_margin
		right = cam.global_position.x + half_w - horizontal_margin
		top = cam.global_position.y - half_h + spawn_y_offset
	else:
		left = horizontal_margin
		right = vp_rect.size.x - horizontal_margin
		top = spawn_y_offset
	if right <= left:
		right = left + 1.0
	return Vector2(randf_range(left, right), top)


func _pick_pattern() -> int:
	var weights: Array = [w_straight, w_sine, w_diagonal, w_arc, w_swoop]
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return 0  # STRAIGHT
	var r: float = randf() * total
	var acc: float = 0.0
	for i in weights.size():
		acc += float(weights[i])
		if r <= acc:
			return i
	return 0  # STRAIGHT


func _attach_trajectory(enemy: Node2D, pattern: int) -> void:
	var mover: Node = TrajectoryMoverScript.new()
	mover.pattern = pattern
	mover.speed = randf_range(speed_min, speed_max)
	mover.amplitude = randf_range(70.0, 150.0)
	mover.frequency = randf_range(0.8, 2.4)
	mover.diagonal_angle_deg = randf_range(-26.0, 26.0)
	## SWOOP：在進入螢幕後一段距離才觸發俯衝，觀感清晰
	mover.swoop_trigger_y = enemy.global_position.y + randf_range(180.0, 320.0)
	enemy.add_child(mover)


func _resolve_parent() -> Node:
	if enemy_parent_path != NodePath(""):
		var n: Node = get_node_or_null(enemy_parent_path)
		if n:
			return n
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		return tree.current_scene
	return get_parent()
