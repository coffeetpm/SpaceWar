extends Area2D
class_name CurrencyPickup
## Energy XP drop (EXP). Magnet pickup: large attract radius, accelerates toward player, light trail.
## Drops = EXP; collecting fills level bar; level-up freezes world and shows 3 upgrade choices.

## Base radius before 3x multiplier. Final base = BASE * ATTRACT_RADIUS_MULTIPLIER.
const BASE_ATTRACT_RADIUS := 85.0
const ATTRACT_RADIUS_MULTIPLIER := 3.0
const BASE_ATTRACT_SPEED := 180.0
## Speed scales up as pickup gets closer (smoother, more rewarding).
const ATTRACT_ACCEL_FACTOR := 2.2
@export var collect_radius: float = 18.0

const TRAIL_POINTS := 10
const TRAIL_UPDATE_INTERVAL := 2
const TRAIL_WIDTH := 2.0
const TRAIL_COLOR := Color(1.0, 0.9, 0.5, 0.35)

@export var value: int = 1

var _player: Node2D
var _attract_radius: float = 0.0
var _trail_positions: PackedVector2Array = []
var _trail_line: Line2D
var _trail_tick: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_attract_radius = BASE_ATTRACT_RADIUS * ATTRACT_RADIUS_MULTIPLIER
	if SaveManager and SaveManager.has_method("get_magnet_radius_bonus"):
		_attract_radius += SaveManager.get_magnet_radius_bonus()
	_build_trail()
	if RunState and RunState.is_opening_phase():
		var vis: Node2D = get_node_or_null("Visual") as Node2D
		if vis:
			vis.scale = Vector2(RunState.opening_visual_scale, RunState.opening_visual_scale)


func _build_trail() -> void:
	_trail_line = Line2D.new()
	_trail_line.name = "Trail"
	_trail_line.width = TRAIL_WIDTH
	_trail_line.default_color = TRAIL_COLOR
	_trail_line.z_index = -1
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		_trail_line.material = mat
	add_child(_trail_line)


func set_value(v: int) -> void:
	value = maxi(1, v)


func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var to_player := _player.global_position - global_position
	var d := to_player.length()
	if d <= collect_radius:
		_collect()
		return
	if d <= _attract_radius and d > 0.0:
		var dir := to_player.normalized()
		var t := 1.0 - (d / _attract_radius)
		var speed := BASE_ATTRACT_SPEED * (1.0 + ATTRACT_ACCEL_FACTOR * t)
		global_position += dir * speed * delta
	_update_trail()


func _update_trail() -> void:
	_trail_tick += 1
	if _trail_tick % TRAIL_UPDATE_INTERVAL != 0:
		return
	if not _trail_line:
		return
	var local_origin := Vector2.ZERO
	_trail_positions.insert(0, local_origin)
	while _trail_positions.size() > TRAIL_POINTS:
		_trail_positions.remove_at(_trail_positions.size() - 1)
	_trail_line.clear_points()
	for i in _trail_positions.size():
		_trail_line.add_point(_trail_positions[i])


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()


func _collect() -> void:
	EventBus.exp_collected.emit(value)
	queue_free()
