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

func _ready() -> void:
	add_to_group("enemy")
	current_hp = max_hp
	_find_player()
	# apply_stage_scaling() may be called by spawner after this to reduce HP for early stages
	_find_pattern()
	if fire_interval > 0.0:
		_shoot_timer = fire_interval * 0.5  # 首發延遲
	var core := get_node_or_null("Visual/Core") as CanvasItem
	if core:
		_core_base_modulate = core.modulate


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
	if _player and is_instance_valid(_player):
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
	if Engine.get_process_frames() % 2 == 0:
		_update_trail()
	_update_core_visual()


func _update_trail() -> void:
	if trail_length <= 0:
		return
	var trail: Line2D = get_node_or_null("Visual/Trail") as Line2D
	if not trail:
		return
	_trail_points.append(global_position)
	var max_len := mini(trail_length, TRAIL_MAX)
	while _trail_points.size() > max_len:
		_trail_points.remove_at(0)
	trail.clear_points()
	for p in _trail_points:
		trail.add_point(to_local(p))


func _update_core_visual() -> void:
	var core := get_node_or_null("Visual/Core") as CanvasItem
	if not core:
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
	var core := get_node_or_null("Visual/Core") as CanvasItem
	if not core:
		return
	_hit_pulse_until = Time.get_ticks_msec() * 0.001 + 0.1
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(core, "scale", Vector2(1.0, 1.0), 0.08).from(Vector2(1.28, 1.28))
	t.parallel().tween_property(core, "modulate", Color(1, 1, 1, 1), 0.08).from(Color(2.2, 2.2, 2.2, 1))


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
	var n := get_node_or_null("Visual")
	if n is CanvasItem:
		return n as CanvasItem
	n = get_node_or_null("Sprite")
	if n is CanvasItem:
		return n as CanvasItem
	return self


func _die() -> void:
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
	EventBus.screen_shake_requested.emit(0.19, 0.14)
	EventBus.sound_kill_requested.emit()
	EventBus.explosion_requested.emit(global_position, explosion_scale, explosion_color)
	died.emit(self, global_position)
	queue_free()
