extends Node2D
class_name BossBeamBase
## Refraction Examiner attack rule: every attack has (1) telegraph phase, (2) readable direction, (3) dodge window.
## Override _get_beam_duration and _tick_beam. Telegraph always runs first; direction = this node's rotation.

signal telegraph_started
signal beam_fired
signal beam_ended

@export var beam_length: float = 420.0
@export var beam_width: float = 16.0
@export var telegraph_duration: float = 0.6
@export var damage_per_interval: int = 1
@export var damage_interval: float = 0.22
@export var player_group: String = "player"

var _state: String = "idle"  # idle, telegraph, beam
var _timer: float = 0.0
var _damage_timer: float = 0.0
var _line: Line2D
var _glow: Line2D
var _area: Area2D
var _collision: CollisionShape2D
var _telegraph: Node2D

func _ready() -> void:
	_build_visuals()
	_build_area()
	visible = false


func _build_visuals() -> void:
	_glow = Line2D.new()
	_glow.name = "Glow"
	_glow.width = beam_width * 2.2
	_glow.z_index = -1
	_glow.default_color = ArtDirection.BOSS_BEAM_GLOW
	_glow.add_point(Vector2.ZERO)
	_glow.add_point(Vector2(0, -beam_length))
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		_glow.material = mat
	add_child(_glow)
	_line = Line2D.new()
	_line.name = "Line"
	_line.width = beam_width
	_line.default_color = ArtDirection.BOSS_BEAM_CORE
	_line.add_point(Vector2.ZERO)
	_line.add_point(Vector2(0, -beam_length))
	if mat:
		_line.material = mat
	add_child(_line)


func _build_area() -> void:
	_area = Area2D.new()
	_area.name = "BeamArea"
	_area.collision_layer = 0
	_area.collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(beam_width * 2, beam_length)
	shape.size.y = beam_length
	_collision = CollisionShape2D.new()
	_collision.shape = shape
	_collision.position = Vector2(0, -beam_length * 0.5)
	_area.add_child(_collision)
	_area.body_entered.connect(_on_body_entered)
	_area.monitoring = false
	add_child(_area)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(player_group) and body.has_method("take_damage"):
		body.take_damage(damage_per_interval, self)


func start_attack() -> void:
	if not _telegraph:
		_telegraph = get_node_or_null("TelegraphLine")
	_state = "telegraph"
	_timer = telegraph_duration
	visible = true
	if _line:
		_line.visible = false
	_area.monitoring = false
	if _telegraph and _telegraph.has_method("show_telegraph"):
		_telegraph.show_telegraph()
	telegraph_started.emit()


func _process(delta: float) -> void:
	if _state == "idle":
		return
	_timer -= delta
	if _state == "telegraph":
		if _timer <= 0.0:
			_state = "beam"
			_timer = _get_beam_duration()
			_damage_timer = 0.0
			_area.monitoring = true
			if _line:
				_line.visible = true
			if _glow:
				_glow.visible = true
			beam_fired.emit()
		return
	if _state == "beam":
		_damage_timer += delta
		_tick_beam(delta)
		if _damage_timer >= damage_interval:
			_damage_timer = 0.0
			# damage is via area body_entered; could also apply here per-body
		if _timer <= 0.0:
			_state = "idle"
			visible = false
			_area.monitoring = false
			beam_ended.emit()


func _get_beam_duration() -> float:
	return 1.2


func _tick_beam(_delta: float) -> void:
	pass


func set_telegraph_node(telegraph: Node2D) -> void:
	_telegraph = telegraph
