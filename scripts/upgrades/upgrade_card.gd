extends Control
class_name UpgradeCard
## Single upgrade choice card with entrance, focus, and select animations.
## REFRACT sci-fi: minimal, geometric, controlled glow.

signal card_selected(upgrade: UpgradeData)

const ICON_SIZE := 48
const CARD_ENTER_DURATION := 0.18
const CARD_ENTER_OFFSET_Y := 18.0
const CARD_ENTER_SCALE_START := 0.92
const FOCUS_SCALE := 1.03
const FOCUS_UNFOCUSED_ALPHA := 0.85
const SELECT_SCALE_POP := 1.05
const SELECT_SETTLE_DURATION := 0.10
const ICON_PULSE_DURATION := 0.08
const TICK_NUDGE_PX := 2.0
const SWEEP_DURATION := 0.12
const GLOW_NORMAL := Color(0.45, 0.72, 0.95, 0.18)
const GLOW_FOCUSED := Color(0.55, 0.82, 1.0, 0.32)
const LABEL_COLOR := Color(0.92, 0.95, 1.0)
const HINT_PREVIEW_SIZE := Vector2(52, 36)
const HINT_LOOP_SEC := 1.8
const FORCE_TAG_COLORS: Dictionary = {
	"light": Color(0.6, 0.85, 1.0),
	"time": Color(0.85, 0.75, 1.0),
	"space": Color(0.75, 0.9, 0.95),
}

var upgrade_data: UpgradeData
var _bg: ColorRect
var _icon_rect: TextureRect
var _content: Control
var _sweep_line: ColorRect
var _hint_preview: Control
var _hint_type: String = ""
var _hint_phase: float = 0.0
var _is_focused: bool = false
var _entered: bool = false
var _parent_ui: Control


func setup(upgrade: UpgradeData, parent_ui: Control) -> void:
	_parent_ui = parent_ui
	upgrade_data = upgrade
	custom_minimum_size = Vector2(260, 88)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_content(parent_ui)
	# Invisible until play_enter
	modulate.a = 0.0
	scale = Vector2(CARD_ENTER_SCALE_START, CARD_ENTER_SCALE_START)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _build_content(parent_ui: Control) -> void:
	_bg = ColorRect.new()
	_bg.name = "Glow"
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = GLOW_NORMAL
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_content = Control.new()
	_content.name = "Content"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = 12
	_content.offset_top = 8
	_content.offset_right = -12
	_content.offset_bottom = -8
	add_child(_content)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(hbox)
	hbox.add_theme_constant_override("separation", 12)
	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex: Texture2D = upgrade_data.icon
	if not tex and upgrade_data.icon_path and not upgrade_data.icon_path.is_empty():
		tex = load(upgrade_data.icon_path) as Texture2D
	if tex:
		_icon_rect.texture = tex
	else:
		_icon_rect.texture = _placeholder_icon()
	hbox.add_child(_icon_rect)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)
	var title := Label.new()
	title.text = upgrade_data.display_name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", LABEL_COLOR)
	vbox.add_child(title)
	var effect_line := Label.new()
	effect_line.text = _effect_summary()
	effect_line.add_theme_font_size_override("font_size", 12)
	effect_line.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98, 0.9))
	effect_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_line.custom_minimum_size.x = 180
	vbox.add_child(effect_line)
	var tags_line := Label.new()
	tags_line.text = _tags_display()
	tags_line.add_theme_font_size_override("font_size", 10)
	var fk: String = upgrade_data.primary_force.to_lower()
	tags_line.add_theme_color_override("font_color", FORCE_TAG_COLORS.get(fk, Color(0.7, 0.8, 0.95)))
	vbox.add_child(tags_line)
	# Small visual hint preview (beam / drone / spread / echo)
	_hint_type = _get_hint_type()
	_hint_preview = Control.new()
	_hint_preview.name = "HintPreview"
	_hint_preview.custom_minimum_size = HINT_PREVIEW_SIZE
	_hint_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_preview.draw.connect(_on_hint_draw)
	hbox.add_child(_hint_preview)
	# Confirm sweep line (hidden until play_select)
	_sweep_line = ColorRect.new()
	_sweep_line.name = "SweepLine"
	_sweep_line.visible = false
	_sweep_line.color = Color(0.6, 0.9, 1.0, 0.5)
	_sweep_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sweep_line)
	_sweep_line.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_sweep_line.anchor_top = 0.5
	_sweep_line.anchor_bottom = 0.5
	_sweep_line.offset_top = -1.5
	_sweep_line.offset_bottom = 1.5
	_sweep_line.offset_left = 0.0
	_sweep_line.offset_right = 4.0


