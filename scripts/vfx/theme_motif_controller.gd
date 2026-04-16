extends Node
## Per-theme motif overlays: SPACE=planets, TIME_FIELD=grid/scanline, VOID_FRACTURE=shards, ORBITAL_CORE=rings.
## Procedural only; opacity scales down with combat density for bullet readability. No edge artifacts.

const LAYER_MOTIF := -199
const BASE_ALPHA := 0.08
const PLANET_PARALLAX := 0.03
const PLANET_COUNT := 4
const SHARD_COUNT := 6
const RING_COUNT := 2

var _layer: CanvasLayer
var _motifs: Array[CanvasItem] = []  # [Space, TimeField, Void, Orbital]
var _camera: Camera2D
var _bullet_pool: Node
var _planet_bases: Array[Vector2] = []
var _planet_radii: Array[float] = []
var _planet_polys: Array[Polygon2D] = []
var _shard_polys: Array[Polygon2D] = []
var _shard_offsets: Array[Vector2] = []
var _ring_nodes: Array[Node2D] = []
var _time_field_rect: ColorRect


func _ready() -> void:
	_camera = get_viewport().get_camera_2d()
	_bullet_pool = get_tree().get_first_node_in_group("bullet_pool")
	if _bullet_pool == null:
		_bullet_pool = get_parent().get_node_or_null("World/BulletPool")
	_layer = CanvasLayer.new()
	_layer.layer = LAYER_MOTIF
	_layer.name = "MotifLayer"
	add_child(_layer)
	_build_space_motif()
	_build_time_field_motif()
	_build_void_motif()
	_build_orbital_motif()
	for m in _motifs:
		m.visible = false
	if ThemeManager:
		ThemeManager.theme_changed.connect(_on_theme_changed)
		_show_motif_for_theme(ThemeManager.current_theme)
	call_deferred("_ensure_no_edge_artifacts")


func _ensure_no_edge_artifacts() -> void:
	# Keep motif layer behind game (z already by layer); ensure full coverage where used
	if _time_field_rect:
		_time_field_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_time_field_rect.offset_left = -50
		_time_field_rect.offset_top = -50
		_time_field_rect.offset_right = 50
		_time_field_rect.offset_bottom = 50


func _build_space_motif() -> void:
	var root := Node2D.new()
	root.name = "SpaceMotif"
	_layer.add_child(root)
	_motifs.append(root)
	var colors: Array[Color] = [
		Color(0.4, 0.5, 0.9, 0.12),
		Color(0.6, 0.4, 0.7, 0.1),
		Color(0.3, 0.7, 0.8, 0.08),
		Color(0.8, 0.5, 0.4, 0.07),
	]
	for i in PLANET_COUNT:
		var base_pos := Vector2(randf_range(-400, 1200), randf_range(-200, 800))
		var radius := randf_range(140.0, 220.0)
		_planet_bases.append(base_pos)
		_planet_radii.append(radius)
		var poly := Polygon2D.new()
		poly.name = "Planet_%d" % i
		var pts: PackedVector2Array = []
		for j in 32:
			pts.append(base_pos + Vector2.from_angle(TAU * float(j) / 32.0) * radius)
		poly.polygon = pts
		poly.color = colors[i % colors.size()]
		poly.z_index = -20
		root.add_child(poly)
		_planet_polys.append(poly)


func _build_time_field_motif() -> void:
	var shader := load("res://resources/shaders/motif_grid_scanline.gdshader") as Shader
	if not shader:
		var root := ColorRect.new()
		root.name = "TimeFieldMotif"
		root.color = Color(0.2, 0.18, 0.3, 0.04)
		_layer.add_child(root)
		_motifs.append(root)
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("line_color", Color(0.35, 0.3, 0.5, 0.06))
	_time_field_rect = ColorRect.new()
	_time_field_rect.name = "TimeFieldMotif"
	_time_field_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_time_field_rect.anchor_left = 0.0
	_time_field_rect.anchor_top = 0.0
	_time_field_rect.anchor_right = 1.0
	_time_field_rect.anchor_bottom = 1.0
	_time_field_rect.offset_left = -100
	_time_field_rect.offset_top = -100
	_time_field_rect.offset_right = 100
	_time_field_rect.offset_bottom = 100
	_time_field_rect.material = mat
	_time_field_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_time_field_rect)
	_motifs.append(_time_field_rect)


