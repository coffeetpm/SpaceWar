extends Area2D
class_name OrbitDrone
## One drone orbiting the player; contact damage. Visual: orbit motion, small glow.

@export var orbit_radius: float = 58.0
@export var orbit_speed: float = 2.6
@export var contact_damage: int = 2
## For synergy triggers (orbit_tick).
var weapon_tags: Array[String] = ["drone", "orbit"]
## Orbit speed scales with player movement (0.6 when still, up to 1.4 when fast).
const SPEED_SCALE_STILL := 0.6
const SPEED_SCALE_FAST := 1.4
const PLAYER_SPEED_REF := 380.0
const TRAIL_LENGTH := 16
const TRAIL_WIDTH := 4.0

var _angle: float = 0.0
var _player: Node2D
var _trail: Line2D
var _trail_points: Array[Vector2] = []


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	body_entered.connect(_on_body_entered)
	_build_orbit_trail()


func _build_orbit_trail() -> void:
	_trail = Line2D.new()
	_trail.name = "Trail"
	_trail.width = TRAIL_WIDTH
	_trail.z_index = -1
	_trail.default_color = Color(ArtDirection.TIER2_BULLET_GLOW_PLAYER.r, ArtDirection.TIER2_BULLET_GLOW_PLAYER.g, ArtDirection.TIER2_BULLET_GLOW_PLAYER.b, 0.6)
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		_trail.material = mat
	add_child(_trail)


func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var speed_mult: float = SPEED_SCALE_STILL
	if _player is CharacterBody2D:
		var vel: float = (_player as CharacterBody2D).velocity.length()
		speed_mult = lerpf(SPEED_SCALE_STILL, SPEED_SCALE_FAST, clampf(vel / PLAYER_SPEED_REF, 0.0, 1.0))
	_angle += orbit_speed * speed_mult * delta
	var offset := Vector2(cos(_angle), sin(_angle)) * orbit_radius
	global_position = _player.global_position + offset
	# Light Language: orbit trails that oscillate (pulse on trail alpha, never constant)
	_update_trail()
	if _trail and LightLanguage:
		var t := Time.get_ticks_msec() * 0.001
		var speed: float = LightLanguage.get_orbit_oscillate_speed("drones")
		var lo: float = LightLanguage.get_orbit_trail_alpha_min("drones")
		var hi: float = LightLanguage.get_orbit_trail_alpha_max("drones")
		var osc: float = lo + (hi - lo) * (sin(t * speed) * 0.5 + 0.5)
		var c: Color = _trail.default_color
		_trail.default_color = Color(c.r, c.g, c.b, osc * 0.7)


func _update_trail() -> void:
	if not _trail:
		return
	_trail_points.append(global_position)
	while _trail_points.size() > TRAIL_LENGTH:
		_trail_points.remove_at(0)
	_trail.clear_points()
	for p in _trail_points:
		_trail.add_point(to_local(p))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		var dmg: int = contact_damage
		if RunState:
			dmg = int(dmg * RunState.get_ignition_damage_mult())
		body.take_damage(dmg)
		if EventBus.has_signal("player_projectile_impact"):
			EventBus.player_projectile_impact.emit(body.global_position, dmg)
	if SynergyManager:
		SynergyManager.fire_trigger("orbit_tick", {
			"position": global_position,
			"damage": contact_damage,
			"weapon_tags": weapon_tags,
		})


func set_contact_damage(d: int) -> void:
	contact_damage = d