func _effect_summary() -> String:
	var s: String = upgrade_data.description.replace("\n", " ").strip_edges()
	if s.length() > 60:
		return s.substr(0, 57) + "..."
	return s


func _tags_display() -> String:
	var parts: PackedStringArray = []
	if not upgrade_data.primary_force.is_empty():
		parts.append(upgrade_data.primary_force.to_upper())
	for t in upgrade_data.tags:
		if t is String and not (t as String).is_empty():
			var x: String = (t as String).strip_edges()
			if x not in parts:
				parts.append(x)
	if parts.is_empty():
		return ""
	return " · ".join(parts)


func _placeholder_icon() -> Texture2D:
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var col: Color = FORCE_TAG_COLORS.get(upgrade_data.primary_force.to_lower(), Color(0.5, 0.7, 0.95))
	col.a = 0.9
	var cx := ICON_SIZE / 2.0
	var r := minf(cx, cx) - 4.0
	for y in ICON_SIZE:
		for x in ICON_SIZE:
			if Vector2(x - cx, y - cx).length() <= r:
				img.set_pixel(x, y, col)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _get_hint_type() -> String:
	var id_lower: String = String(upgrade_data.id).to_lower()
	var tags_lower: PackedStringArray = []
	for t in upgrade_data.tags:
		if t is String:
			tags_lower.append((t as String).to_lower())
	for t in tags_lower:
		if t in ["echo", "temporal", "delay", "afterimage"]:
			return "echo"
		if t in ["orbit", "drone", "orbital"]:
			return "drone"
		if t in ["spread", "cone", "fan", "wide", "split", "chain"]:
			return "spread"
		if t in ["beam", "pierce", "line"]:
			return "beam"
		if t in ["dash", "vector", "velocity", "rail"]:
			return "beam"
	if id_lower.contains("echo") or id_lower.contains("temporal") or id_lower.contains("pierce"):
		return "echo"
	if id_lower.contains("orbit") or id_lower.contains("drone") or id_lower.contains("shock"):
		return "drone"
	if id_lower.contains("spread") or id_lower.contains("chain") or id_lower.contains("pulse"):
		return "spread"
	if id_lower.contains("beam") or id_lower.contains("pierce"):
		return "beam"
	return "none"


func _process(delta: float) -> void:
	if _hint_type.is_empty() or _hint_type == "none" or not visible:
		return
	_hint_phase += delta / HINT_LOOP_SEC
	if _hint_phase >= 1.0:
		_hint_phase -= 1.0
	if _hint_preview and is_instance_valid(_hint_preview):
		_hint_preview.queue_redraw()


func _on_hint_draw() -> void:
	if not _hint_preview or _hint_type == "none":
		return
	var sz := _hint_preview.size
	if sz.x <= 0 or sz.y <= 0:
		return
	var cx := sz.x * 0.5
	var cy := sz.y * 0.5
	var col: Color = FORCE_TAG_COLORS.get(upgrade_data.primary_force.to_lower(), Color(0.5, 0.75, 0.95))
	col.a = 0.5
	var thin := 1.2
	match _hint_type:
		"beam":
			# Thin vertical beam line, pulse travels up
			var tip_y := cy - 12.0 + 20.0 * (1.0 - _hint_phase)
			_hint_preview.draw_line(Vector2(cx, cy + 10), Vector2(cx, tip_y), col)
			col.a = 0.25
			_hint_preview.draw_line(Vector2(cx - thin, cy + 10), Vector2(cx - thin, cy - 8), col)
			_hint_preview.draw_line(Vector2(cx + thin, cy + 10), Vector2(cx + thin, cy - 8), col)
		"drone":
			# Small orbiting dot
			var r := 10.0
			var angle := _hint_phase * TAU
			var dot := Vector2(cx + cos(angle) * r, cy + sin(angle) * r)
			col.a = 0.7
			_hint_preview.draw_arc(Vector2(cx, cy), r, 0, TAU, 24, Color(col.r, col.g, col.b, 0.2))
			_hint_preview.draw_circle(dot, 2.5, col)
		"spread":
			# Fan of short lines, pulse opacity
			var rays := 5
			var spread_angle := deg_to_rad(50.0)
			col.a = 0.35 + 0.25 * (0.5 + 0.5 * sin(_hint_phase * TAU))
			for i in rays:
				var a := -spread_angle * 0.5 + spread_angle * float(i) / maxf(1, rays - 1) + _hint_phase * 0.3
				var end := Vector2(cx + cos(a) * 18, cy - 6 + sin(a) * 18)
				_hint_preview.draw_line(Vector2(cx, cy + 4), end, col)
		"echo":
			# Delayed flash echo: two overlapping strokes with phase offset
			var echo_phase := fmod(_hint_phase + 0.35, 1.0)
			col.a = 0.2 + 0.4 * (1.0 - echo_phase)
			_hint_preview.draw_line(Vector2(cx - 14, cy), Vector2(cx + 14, cy), col)
			col.a = 0.15 + 0.35 * (1.0 - _hint_phase)
			_hint_preview.draw_line(Vector2(cx - 12, cy - 2), Vector2(cx + 12, cy - 2), col)