func _build_void_motif() -> void:
	var root := Node2D.new()
	root.name = "VoidMotif"
	_layer.add_child(root)
	_motifs.append(root)
	for i in SHARD_COUNT:
		var poly := Polygon2D.new()
		poly.name = "Shard_%d" % i
		var base := Vector2(randf_range(100, 1100), randf_range(50, 700))
		_shard_offsets.append(base)
		var size := randf_range(25, 55)
		var angle := randf() * TAU
		poly.polygon = PackedVector2Array([
			base + Vector2.from_angle(angle) * size,
			base + Vector2.from_angle(angle + 2.1) * size,
			base + Vector2.from_angle(angle + 4.2) * size,
		])
		poly.color = Color(0.08, 0.12, 0.22, 0.12)
		poly.z_index = -10
		root.add_child(poly)
		_shard_polys.append(poly)


func _build_orbital_motif() -> void:
	var root := Node2D.new()
	root.name = "OrbitalMotif"
	root.position = Vector2(576, 324)
	_layer.add_child(root)
	_motifs.append(root)
	for i in RING_COUNT:
		var ring := Node2D.new()
		ring.name = "Ring_%d" % i
		ring.position = Vector2(randf_range(-200, 200), randf_range(-150, 150))
		root.add_child(ring)
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.7, 0.5, 0.3, 0.08)
		var radius := 120.0 + i * 80.0
		var pts: PackedVector2Array = []
		for j in range(33):
			var a := (float(j) / 32.0) * TAU * 0.7
			pts.append(Vector2.from_angle(a) * radius)
		line.points = pts
		ring.add_child(line)
		_ring_nodes.append(ring)


func _on_theme_changed(theme_id: int, _duration: float) -> void:
	_show_motif_for_theme(theme_id)


func _show_motif_for_theme(theme_id: int) -> void:
	for i in _motifs.size():
		_motifs[i].visible = (i == theme_id)


func _process(delta: float) -> void:
	if ThemeManager == null:
		return
	var count := 0
	if _bullet_pool and _bullet_pool.has_method("get_active_count"):
		count = _bullet_pool.get_active_count()
	ThemeManager.set_combat_density_from_bullet_count(count)
	var mult: float = ThemeManager.get_motif_opacity_multiplier()
	var beat_mult: float = VisualLayers.get_atmosphere_beat_multiplier() if VisualLayers else 1.0
	var breath_mult: float = VisualLayers.get_atmosphere_breath_multiplier() if VisualLayers else 1.0
	var stage_mult: float = VisualLayers.get_stage_progression_multiplier() if VisualLayers else 1.0
	var alpha: float = BASE_ALPHA * mult * beat_mult * breath_mult * stage_mult
	for m in _motifs:
		if not m.visible:
			continue
		m.modulate.a = alpha
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	var cam_pos: Vector2 = _camera.global_position if _camera else Vector2.ZERO
	# SPACE: slow parallax on planets (update polygon centers)
	if _motifs.size() > 0 and _motifs[0].visible and _planet_polys.size() > 0:
		for i in _planet_polys.size():
			var base_pos: Vector2 = _planet_bases[i]
			var radius: float = _planet_radii[i]
			var center: Vector2 = base_pos + cam_pos * PLANET_PARALLAX * (0.8 + sin(float(i)) * 0.2)
			var pts: PackedVector2Array = []
			for j in 32:
				pts.append(center + Vector2.from_angle(TAU * float(j) / 32.0) * radius)
			_planet_polys[i].polygon = pts
	# VOID: gentle drift
	for i in _shard_polys.size():
		var poly: Polygon2D = _shard_polys[i]
		var off: Vector2 = _shard_offsets[i]
		var t: float = Time.get_ticks_msec() * 0.001
		var drift := Vector2(sin(t * 0.5 + float(i)) * 12.0, cos(t * 0.4 + float(i) * 0.7) * 10.0)
		var size := 30.0
		var angle := t * 0.15 + float(i)
		poly.polygon = PackedVector2Array([
			off + drift + Vector2.from_angle(angle) * size,
			off + drift + Vector2.from_angle(angle + 2.1) * size,
			off + drift + Vector2.from_angle(angle + 4.2) * size,
		])
	# ORBITAL: rotate rings
	for ring in _ring_nodes:
		ring.rotation += delta * 0.12
