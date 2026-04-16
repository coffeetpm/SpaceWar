extends Control
## GameOver: clean summary (stages, level, build, fragments) and two actions — Restart, Return to System Lab.
## Labels filled by StageManager before show. Premium panel: spacing, typography, subtle glow.

@onready var _panel: Panel = $Panel
var _system_lab: SystemLab
var _restart_btn: Button
var _lab_btn: Button

const TITLE_FONT_SIZE := 26
const ROW_FONT_SIZE := 15
const ROW_SPACING := 22
const PANEL_PADDING := 28
const GLOW_COLOR := Color(0.22, 0.5, 0.85, 0.12)
const BORDER_COLOR := Color(0.35, 0.7, 0.95, 0.5)


func _ready() -> void:
	hide()
	EventBus.game_over.connect(_on_game_over)
	_build_panel_style()
	_ensure_summary_labels()
	_build_buttons()
	_resolve_system_lab()


func _build_panel_style() -> void:
	if not _panel:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = GLOW_COLOR
	style.shadow_size = 8
	style.content_margin_left = PANEL_PADDING
	style.content_margin_top = PANEL_PADDING
	style.content_margin_right = PANEL_PADDING
	style.content_margin_bottom = PANEL_PADDING
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(320, 320)


func _ensure_summary_labels() -> void:
	if not _panel:
		return
	if not _panel.has_node("LevelReachedLabel"):
		var lbl := Label.new()
		lbl.name = "LevelReachedLabel"
		lbl.text = "Level reached: 1"
		lbl.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		_panel.add_child(lbl)
	if not _panel.has_node("BuildsLabel"):
		var bl := Label.new()
		bl.name = "BuildsLabel"
		bl.text = "Build: —"
		bl.add_theme_font_size_override("font_size", ROW_FONT_SIZE - 1)
		bl.add_theme_color_override("font_color", Color(0.7, 0.82, 1.0))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size.x = 260
		_panel.add_child(bl)
	# Title
	var title: Label = _panel.get_node_or_null("Label") as Label
	if title:
		title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
		title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
		title.text = "Run Over"
	_layout_labels()


func _layout_labels() -> void:
	if not _panel:
		return
	var y := float(PANEL_PADDING + 8)
	var cx: float = _panel.size.x * 0.5 if _panel.size.x > 0 else 160.0
	var title: Label = _panel.get_node_or_null("Label") as Label
	if title:
		title.set_anchors_preset(Control.PRESET_TOP_WIDE)
		title.offset_left = -140
		title.offset_top = y
		title.offset_right = 140
		title.offset_bottom = y + 36
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		y += 44
	for name in ["StagesClearedLabel", "LevelReachedLabel", "BuildsLabel", "CurrencyEarnedLabel", "TotalCurrencyLabel"]:
		var lbl: Label = _panel.get_node_or_null(name) as Label
		if lbl:
			lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
			lbl.offset_left = -130
			lbl.offset_top = y
			lbl.offset_right = 130
			lbl.offset_bottom = y + 22
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			y += ROW_SPACING


func _build_buttons() -> void:
	if not _panel:
		return
	_restart_btn = Button.new()
	_restart_btn.name = "RestartButton"
	_restart_btn.text = "Restart"
	_restart_btn.custom_minimum_size = Vector2(120, 36)
	_restart_btn.add_theme_font_size_override("font_size", 16)
	_restart_btn.pressed.connect(_on_restart_pressed)
	_panel.add_child(_restart_btn)
	_lab_btn = Button.new()
	_lab_btn.name = "SystemLabButton"
	_lab_btn.text = "Return to System Lab"
	_lab_btn.custom_minimum_size = Vector2(160, 36)
	_lab_btn.add_theme_font_size_override("font_size", 14)
	_lab_btn.pressed.connect(_on_system_lab_pressed)
	_panel.add_child(_lab_btn)
	# Remove old RestartLabel if present (replaced by button)
	var old_restart: Label = _panel.get_node_or_null("RestartLabel") as Label
	if old_restart:
		old_restart.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_READY:
		call_deferred("_layout_labels")
		call_deferred("_layout_buttons")


func _layout_buttons() -> void:
	if not _panel or not _restart_btn or not _lab_btn:
		return
	var h := _panel.size.y
	if h <= 0:
		h = 320
	_restart_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_restart_btn.anchor_left = 0.5
	_restart_btn.anchor_right = 0.5
	_restart_btn.anchor_top = 1.0
	_restart_btn.anchor_bottom = 1.0
	_restart_btn.offset_left = -130
	_restart_btn.offset_top = -52
	_restart_btn.offset_right = -10
	_restart_btn.offset_bottom = -12
	_lab_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_lab_btn.anchor_left = 0.5
	_lab_btn.anchor_right = 0.5
	_lab_btn.anchor_top = 1.0
	_lab_btn.anchor_bottom = 1.0
	_lab_btn.offset_left = 10
	_lab_btn.offset_top = -52
	_lab_btn.offset_right = 130
	_lab_btn.offset_bottom = -12


func _resolve_system_lab() -> void:
	var ui: Node = get_parent()
	if not ui:
		return
	_system_lab = ui.get_node_or_null("SystemLab") as SystemLab


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_system_lab_pressed() -> void:
	var lab: SystemLab = _system_lab if _system_lab else get_parent().get_node_or_null("SystemLab") as SystemLab
	if lab:
		hide()
		lab.show_lab(false)


func _on_game_over() -> void:
	_layout_labels()
	_layout_buttons()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _system_lab and _system_lab.visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_R:
			_on_restart_pressed()
