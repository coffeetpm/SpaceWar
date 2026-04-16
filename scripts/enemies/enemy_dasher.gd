extends CharacterBody2D
class_name EnemyDasher
## Dasher: telegraphs briefly then dashes toward player. Chaser variant with burst movement.

signal died(enemy: Node, at_position: Vector2)

@export var max_hp: int = 2
@export var approach_speed: float = 55.0
@export var dash_speed: float = 420.0
@export var telegraph_duration: float = 0.55
@export var dash_duration: float = 0.22
@export var cooldown_after_dash: float = 0.9
@export var damage_on_contact: int = 1
@export var explosion_scale: float = 0.85
@export var explosion_color: Color = Color.ORANGE
@export var currency_drop: int = 1

enum State { APPROACH, TELEGRAPH, DASH, COOLDOWN }

var current_hp: int
var _player: Node2D
var _state: State = State.APPROACH
var _state_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.UP
var _death_started: bool = false
var _telegraph_line: Line2D
var _core_base_modulate: Color = Color(1, 1, 1, 1)


func _ready() -> void:
	add_to_group("enemy")
	current_hp = max_hp
	_player = get_tree().get_first_node_in_group("player") as Node2D
	var core := get_node_or_null("Visual/Core") as CanvasItem
	if core:
		_core_base_modulate = core.modulate
	_build_telegraph_visual()


func _build_telegraph_visual() -> void:
	_telegraph_line = Line2D.new()
	_telegraph_line.name = "TelegraphLine"
	_telegraph_line.width = 3.0
	_telegraph_line.default_color = Color(1.0, 0.5, 0.2, 0.0)
	_telegraph_line.z_index = 1
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		_telegraph_line.material = mat
	var vis: Node2D = get_node_or_null("Visual") as Node2D
	if vis:
		vis.add_child(_telegraph_line)
	else:
		add_child(_telegraph_line)


func apply_stage_scaling(stage_index: int) -> void:
	var hp_scale: float = 1.0
	var speed_scale: float = 1.0
	if stage_index <= 1:
		hp_scale = 0.9
	elif stage_index <= 3:
		hp_scale = 1.0 + (stage_index - 1) * 0.12
	else:
		hp_scale = 1.0 + (stage_index - 1) * 0.15
	if stage_index > 1:
		speed_scale = 1.0 + (stage_index - 1) * 0.06
	max_hp = maxi(1, int(max_hp * hp_scale))
	approach_speed *= speed_scale
	dash_speed *= speed_scale
	current_hp = max_hp


func _physics_process(delta: float) -> void:
	if _death_started or (RunState and RunState.gameplay_frozen):
		return
	if not _player or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_state_timer -= delta
	match _state:
		State.APPROACH:
			var dir := (_player.global_position - global_position).normalized()
			velocity = dir * approach_speed
			move_and_slide()
			_update_telegraph(false, Vector2.ZERO)
			if _state_timer <= 0.0:
				_dash_direction = (_player.global_position - global_position).normalized()
				if _dash_direction.length_squared() < 0.01:
					_dash_direction = Vector2.UP
				_state = State.TELEGRAPH
				_state_timer = telegraph_duration
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			move_and_slide()
			_update_telegraph(true, _dash_direction)
			if _state_timer <= 0.0:
				_state = State.DASH
				_state_timer = dash_duration
		State.DASH:
			velocity = _dash_direction * dash_speed
			move_and_slide()
			_update_telegraph(false, Vector2.ZERO)
			if _state_timer <= 0.0:
				_state = State.COOLDOWN
				_state_timer = cooldown_after_dash
		State.COOLDOWN:
			velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
			move_and_slide()
			_update_telegraph(false, Vector2.ZERO)
			if _state_timer <= 0.0:
				_state = State.APPROACH
				_state_timer = 0.8 + randf() * 0.4


func _update_telegraph(active: bool, direction: Vector2) -> void:
	if not _telegraph_line:
		return
	if not active:
		_telegraph_line.default_color.a = 0.0
		_telegraph_line.clear_points()
		return
	var len := 80.0
	var tip := direction * len
	_telegraph_line.clear_points()
	_telegraph_line.add_point(Vector2.ZERO)
	_telegraph_line.add_point(tip)
	_telegraph_line.default_color = Color(1.0, 0.5, 0.2, 0.5)


func _process(_delta: float) -> void:
	if _death_started:
		return
	var core := get_node_or_null("Visual/Core") as CanvasItem
	if core and _state == State.TELEGRAPH:
		core.modulate = _core_base_modulate * 1.4
	elif core:
		core.modulate = _core_base_modulate


func take_damage(amount: int) -> void:
	current_hp -= amount
	EventBus.hitstop_requested.emit(0.065, 0.11)
	EventBus.hit_flash_requested.emit(_get_sprite(), 0.09)
	EventBus.screen_shake_requested.emit(0.11, 0.09)
	if current_hp <= 0:
		_die()


func _get_sprite() -> CanvasItem:
	var n := get_node_or_null("Visual")
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
