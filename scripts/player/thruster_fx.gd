extends Node2D
## Thruster and cockpit: short bursts on beat and shot (visual rhythm), not constant emission.

@export var thruster_path: NodePath = NodePath("Thruster")
@export var scale_min: float = 0.88
@export var scale_max: float = 1.14
@export var thruster_alpha_min: float = 0.7
@export var thruster_alpha_max: float = 0.96
@export var pulse_decay_duration: float = 0.12

var _thruster: Polygon2D
var _base_scale: Vector2 = Vector2.ONE
var _thruster_base_color: Color
var _cockpit: Polygon2D
var _cockpit_glow: Polygon2D
var _top_edge: Line2D
var _pulse_until: float = 0.0
var _dodge_brighten_until: float = 0.0

const BEAT_PULSE_DURATION := 0.12
const SHOT_PULSE_DURATION := 0.07
const DODGE_BRIGHTEN_DURATION := 0.2
const BEAT_BOOST := 0.06
const DODGE_BOOST := 0.14


func _ready() -> void:
	_thruster = get_node_or_null(thruster_path) as Polygon2D
	if _thruster:
		_base_scale = _thruster.scale
		_thruster_base_color = _thruster.color
	_cockpit = get_node_or_null("Cockpit") as Polygon2D
	_cockpit_glow = get_node_or_null("CockpitGlow") as Polygon2D
	_top_edge = get_node_or_null("TopEdge") as Line2D
	var body_outline: Line2D = get_node_or_null("BodyOutline") as Line2D
	if body_outline:
		body_outline.default_color = Color(0.45, 0.85, 1.2, 0.9)
	if _cockpit:
		_cockpit.color = ArtDirection.TIER1_PLAYER_CORE
	if _cockpit_glow:
		_cockpit_glow.color = ArtDirection.TIER1_COCKPIT_GLOW
		_cockpit_glow.color.a = 0.62
	if _top_edge:
		_top_edge.default_color = ArtDirection.TIER1_COCKPIT_GLOW
		_top_edge.default_color.a = 0.88
	var parts: CPUParticles2D = get_node_or_null("ThrusterParticles") as CPUParticles2D
	if parts:
		parts.color = ArtDirection.PARTICLE_THRUSTER
	var bc := get_node_or_null("/root/BeatConductor")
	if bc and bc.has_signal("beat_pulse"):
		bc.beat_pulse.connect(_on_beat_pulse)
	EventBus.near_dodge_feedback.connect(_on_near_dodge)
	if EventBus.bullet_spawn_requested.is_connected(_on_shot) == false:
		EventBus.bullet_spawn_requested.connect(_on_shot)


func _on_beat_pulse() -> void:
	var now := Time.get_ticks_msec() * 0.001
	_pulse_until = maxf(_pulse_until, now + BEAT_PULSE_DURATION)


func _on_shot(_pos: Vector2, _dir: Vector2, _speed: float, _damage: int, is_player: bool, _weapon_id: String) -> void:
	if not is_player:
		return
	var now := Time.get_ticks_msec() * 0.001
	_pulse_until = maxf(_pulse_until, now + SHOT_PULSE_DURATION)


func _on_near_dodge() -> void:
	_dodge_brighten_until = Time.get_ticks_msec() * 0.001 + DODGE_BRIGHTEN_DURATION


func _process(_delta: float) -> void:
	if not _thruster:
		return
	var now := Time.get_ticks_msec() * 0.001
	var pulse_ratio: float = 0.0
	if now < _pulse_until:
		pulse_ratio = clampf((_pulse_until - now) / pulse_decay_duration, 0.0, 1.0)
	var s := lerpf(scale_min, scale_max, pulse_ratio)
	_thruster.scale = _base_scale * s
	var alpha_t := lerpf(thruster_alpha_min, thruster_alpha_max, pulse_ratio)
	_thruster.color = Color(_thruster_base_color.r, _thruster_base_color.g, _thruster_base_color.b, alpha_t)
	var boost := 0.0
	if now < _pulse_until:
		boost += BEAT_BOOST
	if now < _dodge_brighten_until:
		boost += DODGE_BOOST
	var mod := Color(1.0 + boost, 1.0 + boost, 1.0 + boost, 1.0)
	if _cockpit:
		_cockpit.modulate = mod
	if _cockpit_glow:
		_cockpit_glow.modulate = mod
