extends CharacterBody2D
class_name EnemyBase
## Base enemy: move toward player, HP, death event, particle explosion.
## Motion identity: dart (scout), strafe (fighter), direct (tank). Core: idle pulse, attack brighten, death collapse.

signal died(enemy: Node, at_position: Vector2)

@export var max_hp: int = 3
@export var move_speed: float = 80.0
@export var damage_on_contact: int = 1
@export var explosion_scale: float = 1.0
@export var explosion_color: Color = Color.CYAN
@export var currency_drop: int = 1
@export var fire_interval: float = 1.5  # 0 = 不發射
@export var aim_at_player: bool = true  # Pattern 的 direction 是否指向玩家（Ring 可忽略）
## Motion identity: perpendicular dither (scout = darting, fighter = strafing). 0 = direct.
@export var dart_amount: float = 0.0
@export var strafe_amount: float = 0.0
@export var trail_length: int = 0  # 0 = no trail; scout ~14, fighter ~8

@export_group("Offscreen Cleanup")
## VSN2D 檢測矩形（以敵機為中心）；過大會延遲清理，過細會提早觸發。
@export var offscreen_rect_size: Vector2 = Vector2(96, 96)
## 敵機離開畫面後等候多少秒再回收；避免剛 spawn 就被殺。
@export var offscreen_grace: float = 3.0
## 絕對壽命上限（秒）；即使 VSN2D 失效亦必定回收，避免內存泄漏。
@export var max_lifetime: float = 60.0

const TRAIL_MAX := 20

var current_hp: int
var _player: Node2D
var _pattern: Node  # 具備 fire(origin: Vector2, direction: Vector2) 的節點
var _shoot_timer: float = 0.0
var _trail_points: Array[Vector2] = []
var _attack_brighten_until: float = 0.0
var _hit_pulse_until: float = 0.0
var _death_started: bool = false
var _core_base_modulate: Color = Color(1, 1, 1, 1)
## 若為 true：跳過預設 chase 移動（由外部如 TrajectoryMover 控制），仍保留射擊 AI。
var _motion_override: bool = false
## 快取 Visual/Core 同 Visual/Trail 避免每幀字串 lookup。
var _cached_core: CanvasItem
var _cached_trail: Line2D
var _cached_sprite: CanvasItem
## 離屏清理：VSN2D + grace Timer；進入畫面 flag 後先計，未 spawn 上畫面前唔會被殺。
var _vsn: VisibleOnScreenNotifier2D
var _offscreen_timer: Timer
var _has_entered_screen: bool = false
var _alive_time: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	current_hp = max_hp
	_find_player()
	# apply_stage_scaling() may be called by spawner after this to reduce HP for early stages
	_find_pattern()
	if fire_interval > 0.0:
		_shoot_timer = fire_interval * 0.5  # 首發延遲
	_cached_core = get_node_or_null("Visual/Core") as CanvasItem
	_cached_trail = get_node_or_null("Visual/Trail") as Line2D
	_cached_sprite = _resolve_sprite()
	if _cached_core:
		_core_base_modulate = _cached_core.modulate
	## 由 NeonStyleManager 依 Tier 自動套用霓虹裝飾（無需逐場景手動掛）。
	if NeonStyleManager and NeonStyleManager.has_method("apply_to"):
		NeonStyleManager.apply_to(self)
	## 若場景冇指定 explosion_color（仍為 EnemyBase 預設 CYAN），
	## 依 NeonStyleManager 推斷嘅霓虹色統一爆炸色，令每隻敵機爆自己嘅陣營色。
	if _is_default_explosion_color() and has_meta("neon_color"):
		var nc: Variant = get_meta("neon_color")
		if nc is Color:
			explosion_color = nc
	_setup_offscreen_cleanup()


