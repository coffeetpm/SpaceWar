extends Node2D
class_name WeaponBeam
## Solid light beam: damages enemies in line. Pulsed by BeamWeapon for timing/identity.
## Supports brief lock-on telegraph (precise feel) before firing.

@export var length: float = 420.0
@export var width: float = 14.0
@export var pulse_duration: float = 0.14
@export var damage_per_pulse: int = 3
@export var telegraph_duration: float = 0.12

## Refraction Duplication (meta): secondary beam at angle; visual + 50% damage. Readable, no clutter.
const REFRACTION_ANGLE_RAD := 0.2
const REFRACTION_ECHO_DAMAGE_SCALE := 0.5

var _pulse_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _damaged_this_pulse: bool = false
var _refraction_damaged_this_pulse: bool = false
var _area: Area2D
var _line: Line2D
var _glow: Line2D
var _telegraph_line: Line2D
var _telegraph_glow: Line2D
var _refraction_visual: Node2D = null  # child with rotation; holds line + glow
var _refraction_area: Area2D = null


func _ready() -> void:
	visible = false
	_draw_beam_visual()
	_find_area()
	_build_refraction()


func _find_area() -> void:
	_area = get_node_or_null("BeamArea") as Area2D
	if _area:
		_area.body_entered.connect(_on_body_entered)
		_area.monitoring = false
		_area.monitorable = false


func _draw_beam_visual() -> void:
	_line = get_node_or_null("Line") as Line2D
	if not _line:
		_line = Line2D.new()
		_line.name = "Line"
		_line.width = width
		_line.default_color = ArtDirection.TIER2_BULLET_CORE_PLAYER
		_line.add_point(Vector2.ZERO)
		_line.add_point(Vector2(0, -length))
		var mat := load("res://resources/materials/additive_material.tres") as Material
		if mat:
			_line.material = mat
		add_child(_line)
	_glow = get_node_or_null("Glow") as Line2D
	if not _glow:
		_glow = Line2D.new()
		_glow.name = "Glow"
		_glow.width = width * 1.4
		_glow.z_index = -1
		_glow.default_color = Color(ArtDirection.TIER2_BULLET_GLOW_PLAYER.r, ArtDirection.TIER2_BULLET_GLOW_PLAYER.g, ArtDirection.TIER2_BULLET_GLOW_PLAYER.b, 0.55)
		_glow.add_point(Vector2.ZERO)
		_glow.add_point(Vector2(0, -length))
		var mat := load("res://resources/materials/additive_material.tres") as Material
		if mat:
			_glow.material = mat
		add_child(_glow)
	# Lock-on telegraph: thin line, dim
	_telegraph_line = Line2D.new()
	_telegraph_line.name = "TelegraphLine"
	_telegraph_line.width = width * 0.35
	_telegraph_line.default_color = Color(0.4, 0.85, 1.0, 0.35)
	_telegraph_line.add_point(Vector2.ZERO)
	_telegraph_line.add_point(Vector2(0, -length))
	var tmat := load("res://resources/materials/additive_material.tres") as Material
	if tmat:
		_telegraph_line.material = tmat
	add_child(_telegraph_line)
	_telegraph_glow = Line2D.new()
	_telegraph_glow.name = "TelegraphGlow"
	_telegraph_glow.width = width * 0.8
	_telegraph_glow.z_index = -2
	_telegraph_glow.default_color = Color(0.3, 0.7, 0.95, 0.2)
	_telegraph_glow.add_point(Vector2.ZERO)
	_telegraph_glow.add_point(Vector2(0, -length))
	if tmat:
		_telegraph_glow.material = tmat
	add_child(_telegraph_glow)
	_telegraph_line.visible = false
	_telegraph_glow.visible = false


