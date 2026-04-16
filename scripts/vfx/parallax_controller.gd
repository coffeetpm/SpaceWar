extends Node
## Drives procedural parallax layers with camera position for infinite-feel world.
## Layer 1: distant stars. Layer 2: mid dust/nebula. Layer 3: slow color fog.

@export var layer_stars_path: NodePath = NodePath("ParallaxLayer/Stars")
@export var layer_dust_path: NodePath = NodePath("ParallaxLayer/Dust")
@export var layer_fog_path: NodePath = NodePath("ParallaxLayer/Fog")
@export var motion_scale_stars: float = 0.12
@export var motion_scale_dust: float = 0.35
@export var motion_scale_fog: float = 0.6

var _camera: Camera2D
var _mat_stars: ShaderMaterial
var _mat_dust: ShaderMaterial
var _mat_fog: ShaderMaterial


func _ready() -> void:
	_camera = get_viewport().get_camera_2d()
	var stars: CanvasItem = get_node_or_null(layer_stars_path) as CanvasItem
	var dust: CanvasItem = get_node_or_null(layer_dust_path) as CanvasItem
	var fog: CanvasItem = get_node_or_null(layer_fog_path) as CanvasItem
	if stars:
		stars.visible = true
		if stars.material is ShaderMaterial:
			_mat_stars = stars.material as ShaderMaterial
	if dust:
		dust.visible = true
		if dust.material is ShaderMaterial:
			_mat_dust = dust.material as ShaderMaterial
	if fog:
		fog.visible = true
		if fog.material is ShaderMaterial:
			_mat_fog = fog.material as ShaderMaterial
	EventBus.wave_cleared.connect(_on_stage_progression)
	EventBus.stage_cleared.connect(_on_stage_progression)
	if ThemeManager:
		if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
			ThemeManager.theme_changed.connect(_on_theme_changed)
		_apply_theme_colors(ThemeManager.current_theme)
	call_deferred("_setup_theme")


func _setup_theme() -> void:
	if not is_instance_valid(self):
		return
	if ThemeManager == null:
		return
	if ThemeManager.theme_changed.is_connected(_on_theme_changed):
		return
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_theme_colors(ThemeManager.current_theme)


func _process(_delta: float) -> void:
	if not _camera or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	var pos: Vector2 = _camera.global_position if _camera else Vector2.ZERO
	if _mat_stars:
		_mat_stars.set_shader_parameter("scroll_offset", pos * motion_scale_stars)
	if _mat_dust:
		_mat_dust.set_shader_parameter("scroll_offset", pos * motion_scale_dust)
	if _mat_fog:
		_mat_fog.set_shader_parameter("scroll_offset", pos * motion_scale_fog)
	# Focus: center sharp, edges atmospheric; tighten in combat, expand when calm
	if VisualLayers:
		var center: Vector2 = VisualLayers.get_focus_center()
		var inner: float = VisualLayers.get_focus_inner_radius()
		var outer: float = VisualLayers.get_focus_outer_radius()
		if _mat_stars:
			_mat_stars.set_shader_parameter("focus_center", center)
			_mat_stars.set_shader_parameter("focus_inner_radius", inner)
			_mat_stars.set_shader_parameter("focus_outer_radius", outer)
		if _mat_dust:
			_mat_dust.set_shader_parameter("focus_center", center)
			_mat_dust.set_shader_parameter("focus_inner_radius", inner)
			_mat_dust.set_shader_parameter("focus_outer_radius", outer)
		if _mat_fog:
			_mat_fog.set_shader_parameter("focus_center", center)
			_mat_fog.set_shader_parameter("focus_inner_radius", inner)
			_mat_fog.set_shader_parameter("focus_outer_radius", outer)


func _on_theme_changed(theme_id: int, transition_duration: float) -> void:
	if not ThemeManager:
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	var star_c: Color = ThemeManager.get_star_color()
	var dust_c: Color = ThemeManager.get_dust_color()
	var fog_c: Color = ThemeManager.get_fog_color()
	if _mat_stars:
		tween.parallel().tween_method(_set_star_color, _get_star_color(), star_c, transition_duration)
	if _mat_dust:
		tween.parallel().tween_method(_set_dust_color, _get_dust_color(), dust_c, transition_duration)
	if _mat_fog:
		tween.parallel().tween_method(_set_fog_color, _get_fog_color(), fog_c, transition_duration)


func _get_star_color() -> Color:
	if _mat_stars:
		var v: Variant = _mat_stars.get_shader_parameter("star_color")
		if v is Color:
			return v
	return Color(0.5, 0.6, 0.85)


func _set_star_color(c: Color) -> void:
	if _mat_stars:
		_mat_stars.set_shader_parameter("star_color", Color(c.r, c.g, c.b, 0.7))


func _get_dust_color() -> Color:
	if _mat_dust:
		var v: Variant = _mat_dust.get_shader_parameter("dust_color")
		if v is Color:
			return v
	return Color(0.2, 0.22, 0.35)


func _set_dust_color(c: Color) -> void:
	if _mat_dust:
		_mat_dust.set_shader_parameter("dust_color", Color(c.r, c.g, c.b, 0.25))


func _get_fog_color() -> Color:
	if _mat_fog:
		var v: Variant = _mat_fog.get_shader_parameter("fog_color")
		if v is Color:
			return v
	return Color(0.08, 0.1, 0.18)


func _set_fog_color(c: Color) -> void:
	if _mat_fog:
		_mat_fog.set_shader_parameter("fog_color", Color(c.r, c.g, c.b, 0.35))


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_F10:
			_debug_print_atmosphere_status()


func _debug_print_atmosphere_status() -> void:
	var theme_name: String = ThemeManager.get_theme_name(ThemeManager.current_theme) if ThemeManager else "N/A"
	var stars_node: CanvasItem = get_node_or_null(layer_stars_path) as CanvasItem
	var dust_node: CanvasItem = get_node_or_null(layer_dust_path) as CanvasItem
	var fog_node: CanvasItem = get_node_or_null(layer_fog_path) as CanvasItem
	print("[Atmosphere] theme=%s | Stars: visible=%s material=%s | Dust: visible=%s material=%s | Fog: visible=%s material=%s" % [
		theme_name,
		stars_node.visible if stars_node else false,
		"ShaderMaterial" if _mat_stars else "none",
		dust_node.visible if dust_node else false,
		"ShaderMaterial" if _mat_dust else "none",
		fog_node.visible if fog_node else false,
		"ShaderMaterial" if _mat_fog else "none",
	])


func _apply_theme_colors(theme_id: int) -> void:
	if not ThemeManager:
		return
	_set_star_color(ThemeManager.get_star_color())
	_set_dust_color(ThemeManager.get_dust_color())
	_set_fog_color(ThemeManager.get_fog_color())


## Gentle brightness shift on stage progression (living rhythm). Uses VisualLayers multiplier so opacity controller can combine.
func _on_stage_progression(_arg: int = 0) -> void:
	if not VisualLayers:
		return
	VisualLayers.set_stage_progression_multiplier(1.04)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_SINE)
	t.tween_method(VisualLayers.set_stage_progression_multiplier, 1.04, 1.0, 1.2)