## 設置 VisibleOnScreenNotifier2D 同 grace Timer；敵機離畫面一段時間後靜默回收。
func _setup_offscreen_cleanup() -> void:
	_vsn = VisibleOnScreenNotifier2D.new()
	_vsn.rect = Rect2(-offscreen_rect_size * 0.5, offscreen_rect_size)
	add_child(_vsn)
	_vsn.screen_entered.connect(_on_screen_entered)
	_vsn.screen_exited.connect(_on_screen_exited)

	_offscreen_timer = Timer.new()
	_offscreen_timer.one_shot = true
	_offscreen_timer.wait_time = maxf(offscreen_grace, 0.1)
	_offscreen_timer.timeout.connect(_on_offscreen_timeout)
	add_child(_offscreen_timer)


func _on_screen_entered() -> void:
	_has_entered_screen = true
	if _offscreen_timer and not _offscreen_timer.is_stopped():
		_offscreen_timer.stop()


func _on_screen_exited() -> void:
	## 冇真正入過畫面（e.g. 由 spawner 放喺畫面上方），唔觸發回收；等入屏後再計。
	if not _has_entered_screen or _death_started:
		return
	if _offscreen_timer and _offscreen_timer.is_stopped():
		_offscreen_timer.start()


func _on_offscreen_timeout() -> void:
	if _death_started:
		return
	## 再次確認仲係離屏（避免 grace 期間又 scroll 返入畫面）
	if _vsn and _vsn.is_on_screen():
		return
	_despawn_silently()


## 靜默回收：唔觸發爆炸/震動，但照發 died signal 令 WaveSpawner._alive_count 正確遞減。
func _despawn_silently() -> void:
	if _death_started:
		return
	_death_started = true
	collision_layer = 0
	collision_mask = 0
	died.emit(self, global_position)
	queue_free()


## 檢查 explosion_color 係咪仍為 EnemyBase @export 預設值 Color.CYAN。
func _is_default_explosion_color() -> bool:
	return is_equal_approx(explosion_color.r, Color.CYAN.r) \
		and is_equal_approx(explosion_color.g, Color.CYAN.g) \
		and is_equal_approx(explosion_color.b, Color.CYAN.b)


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _find_pattern() -> void:
	_pattern = get_node_or_null("Pattern")
	if _pattern and not _pattern.has_method("fire"):
		_pattern = null
	if not _pattern:
		for c in get_children():
			if c.has_method("fire"):
				_pattern = c
				break


func _physics_process(delta: float) -> void:
	if _death_started:
		return
	if RunState and RunState.gameplay_frozen:
		return
	if not _motion_override and _player and is_instance_valid(_player):
		var dir := (_player.global_position - global_position).normalized()
		var base_vel := dir * move_speed
		var perp := Vector2(-dir.y, dir.x)
		var t := Time.get_ticks_msec() * 0.001
		if dart_amount > 0.0:
			base_vel += perp * dart_amount * sin(t * 8.0)
		if strafe_amount > 0.0:
			base_vel += perp * strafe_amount * sin(t * 4.5)
		velocity = base_vel
		move_and_slide()
	if fire_interval <= 0.0 or not _pattern:
		return
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = fire_interval
		_attack_brighten_until = Time.get_ticks_msec() * 0.001 + 0.18
		var aim_dir: Vector2
		if aim_at_player and _player and is_instance_valid(_player):
			aim_dir = (_player.global_position - global_position).normalized()
		else:
			aim_dir = Vector2.UP
		_pattern.fire(global_position, aim_dir)


func _process(_delta: float) -> void:
	if _death_started:
		return
	if RunState and RunState.gameplay_frozen:
		return
	## 絕對壽命上限：即使 VSN2D 檢測失效（例如 Camera2D 唔存在），亦會兜底回收，防止內存泄漏。
	_alive_time += _delta
	if _alive_time >= max_lifetime:
		_despawn_silently()
		return
	if Engine.get_process_frames() % 2 == 0:
		_update_trail()
	_update_core_visual()


