extends Node
## Visual evolution feedback: triggered moments only. First synergy, second synergy, ignition point.
## Refraction flicker, temporal echo, beam stability (via beam node). Not constant.

const LAYER_EVOLUTION_FX := 36
const REFRACTION_DURATION := 0.14
const REFRACTION_ALPHA := 0.055
const REFRACTION_COLOR := Color(0.82, 0.92, 1.0)
const ECHO_DURATION := 0.2
const ECHO_ALPHA := 0.065
const ECHO_COLOR := Color(0.72, 0.88, 1.0)

var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER_EVOLUTION_FX
	_layer.name = "EvolutionFeedbackLayer"
	add_child(_layer)
	if EventBus.has_signal("first_synergy_triggered"):
		EventBus.first_synergy_triggered.connect(_on_first_synergy)
	if EventBus.has_signal("second_synergy_triggered"):
		EventBus.second_synergy_triggered.connect(_on_second_synergy)
	if EventBus.has_signal("build_ignited"):
		EventBus.build_ignited.connect(_on_ignition_point)


func _on_first_synergy() -> void:
	_play_refraction_flicker()


func _on_second_synergy() -> void:
	_play_temporal_echo()


func _on_ignition_point(_effect_id: String, _display_name: String, _duration_sec: float) -> void:
	_play_refraction_flicker()
	_play_temporal_echo()
	# Energy distortion rings are handled by WeaponLightController on build_ignited


func _play_refraction_flicker() -> void:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_left = -50
	rect.offset_top = -50
	rect.offset_right = 50
	rect.offset_bottom = 50
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(REFRACTION_COLOR.r, REFRACTION_COLOR.g, REFRACTION_COLOR.b, REFRACTION_ALPHA)
	_layer.add_child(rect)
	var t := rect.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(rect, "color:a", 0.0, REFRACTION_DURATION)
	t.tween_callback(func() -> void: rect.queue_free())


func _play_temporal_echo() -> void:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_left = -50
	rect.offset_top = -50
	rect.offset_right = 50
	rect.offset_bottom = 50
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(ECHO_COLOR.r, ECHO_COLOR.g, ECHO_COLOR.b, ECHO_ALPHA)
	_layer.add_child(rect)
	var t := rect.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(rect, "color:a", 0.0, ECHO_DURATION)
	t.tween_callback(func() -> void: rect.queue_free())