func _build_refraction() -> void:
	if not SaveManager or not SaveManager.is_refraction_unlocked():
		return
	_refraction_visual = Node2D.new()
	_refraction_visual.name = "RefractionVisual"
	_refraction_visual.rotation = REFRACTION_ANGLE_RAD
	add_child(_refraction_visual)
	var r_line := Line2D.new()
	r_line.width = width * 0.7
	r_line.default_color = Color(ArtDirection.TIER2_BULLET_CORE_PLAYER.r, ArtDirection.TIER2_BULLET_CORE_PLAYER.g, ArtDirection.TIER2_BULLET_CORE_PLAYER.b, 0.42)
	r_line.add_point(Vector2.ZERO)
	r_line.add_point(Vector2(0, -length))
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		r_line.material = mat
	_refraction_visual.add_child(r_line)
	var r_glow := Line2D.new()
	r_glow.width = width * 1.0
	r_glow.z_index = -1
	r_glow.default_color = Color(ArtDirection.TIER2_BULLET_GLOW_PLAYER.r, ArtDirection.TIER2_BULLET_GLOW_PLAYER.g, ArtDirection.TIER2_BULLET_GLOW_PLAYER.b, 0.28)
	r_glow.add_point(Vector2.ZERO)
	r_glow.add_point(Vector2(0, -length))
	if mat:
		r_glow.material = mat
	_refraction_visual.add_child(r_glow)
	_refraction_visual.visible = false
	# Refraction area: same shape as beam, rotated
	_refraction_area = Area2D.new()
	_refraction_area.name = "RefractionArea"
	_refraction_area.collision_layer = 0
	_refraction_area.collision_mask = 4
	_refraction_area.position = Vector2(0, -length * 0.5)
	_refraction_area.rotation = REFRACTION_ANGLE_RAD
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, length)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	_refraction_area.add_child(cs)
	add_child(_refraction_area)
	_refraction_area.monitoring = false
	_refraction_area.monitorable = false


## Start lock-on telegraph; call pulse() after telegraph_duration to fire.
func start_telegraph() -> void:
	visible = true
	_telegraph_timer = telegraph_duration
	if _telegraph_line:
		_telegraph_line.visible = true
	if _telegraph_glow:
		_telegraph_glow.visible = true
	if _line:
		_line.visible = false
	if _glow:
		_glow.visible = false


func pulse() -> void:
	_telegraph_timer = 0.0
	if _telegraph_line:
		_telegraph_line.visible = false
	if _telegraph_glow:
		_telegraph_glow.visible = false
	visible = true
	_line.visible = true
	_glow.visible = true
	_pulse_timer = pulse_duration
	_damaged_this_pulse = false
	_refraction_damaged_this_pulse = false
	if _area:
		_area.monitoring = true
	if _refraction_visual:
		_refraction_visual.visible = true
	if _refraction_area:
		_refraction_area.monitoring = true