func play_enter(delay: float) -> void:
	pivot_offset = size * 0.5
	if _content:
		_content.position = Vector2(0, CARD_ENTER_OFFSET_Y)
	scale = Vector2(CARD_ENTER_SCALE_START, CARD_ENTER_SCALE_START)
	modulate.a = 0.0
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_interval(delay)
	t.tween_property(self, "scale", Vector2.ONE, CARD_ENTER_DURATION)
	if _content:
		t.parallel().tween_property(_content, "position", Vector2.ZERO, CARD_ENTER_DURATION)
	t.parallel().tween_property(self, "modulate:a", 1.0, CARD_ENTER_DURATION)
	t.tween_callback(func() -> void: _entered = true)


func set_focused(focused: bool) -> void:
	if _is_focused == focused:
		return
	_is_focused = focused
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	var target_scale: float = FOCUS_SCALE if focused else 1.0
	var target_alpha: float = 1.0 if focused else FOCUS_UNFOCUSED_ALPHA
	t.tween_property(self, "scale", Vector2(target_scale, target_scale), 0.1)
	t.parallel().tween_property(self, "modulate:a", target_alpha, 0.1)
	if _bg:
		t.parallel().tween_property(_bg, "color", GLOW_FOCUSED if focused else GLOW_NORMAL, 0.1)
	if focused:
		_play_icon_pulse()
		_play_tick_nudge()


func _play_icon_pulse() -> void:
	if not _icon_rect:
		return
	var orig := _icon_rect.modulate
	var t := _icon_rect.create_tween()
	t.tween_property(_icon_rect, "modulate", Color(1.2, 1.2, 1.2), ICON_PULSE_DURATION * 0.5)
	t.tween_property(_icon_rect, "modulate", orig, ICON_PULSE_DURATION * 0.5)


func _play_tick_nudge() -> void:
	if not _content:
		return
	var orig := _content.position
	var t := _content.create_tween()
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(_content, "position", orig + Vector2(TICK_NUDGE_PX, 0), ICON_PULSE_DURATION * 0.5)
	t.tween_property(_content, "position", orig, ICON_PULSE_DURATION * 0.5)


func play_select() -> void:
	# Confirm sweep
	if _sweep_line:
		_sweep_line.visible = true
		_sweep_line.offset_left = 0.0
		_sweep_line.offset_right = 4.0
		var full_width := size.x
		var t := _sweep_line.create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_CUBIC)
		t.tween_property(_sweep_line, "offset_left", full_width, SWEEP_DURATION)
		t.tween_property(_sweep_line, "offset_right", full_width + 4.0, 0.0)
		t.tween_callback(func() -> void: _sweep_line.visible = false)
	# Lock in: scale pop then settle
	var t2 := create_tween()
	t2.set_ease(Tween.EASE_OUT)
	t2.set_trans(Tween.TRANS_CUBIC)
	t2.tween_property(self, "scale", Vector2(SELECT_SCALE_POP, SELECT_SCALE_POP), 0.05)
	t2.tween_property(self, "scale", Vector2.ONE, SELECT_SETTLE_DURATION)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_selected.emit(upgrade_data)


func _on_mouse_entered() -> void:
	if _parent_ui and _parent_ui.has_method("set_focused_card"):
		_parent_ui.set_focused_card(self)


func _on_mouse_exited() -> void:
	if _parent_ui and _parent_ui.has_method("clear_focused_card"):
		_parent_ui.clear_focused_card(self)
