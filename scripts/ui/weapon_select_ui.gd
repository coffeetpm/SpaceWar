extends Control
class_name WeaponSelectUI
## System interface: feels like controlling a light engine. Geometric panels, energy lines, minimal text.
## Options appear as modules/nodes; smooth, reactive, no abrupt transitions.

signal weapon_selected(weapon_id: String)

const WEAPONS: Array[Dictionary] = [
	{"id": "beam", "name": "Beam", "tag": "LIGHT"},
	{"id": "drones", "name": "Drones", "tag": "SPACE"},
	{"id": "spread", "name": "Spread", "tag": "TIME"},
	{"id": "burst", "name": "Pulse", "tag": "TIME"},
]

const PANEL_COLOR := Color(0.06, 0.08, 0.12, 0.92)
const BORDER_COLOR := Color(0.25, 0.65, 0.95, 0.7)
const LINE_COLOR := Color(0.35, 0.82, 1.0, 0.35)
const MODULE_BG := Color(0.08, 0.11, 0.16, 0.9)
const MODULE_BORDER := Color(0.3, 0.7, 1.0, 0.4)
const MODULE_ACTIVE := Color(0.4, 0.85, 1.05, 0.6)
const TEXT_COLOR := Color(0.5, 0.85, 1.0, 0.95)
const TEXT_DIM := Color(0.45, 0.7, 0.9, 0.6)
const TWEEN_HOVER := 0.12
const TWEEN_SELECT := 0.15
const TWEEN_SHOW := 0.25

var _selected_id: String = "beam"
var _root: Control
var _module_list: HBoxContainer
var _engage_btn: Button
var _module_nodes: Array[Control] = []


func _ready() -> void:
	var old_panel := get_node_or_null("Panel")
	if old_panel:
		old_panel.queue_free()
	_build_system_interface()
	_apply_initial_selection()
	modulate.a = 0.0


func _build_system_interface() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -220
	_root.offset_top = -140
	_root.offset_right = 220
	_root.offset_bottom = 140
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 14
	style.content_margin_top = 14
	style.content_margin_right = 14
	style.content_margin_bottom = 14
	bg.add_theme_stylebox_override("panel", style)
	_root.add_child(bg)

	var lines := _EnergyLines.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.set_meta("line_color", LINE_COLOR)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lines)

	var title := Label.new()
	title.text = "PRIMARY SYSTEM"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", TEXT_DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(12, 12)
	title.size = Vector2(396, 20)
	_root.add_child(title)

	_module_list = HBoxContainer.new()
	_module_list.position = Vector2(24, 44)
	_module_list.size = Vector2(372, 72)
	_module_list.add_theme_constant_override("separation", 16)
	_root.add_child(_module_list)

	var available := _get_available_weapons()
	for w in available:
		var mod := _add_module(w)
		_module_nodes.append(mod)

	_engage_btn = Button.new()
	_engage_btn.text = "ENGAGE"
	_engage_btn.position = Vector2(120, 128)
	_engage_btn.size = Vector2(180, 36)
	_engage_btn.add_theme_font_size_override("font_size", 14)
	_engage_btn.add_theme_color_override("font_color", TEXT_COLOR)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.2, 0.3, 0.9)
	btn_style.border_color = MODULE_BORDER
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(0)
	btn_style.content_margin_left = 12
	btn_style.content_margin_top = 8
	btn_style.content_margin_right = 12
	btn_style.content_margin_bottom = 8
	_engage_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	(btn_hover as StyleBoxFlat).border_color = MODULE_ACTIVE
	(btn_hover as StyleBoxFlat).bg_color = Color(0.15, 0.28, 0.4, 0.95)
	_engage_btn.add_theme_stylebox_override("hover", btn_hover)
	_engage_btn.add_theme_stylebox_override("pressed", btn_hover)
	_engage_btn.pressed.connect(_on_start_pressed)
	_root.add_child(_engage_btn)


func _add_module(w: Dictionary) -> Control:
	var id: String = w.get("id", "")
	var name_str: String = w.get("name", "")
	var tag: String = w.get("tag", "")
	var box := Panel.new()
	box.custom_minimum_size = Vector2(84, 72)
	box.set_meta("weapon_id", id)
	var style := StyleBoxFlat.new()
	style.bg_color = MODULE_BG
	style.border_color = MODULE_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = "%s\n%s" % [name_str, tag]
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", TEXT_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 4
	lbl.offset_top = 4
	lbl.offset_right = -4
	lbl.offset_bottom = -4
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	box.gui_input.connect(_on_module_input.bind(id, box, style, lbl))
	box.mouse_entered.connect(_on_module_entered.bind(box, style, lbl))
	box.mouse_exited.connect(_on_module_exited.bind(box, style, lbl))
	_module_list.add_child(box)
	return box