func _process(delta: float) -> void:
	if _telegraph_timer > 0.0:
		_telegraph_timer -= delta
		return
	if _pulse_timer <= 0.0:
		return
	if not _damaged_this_pulse and _area:
		_damaged_this_pulse = true
		var dmg: int = damage_per_pulse
		if RunState:
			dmg = int(dmg * RunState.get_ignition_damage_mult())
		for body in _area.get_overlapping_bodies():
			if body.is_in_group("enemy") and body.has_method("take_damage"):
				body.take_damage(dmg)
		for area in _area.get_overlapping_areas():
			_damage_boss_area(area, dmg)
		if EventBus.has_signal("player_projectile_impact"):
			var tip: Vector2 = global_position + global_transform * Vector2(0, -length)
			EventBus.player_projectile_impact.emit(tip, dmg)
	if not _refraction_damaged_this_pulse and _refraction_area:
		_refraction_damaged_this_pulse = true
		var ref_dmg: int = maxi(1, int(float(damage_per_pulse) * REFRACTION_ECHO_DAMAGE_SCALE))
		if RunState:
			ref_dmg = int(ref_dmg * RunState.get_ignition_damage_mult())
		for body in _refraction_area.get_overlapping_bodies():
			if body.is_in_group("enemy") and body.has_method("take_damage"):
				body.take_damage(ref_dmg)
		for area in _refraction_area.get_overlapping_areas():
			_damage_boss_area(area, ref_dmg)
		if SynergyManager:
			var weapon_tags: Array[String] = (get_parent() as RunWeaponBase).get_weapon_tags() if get_parent() is RunWeaponBase else []
			var dir := -global_transform.y.normalized()
			SynergyManager.fire_trigger("pierce_pulse", {
				"position": global_position,
				"direction": dir,
				"damage": damage_per_pulse,
				"speed": 400.0,
				"weapon_tags": weapon_tags,
			})
	_pulse_timer -= delta
	# Light Language: continuous but breathing intensity (never constant glow)
	if _glow and LightLanguage:
		var breath_speed: float = LightLanguage.get_beam_breath_speed("beam")
		var lo: float = LightLanguage.get_beam_breath_min("beam")
		var hi: float = LightLanguage.get_beam_breath_max("beam")
		var breath: float = lo + (hi - lo) * (sin(Time.get_ticks_msec() * 0.001 * breath_speed) * 0.5 + 0.5)
		var c: Color = _glow.default_color
		const BASE_GLOW_ALPHA := 0.6
		_glow.default_color = Color(c.r, c.g, c.b, BASE_GLOW_ALPHA * breath)
	if _pulse_timer <= 0.0:
		_spawn_signature_beam_moment()
		visible = false
		_line.visible = false
		_glow.visible = false
		if _refraction_visual:
			_refraction_visual.visible = false
		if _refraction_area:
			_refraction_area.monitoring = false
		if _area:
			_area.monitoring = false


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		var dmg: int = damage_per_pulse
		if RunState:
			dmg = int(dmg * RunState.get_ignition_damage_mult())
		body.take_damage(dmg)


## Boss 採用 Area2D hitbox（非 PhysicsBody），需另向上找最近的 boss 節點。
## 支援 NeonTitan 的弱點：弱點 Area 本身實作 take_damage 時直接呼叫。
func _damage_boss_area(area: Area2D, dmg: int) -> void:
	if area == null or not is_instance_valid(area):
		return
	if area.is_in_group("boss") and area.has_method("take_damage"):
		area.take_damage(dmg)
		return
	var p: Node = area.get_parent()
	while p and not (p.is_in_group("boss") and p.has_method("take_damage")):
		p = p.get_parent()
	if p:
		p.take_damage(dmg)


func set_damage(d: int) -> void:
	damage_per_pulse = d


## Signature moment: refraction trail (slice in space) + clean impact at beam tip. Technological, precise.
func _spawn_signature_beam_moment() -> void:
	var tip_global: Vector2 = global_position + global_transform * Vector2(0, -length)
	var scene := get_tree().current_scene
	if not scene:
		return
	# Refraction trail: space left behind the beam, fades to normal
	var trail_node := Node2D.new()
	trail_node.global_position = global_position
	trail_node.global_rotation = global_rotation
	var trail := Line2D.new()
	trail.width = 4.0
	trail.default_color = Color(0.35, 0.82, 1.0, 0.38)
	trail.add_point(Vector2.ZERO)
	trail.add_point(Vector2(0, -length))
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		trail.material = mat
	trail_node.add_child(trail)
	scene.add_child(trail_node)
	var t_trail := trail_node.create_tween()
	t_trail.tween_property(trail, "default_color:a", 0.0, 0.35)
	t_trail.tween_callback(func() -> void: trail_node.queue_free())
	# Clean energy fracture + light shards at tip
	var impact := Node2D.new()
	impact.set_script(load("res://scripts/vfx/beam_impact_vfx.gd") as GDScript)
	impact.global_position = tip_global
	scene.add_child(impact)


## Evolution feedback: one-shot stability flicker when first synergy triggers (beam feels less stable for a moment).
func play_stability_flicker() -> void:
	if not _line or not _glow:
		return
	var was_visible: bool = visible
	var was_line: bool = _line.visible
	var was_glow: bool = _glow.visible
	visible = true
	_line.visible = true
	_glow.visible = true
	modulate.a = 0.45
	scale = Vector2(0.88, 0.88)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
	t.tween_callback(func() -> void:
		if not was_visible:
			visible = false
		_line.visible = was_line
		_glow.visible = was_glow
	)
