extends Node
class_name BuildIgnitionFX
## Listens to build_ignited: emotional highlight — system coming online.
## World brightness rises briefly, color tone shifts (cool), subtle time slow, light echo (WeaponLightController).
## No explosion: no hit flash, no heavy shake.

const IGNITION_GLOW_DURATION := 0.5
const IGNITION_GLOW_STRENGTH := 1.2
const IGNITION_OVERLAY_ALPHA := 0.04
const IGNITION_TINT := Color(0.82, 0.92, 1.0)
const TIME_SLOW_DURATION := 0.35
const TIME_SLOW_SCALE := 0.72

func _ready() -> void:
	if EventBus.has_signal("build_ignited"):
		EventBus.build_ignited.connect(_on_build_ignited)


func _on_build_ignited(_effect_id: String, display_name: String, _duration_sec: float) -> void:
	# World brightness + cool color tone (system coming online; BeatConductor + WeaponLightController echo)
	_request_ignition_pulse()
	# Subtle time slow — moment of focus, not impact (Hitstop applies and recovers)
	if EventBus.has_signal("time_scale_dip_requested"):
		EventBus.time_scale_dip_requested.emit(TIME_SLOW_DURATION, TIME_SLOW_SCALE)
	# No explosion: no hit_flash, no heavy screen shake
	# Short-lived label: "build online"
	_show_ignition_label(display_name)


func _request_ignition_pulse() -> void:
	if BeatConductor and BeatConductor.has_method("request_world_ripple"):
		BeatConductor.request_world_ripple(IGNITION_GLOW_DURATION, IGNITION_GLOW_STRENGTH, IGNITION_OVERLAY_ALPHA, true, IGNITION_TINT)


func _show_ignition_label(display_name: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "BuildIgnitionLayer"
	layer.layer = VisualLayers.LAYER_FX if VisualLayers else 40
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var label := Label.new()
	label.text = display_name + " — online"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	label.add_theme_color_override("font_outline_color", Color(0.15, 0.12, 0.05))
	label.add_theme_constant_override("outline_size", 4)
	center.add_child(label)
	# Fade out and remove after 2s
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(layer):
		layer.queue_free()