func _on_module_input(event: InputEvent, id: String, box: Control, style: StyleBoxFlat, lbl: Label) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_module(id)


func _on_module_entered(box: Control, _style: StyleBoxFlat, lbl: Label) -> void:
	var sty: StyleBoxFlat = box.get_theme_stylebox("panel") as StyleBoxFlat
	if sty:
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(box, "modulate", Color(1.08, 1.08, 1.12), TWEEN_HOVER)
		t.parallel().tween_property(sty, "border_color", MODULE_ACTIVE, TWEEN_HOVER)
		t.parallel().tween_method(func(_v) -> void: box.queue_redraw(), 0.0, 1.0, TWEEN_HOVER)
	if lbl:
		lbl.add_theme_color_override("font_color", TEXT_COLOR)


func _on_module_exited(box: Control, _style: StyleBoxFlat, lbl: Label) -> void:
	var active: bool = box.get_meta("weapon_id", "") == _selected_id
	var sty: StyleBoxFlat = box.get_theme_stylebox("panel") as StyleBoxFlat
	if sty:
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(box, "modulate", Color(1, 1, 1), TWEEN_HOVER)
		t.parallel().tween_property(sty, "border_color", MODULE_ACTIVE if active else MODULE_BORDER, TWEEN_HOVER)
		t.parallel().tween_method(func(_v) -> void: box.queue_redraw(), 0.0, 1.0, TWEEN_HOVER)
	if lbl:
		lbl.add_theme_color_override("font_color", TEXT_COLOR if active else TEXT_DIM)


func _select_module(id: String) -> void:
	_selected_id = id
	for child in _module_list.get_children():
		if not child is Panel:
			continue
		var pan := child as Panel
		var sty: StyleBoxFlat = pan.get_theme_stylebox("panel") as StyleBoxFlat
		if not sty:
			continue
		var is_active: bool = pan.get_meta("weapon_id", "") == id
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(sty, "border_color", MODULE_ACTIVE if is_active else MODULE_BORDER, TWEEN_SELECT)
		t.tween_method(func(_v) -> void: pan.queue_redraw(), 0.0, 1.0, TWEEN_SELECT)
		var lbl: Label = pan.get_child(0) if pan.get_child_count() > 0 else null
		if lbl:
			lbl.add_theme_color_override("font_color", TEXT_COLOR if is_active else TEXT_DIM)


func _apply_initial_selection() -> void:
	var available := _get_available_weapons()
	var has := false
	for w in available:
		if w.get("id", "") == _selected_id:
			has = true
			break
	if available.size() > 0 and not has:
		_selected_id = available[0].get("id", "beam")
	for child in _module_list.get_children():
		if child is Panel:
			var pan := child as Panel
			var sty: StyleBoxFlat = pan.get_theme_stylebox("panel") as StyleBoxFlat
			if sty:
				sty.border_color = MODULE_ACTIVE if pan.get_meta("weapon_id", "") == _selected_id else MODULE_BORDER
			var lbl: Label = pan.get_child(0) if pan.get_child_count() > 0 else null
			if lbl:
				lbl.add_theme_color_override("font_color", TEXT_COLOR if pan.get_meta("weapon_id", "") == _selected_id else TEXT_DIM)


func _get_available_weapons() -> Array:
	var available: Array = []
	var unlocked: Array = []
	if SaveManager:
		unlocked = SaveManager.get_unlocked_weapons()
	for w in WEAPONS:
		if unlocked.is_empty() or w.id in unlocked:
			available.append(w)
	if available.is_empty():
		available.assign(WEAPONS)
	return available


func _on_start_pressed() -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "modulate:a", 0.0, 0.14)
	t.tween_callback(func() -> void:
		hide()
		weapon_selected.emit(_selected_id)
	)


## Call this instead of show() when you want the fade-in tween. Do not override show() (CanvasItem native).
func show_with_fade() -> void:
	show()
	modulate.a = 0.0
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "modulate:a", 1.0, TWEEN_SHOW)


func set_selected(weapon_id: String) -> void:
	_selected_id = weapon_id
	_apply_initial_selection()


class _EnergyLines:
	extends Control
	func _draw() -> void:
		var c: Color = get_meta("line_color", Color(0.35, 0.82, 1.0, 0.35))
		var w := size.x
		var h := size.y
		var m := 12
		# Horizontal energy lines (top and bottom)
		draw_line(Vector2(m, 2), Vector2(w - m, 2), c)
		draw_line(Vector2(m, h - 3), Vector2(w - m, h - 3), c)
		# Short vertical ticks at corners
		draw_line(Vector2(m, 0), Vector2(m, 8), c)
		draw_line(Vector2(w - m, 0), Vector2(w - m, 8), c)
		draw_line(Vector2(m, h - 8), Vector2(m, h), c)
		draw_line(Vector2(w - m, h - 8), Vector2(w - m, h), c)
