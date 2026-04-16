extends Node
## Extra atmospheric beauty: drifting nebula, soft star clusters, distant luminous shapes, light dust.
## Subtle, living space. Low opacity; never competes with gameplay. Minimal.

const LAYER_BEAUTY := -201
const BASE_OPACITY := 0.42
const DRIFT_SPEED := 8.0
const SHAPE_COUNT := 4
const DUST_AMOUNT := 24
const DUST_LIFETIME := 12.0
const DUST_SPEED_MIN := 2.0
const DUST_SPEED_MAX := 8.0

var _layer: CanvasLayer
var _content: Node2D
var _nebula: ColorRect
var _star_clusters: ColorRect
var _luminous_shapes: Node2D
var _dust: CPUParticles2D
var _shape_offsets: Array[Vector2] = []
var _shape_angles: Array[float] = []
var _shape_nodes: Array[Polygon2D] = []


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER_BEAUTY
	_layer.name = "AtmosphereBeautyLayer"
	add_child(_layer)
	_content = Node2D.new()
	_content.name = "Content"
	_layer.add_child(_content)
	_build_nebula()
	_build_star_clusters()
	_build_luminous_shapes()
	_build_dust()


func _build_nebula() -> void:
	var mat := load("res://resources/materials/nebula_drift_material.tres") as ShaderMaterial
	if not mat:
		return
	_nebula = ColorRect.new()
	_nebula.name = "Nebula"
	_nebula.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nebula.anchor_left = 0.0
	_nebula.anchor_top = 0.0
	_nebula.anchor_right = 1.0
	_nebula.anchor_bottom = 1.0
	_nebula.offset_left = -150
	_nebula.offset_top = -150
	_nebula.offset_right = 150
	_nebula.offset_bottom = 150
	_nebula.material = mat
	_nebula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nebula.color = Color(0.06, 0.08, 0.14, 0.18)
	_content.add_child(_nebula)


func _build_star_clusters() -> void:
	var mat := load("res://resources/materials/star_clusters_material.tres") as ShaderMaterial
	if not mat:
		return
	_star_clusters = ColorRect.new()
	_star_clusters.name = "StarClusters"
	_star_clusters.set_anchors_preset(Control.PRESET_FULL_RECT)
	_star_clusters.anchor_left = 0.0
	_star_clusters.anchor_top = 0.0
	_star_clusters.anchor_right = 1.0
	_star_clusters.anchor_bottom = 1.0
	_star_clusters.offset_left = -150
	_star_clusters.offset_top = -150
	_star_clusters.offset_right = 150
	_star_clusters.offset_bottom = 150
	_star_clusters.material = mat
	_star_clusters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_clusters.color = Color(0.5, 0.55, 0.7, 0.14)
	_content.add_child(_star_clusters)


func _build_luminous_shapes() -> void:
	_luminous_shapes = Node2D.new()
	_luminous_shapes.name = "LuminousShapes"
	_content.add_child(_luminous_shapes)
	var colors: Array[Color] = [
		Color(0.25, 0.3, 0.55, 0.06),
		Color(0.35, 0.22, 0.5, 0.05),
		Color(0.2, 0.35, 0.5, 0.055),
		Color(0.3, 0.25, 0.45, 0.05),
	]
	for i in SHAPE_COUNT:
		var poly := Polygon2D.new()
		poly.name = "Shape_%d" % i
		var rx := randf_range(180.0, 320.0)
		var ry := randf_range(120.0, 220.0)
		_shape_offsets.append(Vector2(randf_range(-300, 300), randf_range(-200, 200)))
		_shape_angles.append(randf() * TAU)
		var pts: PackedVector2Array = []
		for j in 24:
			var a := TAU * float(j) / 24.0
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		poly.polygon = pts
		poly.color = colors[i % colors.size()]
		poly.z_index = -5
		_luminous_shapes.add_child(poly)
		_shape_nodes.append(poly)


func _build_dust() -> void:
	_dust = CPUParticles2D.new()
	_dust.name = "Dust"
	_dust.amount = DUST_AMOUNT
	_dust.lifetime = DUST_LIFETIME
	_dust.randomness = 0.6
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(700, 450)
	_dust.direction = Vector2(0.3, -0.2).normalized()
	_dust.spread = 180.0
	_dust.initial_velocity_min = DUST_SPEED_MIN
	_dust.initial_velocity_max = DUST_SPEED_MAX
	_dust.scale_amount_min = 0.15
	_dust.scale_amount_max = 0.4
	_dust.color = Color(0.4, 0.45, 0.6, 0.12)
	_dust.z_index = -3
	var add_mat := load("res://resources/materials/additive_material.tres") as Material
	if add_mat:
		_dust.material = add_mat
	_content.add_child(_dust)


func _process(_delta: float) -> void:
	var opacity: float = BASE_OPACITY
	if VisualLayers:
		opacity *= VisualLayers.get_atmosphere_opacity_multiplier()
		opacity *= VisualLayers.get_atmosphere_beat_multiplier()
		if VisualLayers.has_method("get_atmosphere_breath_multiplier"):
			opacity *= VisualLayers.get_atmosphere_breath_multiplier()
	if EmotionFeedback and EmotionFeedback.has_method("get_emotion_breath_intensity"):
		opacity *= EmotionFeedback.get_emotion_breath_intensity()
		if VisualLayers.has_method("get_stage_progression_multiplier"):
			opacity *= VisualLayers.get_stage_progression_multiplier()
		# Focus: center sharp, edges atmospheric (only soften atmosphere, never gameplay)
		var center: Vector2 = VisualLayers.get_focus_center()
		var inner: float = VisualLayers.get_focus_inner_radius()
		var outer: float = VisualLayers.get_focus_outer_radius()
		if _nebula and _nebula.material is ShaderMaterial:
			var mat: ShaderMaterial = _nebula.material as ShaderMaterial
			mat.set_shader_parameter("focus_center", center)
			mat.set_shader_parameter("focus_inner_radius", inner)
			mat.set_shader_parameter("focus_outer_radius", outer)
		if _star_clusters and _star_clusters.material is ShaderMaterial:
			var mat: ShaderMaterial = _star_clusters.material as ShaderMaterial
			mat.set_shader_parameter("focus_center", center)
			mat.set_shader_parameter("focus_inner_radius", inner)
			mat.set_shader_parameter("focus_outer_radius", outer)
	opacity = clampf(opacity, 0.18, 0.55)
	_content.modulate.a = opacity
	# Distant particles shimmer (emotional feedback layer)
	if _dust and EmotionFeedback and EmotionFeedback.has_method("get_emotion_shimmer_strength"):
		var sh: float = EmotionFeedback.get_emotion_shimmer_strength()
		_dust.scale_amount_min = lerpf(0.15, 0.35, sh)
		_dust.scale_amount_max = lerpf(0.4, 0.7, sh)
	var t := Time.get_ticks_msec() * 0.001
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_luminous_shapes.position = vp_size * 0.5
	_dust.position = vp_size * 0.5
	for i in _shape_nodes.size():
		var node: Polygon2D = _shape_nodes[i]
		var off: Vector2 = _shape_offsets[i]
		var angle: float = _shape_angles[i]
		var drift := Vector2(sin(t * 0.08 + float(i)) * DRIFT_SPEED, cos(t * 0.06 + float(i) * 0.7) * DRIFT_SPEED)
		node.position = off + drift
		node.rotation = angle + t * 0.02 * (1.0 if i % 2 == 0 else -1.0)
