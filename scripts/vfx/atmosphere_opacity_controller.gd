extends Node
## Tetris Effect–style: Layer 3 atmosphere fades during combat and pulses with beat.
## Drives parallax + motif opacity so beauty stays behind gameplay.

@export var parallax_controller_path: NodePath = NodePath("../ParallaxController")
@export var world_atmosphere_path: NodePath = NodePath("../World/StarDust")

var _parallax_stars: CanvasItem
var _parallax_dust: CanvasItem
var _parallax_fog: CanvasItem
var _world_atmosphere: CanvasItem
var _beat_boost: float = 1.0
var _beat_boost_until: float = 0.0


func _ready() -> void:
	var px: Node = get_node_or_null(parallax_controller_path)
	if px:
		var layer = px.get_node_or_null("ParallaxLayer")
		if layer:
			_parallax_stars = layer.get_node_or_null("Stars") as CanvasItem
			_parallax_dust = layer.get_node_or_null("Dust") as CanvasItem
			_parallax_fog = layer.get_node_or_null("Fog") as CanvasItem
	_world_atmosphere = get_node_or_null(world_atmosphere_path) as CanvasItem
	if BeatConductor and BeatConductor.has_signal("beat_pulse"):
		BeatConductor.beat_pulse.connect(_on_beat_pulse)


func _on_beat_pulse() -> void:
	if VisualLayers:
		VisualLayers.set_atmosphere_beat_pulse()
	_beat_boost = VisualLayers.ATMOSPHERE_BEAT_BOOST if VisualLayers else 1.08
	_beat_boost_until = Time.get_ticks_msec() * 0.001 + (VisualLayers.ATMOSPHERE_BEAT_DURATION if VisualLayers else 0.12)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now >= _beat_boost_until:
		_beat_boost = 1.0
	else:
		# Ease back to 1.0
		var t := 1.0 - (_beat_boost_until - now) / (VisualLayers.ATMOSPHERE_BEAT_DURATION if VisualLayers else 0.12)
		_beat_boost = lerpf(VisualLayers.ATMOSPHERE_BEAT_BOOST if VisualLayers else 1.08, 1.0, t)
	var opacity: float = VisualLayers.get_atmosphere_opacity_multiplier() if VisualLayers else 1.0
	opacity *= _beat_boost
	if VisualLayers and VisualLayers.has_method("get_atmosphere_breath_multiplier"):
		opacity *= VisualLayers.get_atmosphere_breath_multiplier()
	if VisualLayers and VisualLayers.has_method("get_stage_progression_multiplier"):
		opacity *= VisualLayers.get_stage_progression_multiplier()
	if EmotionFeedback and EmotionFeedback.has_method("get_emotion_breath_intensity"):
		opacity *= EmotionFeedback.get_emotion_breath_intensity()
	opacity = clampf(opacity, 0.32, 1.0)
	if _parallax_stars:
		_parallax_stars.modulate.a = opacity
	if _parallax_dust:
		_parallax_dust.modulate.a = opacity * 0.92
	if _parallax_fog:
		_parallax_fog.modulate.a = opacity * 0.85
	if _world_atmosphere:
		_world_atmosphere.modulate.a = opacity * 0.9
