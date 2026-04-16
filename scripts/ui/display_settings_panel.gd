extends Control
## Display settings UI: mode, resolution, UI scale. Shown as overlay from SystemLab.

signal closed

const MODE_WINDOWED := 0
const MODE_FULLSCREEN := 1
const MODE_BORDERLESS := 2

var _mode_option: OptionButton
var _resolution_option: OptionButton
var _ui_scale_slider: HSlider
var _ui_scale_label: Label
var _apply_btn: Button
var _close_btn: Button


func _ds() -> Node:
	return get_node_or_null("/root/DisplaySettings")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.09, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_gui_input)
	add_child(bg)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_top = -180
	panel.offset_right = 200
	panel.offset_bottom = 180
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.1, 0.16, 0.98)
	style.border_color = Color(0.3, 0.6, 0.9, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_top = 16
	style.content_margin_right = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Display Settings"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1.0))
	vbox.add_child(title)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	var mode_label := Label.new()
	mode_label.text = "Display Mode:"
	mode_label.custom_minimum_size.x = 120
	mode_row.add_child(mode_label)
	_mode_option = OptionButton.new()
	_mode_option.item_count = 0
	_mode_option.add_item("Windowed", MODE_WINDOWED)
	_mode_option.add_item("Fullscreen", MODE_FULLSCREEN)
	_mode_option.add_item("Borderless", MODE_BORDERLESS)
	_mode_option.custom_minimum_size.x = 160
	mode_row.add_child(_mode_option)
	vbox.add_child(mode_row)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)
	var res_label := Label.new()
	res_label.text = "Resolution:"
	res_label.custom_minimum_size.x = 120
	res_row.add_child(res_label)
	_resolution_option = OptionButton.new()
	_resolution_option.custom_minimum_size.x = 180
	_populate_resolutions()
	res_row.add_child(_resolution_option)
	vbox.add_child(res_row)

	var ui_row := VBoxContainer.new()
	ui_row.add_theme_constant_override("separation", 4)
	_ui_scale_label = Label.new()
	var ds: Node = _ds()
	_ui_scale_label.text = "UI Scale: %.1f" % (float(ds.get("ui_scale")) if ds else 1.0)
	ui_row.add_child(_ui_scale_label)
	_ui_scale_slider = HSlider.new()
	_ui_scale_slider.min_value = 0.0
	_ui_scale_slider.max_value = 1.0
	_ui_scale_slider.step = 0.1
	_ui_scale_slider.custom_minimum_size.x = 200
	_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	ui_row.add_child(_ui_scale_slider)
	vbox.add_child(ui_row)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	_apply_btn = Button.new()
	_apply_btn.text = "Apply"
	_apply_btn.pressed.connect(_on_apply)
	btn_row.add_child(_apply_btn)
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.pressed.connect(_on_close)
	btn_row.add_child(_close_btn)
	vbox.add_child(btn_row)

	_refresh_from_settings()


func _populate_resolutions() -> void:
	var ds: Node = _ds()
	if not ds:
		return
	_resolution_option.clear()
	var desktop := DisplayServer.screen_get_size()
	var added: Array[Vector2i] = []
	var common_res: Array = ds.get("COMMON_RESOLUTIONS")
	if common_res == null:
		common_res = [Vector2i(1920, 1080)]
	for r in common_res:
		var rv: Vector2i = r as Vector2i
		if rv in added:
			continue
		added.append(rv)
		var label := "%d × %d" % [rv.x, rv.y]
		if rv == desktop:
			label += " (Desktop)"
		_resolution_option.add_item(label, _resolution_option.item_count)
		_resolution_option.set_item_metadata(_resolution_option.item_count - 1, rv)
	if desktop not in added:
		_resolution_option.add_item("%d × %d (Desktop)" % [desktop.x, desktop.y], _resolution_option.item_count)
		_resolution_option.set_item_metadata(_resolution_option.item_count - 1, desktop)
	var curr_raw: Variant = ds.get("resolution")
	var curr: Vector2i = curr_raw as Vector2i if curr_raw is Vector2i else Vector2i(1920, 1080)
	if curr not in added:
		var label := "%d × %d" % [curr.x, curr.y]
		if curr == desktop:
			label += " (Desktop)"
		_resolution_option.add_item(label, _resolution_option.item_count)
		_resolution_option.set_item_metadata(_resolution_option.item_count - 1, curr)


func _refresh_from_settings() -> void:
	var ds: Node = _ds()
	if not ds:
		return
	_mode_option.select(_mode_option.get_item_index(ds.get("display_mode")))
	var res_raw: Variant = ds.get("resolution")
	var target_res: Vector2i = res_raw as Vector2i if res_raw is Vector2i else Vector2i(1920, 1080)
	for i in range(_resolution_option.item_count):
		var meta = _resolution_option.get_item_metadata(i)
		if meta != null and meta == target_res:
			_resolution_option.select(i)
			break
	_ui_scale_slider.value = ds.call("get_ui_scale_slider_value")
	_update_ui_scale_label()


func _update_ui_scale_label() -> void:
	var ds: Node = _ds()
	if _ui_scale_label and ds:
		_ui_scale_label.text = "UI Scale: %.1f" % ds.get("ui_scale")


func _on_ui_scale_changed(_val: float) -> void:
	var ds: Node = _ds()
	if ds:
		ds.call("set_ui_scale_from_slider", _ui_scale_slider.value)
		_update_ui_scale_label()


func _on_apply() -> void:
	var ds: Node = _ds()
	if not ds:
		return
	var midx := _mode_option.selected
	ds.call("set_display_mode", _mode_option.get_item_id(midx))
	var meta = _resolution_option.get_item_metadata(_resolution_option.selected)
	if meta != null:
		ds.call("set_resolution", meta)
	ds.call("set_ui_scale_from_slider", _ui_scale_slider.value)
	ds.call("apply_settings")


func _on_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_close()


func _on_close() -> void:
	closed.emit()
	hide()