func _update_trail() -> void:
	if trail_length <= 0:
		return
	var trail: Line2D = _cached_trail
	if trail == null or not is_instance_valid(trail):
		return
	_trail_points.append(global_position)
	var max_len := mini(trail_length, TRAIL_MAX)
	while _trail_points.size() > max_len:
		_trail_points.remove_at(0)
	## 性能：set_points 一次性替換，避免 clear_points + 多次 add_point。
	var n: int = _trail_points.size()
	if n == 0:
		trail.clear_points()
		return
	var local_points: PackedVector2Array = PackedVector2Array()
	local_points.resize(n)
	var xform_inv: Transform2D = global_transform.affine_inverse()
	for i in n:
		local_points[i] = xform_inv * _trail_points[i]
	trail.points = local_points


func _update_core_visual() -> void:
	var core: CanvasItem = _cached_core
	if core == null or not is_instance_valid(core):
		return
	var now := Time.get_ticks_msec() * 0.001
	if now < _hit_pulse_until:
		return  # let _pulse_core tween run
	if now < _attack_brighten_until:
		core.modulate = _core_base_modulate * 1.35
	else:
		core.modulate = _core_base_modulate


func take_damage(amount: int) -> void:
	current_hp -= amount
	EventBus.hitstop_requested.emit(0.065, 0.11)
	EventBus.hit_flash_requested.emit(_get_sprite(), 0.09)
	_pulse_core()
	EventBus.screen_shake_requested.emit(0.11, 0.09)
	if current_hp <= 0:
		_die()


func _pulse_core() -> void:
	var core: CanvasItem = _cached_core
	if core == null or not is_instance_valid(core):
		return
	_hit_pulse_until = Time.get_ticks_msec() * 0.001 + 0.1
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(core, "scale", Vector2(1.0, 1.0), 0.08).from(Vector2(1.28, 1.28))
	t.parallel().tween_property(core, "modulate", Color(1, 1, 1, 1), 0.08).from(Color(2.2, 2.2, 2.2, 1))


## 由外部移動控制器（如 TrajectoryMover）呼叫：true 時略過預設 chase 移動，仍保留射擊 AI。
func set_motion_override(enabled: bool) -> void:
	_motion_override = enabled


func apply_stage_scaling(stage_index: int) -> void:
	# Difficulty curve: stage 1 = base; later stages = more HP and speed.
	if stage_index <= 1:
		current_hp = max_hp
		return
	var hp_scale: float = 1.0 + (stage_index - 1) * 0.18
	var speed_scale: float = 1.0 + (stage_index - 1) * 0.08
	max_hp = maxi(1, int(max_hp * hp_scale))
	move_speed *= speed_scale
	current_hp = max_hp


func _get_sprite() -> CanvasItem:
	if _cached_sprite and is_instance_valid(_cached_sprite):
		return _cached_sprite
	return _resolve_sprite()


func _resolve_sprite() -> CanvasItem:
	var n: Node = get_node_or_null("Visual")
	if n is CanvasItem:
		return n as CanvasItem
	n = get_node_or_null("Sprite")
	if n is CanvasItem:
		return n as CanvasItem
	return self


func _die() -> void:
	if _death_started:
		return
	_death_started = true
	collision_layer = 0
	collision_mask = 0
	var core := get_node_or_null("Visual/Core") as Node2D
	if core:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(core, "scale", Vector2.ZERO, 0.06).from(core.scale)
		tween.tween_callback(_finish_death)
	else:
		_finish_death()


func _finish_death() -> void:
	EventBus.enemy_died.emit(self, global_position)
	EventBus.hitstop_requested.emit(0.08, 0.12)
	## 震動按 explosion_scale 縮放：雜兵~0.32、普通~0.38、坦克~0.52；比原本 0.19 更有感。
	## trauma 會喺 CameraShake 內平方（shake = t²）：0.38² × 8px ≈ 1.15 px 峰值；Tank 級約 2.2 px。
	var shake_amp: float = clampf(0.38 * explosion_scale, 0.22, 0.75)
	var shake_dur: float = clampf(0.15 + 0.06 * explosion_scale, 0.14, 0.32)
	EventBus.screen_shake_requested.emit(shake_amp, shake_dur)
	EventBus.sound_kill_requested.emit()
	EventBus.explosion_requested.emit(global_position, explosion_scale, explosion_color)
	died.emit(self, global_position)
	queue_free()
