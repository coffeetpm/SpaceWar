extends Control
## Neon sci-fi HUD: right panel (timer, HP bar, build identity, currency), top run status, center notifications.
## Interaction: UI pulse on upgrade, glow on damage, clean flash on boss clear.

@onready var _hud_panel: Panel = $HUDPanel
@onready var _wave_label: Label = $HUDPanel/WaveLabel
@onready var _hp_label: Label = $HUDPanel/HPLabel
@onready var _hp_bar: ProgressBar = $HUDPanel/HPBar
@onready var _timer_label: Label = $HUDPanel/TimerLabel
@onready var _run_complete_label: Label = $RunCompleteLabel
@onready var _earned_label: Label = $HUDPanel/EarnedLabel
@onready var _total_label: Label = $HUDPanel/TotalCurrencyLabel
@onready var _build_identity: Label = $HUDPanel/BuildIdentity

var _exp_bar: ProgressBar
var _exp_level_label: Label
var _exp_pop_label: Label
var _weapon_icon: TextureRect

var _player: Node2D
var _clear_label: Label
var _stage_mgr: Node

const WEAPON_DISPLAY: Dictionary = {
	"beam": "Beam",
	"spread": "Spread",
	"burst": "Burst",
	"homing": "Homing",
	"drones": "Drones",
	"rear": "Rear",
}


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_stage_mgr = get_tree().get_first_node_in_group("stage_manager")
	if _stage_mgr == null and get_tree().root:
		_stage_mgr = get_tree().root.get_node_or_null("World/StageManager")
	if _run_complete_label:
		_run_complete_label.hide()
	if EventBus.has_signal("boss_clear_show_cleared"):
		EventBus.boss_clear_show_cleared.connect(_on_boss_clear_show_cleared)
	if EventBus.has_signal("boss_reward_unlocked"):
		EventBus.boss_reward_unlocked.connect(_on_boss_reward_unlocked)
	if EventBus.has_signal("upgrade_picked"):
		EventBus.upgrade_picked.connect(_on_upgrade_picked)
	EventBus.player_damaged.connect(_on_player_damaged)
	if EventBus.has_signal("run_started"):
		EventBus.run_started.connect(_on_run_started)
	if EventBus.has_signal("build_ignited"):
		EventBus.build_ignited.connect(_on_build_ignited)
	if EventBus.has_signal("exp_collected"):
		EventBus.exp_collected.connect(_on_exp_collected)
	_build_exp_ui()


func _on_run_started(weapon_id: String) -> void:
	_update_build_identity(weapon_id)
	_update_weapon_icon(weapon_id)


func _on_exp_collected(amount: int) -> void:
	_show_exp_pop(amount)


func _show_exp_pop(amount: int) -> void:
	if not _exp_pop_label or not _hud_panel:
		return
	_exp_pop_label.text = "+%d EXP" % amount
	_exp_pop_label.modulate.a = 1.0
	_exp_pop_label.offset_top = 80.0
	_exp_pop_label.visible = true
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(_exp_pop_label, "modulate:a", 0.0, 0.45)
	t.parallel().tween_property(_exp_pop_label, "offset_top", 72.0, 0.45)
	t.tween_callback(func() -> void:
		if is_instance_valid(_exp_pop_label):
			_exp_pop_label.visible = false
	)


func _on_build_ignited(_effect_id: String, display_name: String, _duration_sec: float) -> void:
	var lbl: Label = get_node_or_null("IgnitionNotification") as Label
	if not lbl:
		lbl = Label.new()
		lbl.name = "IgnitionNotification"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.offset_left = -100
		lbl.offset_top = -40
		lbl.offset_right = 100
		lbl.offset_bottom = 0
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
		add_child(lbl)
	lbl.text = display_name
	lbl.modulate = Color(1, 1, 1, 0)
	lbl.show()
	var tween := create_tween()
	tween.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.12)
	tween.tween_interval(1.2)
	tween.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(func() -> void: lbl.hide())


func _build_exp_ui() -> void:
	if not _hud_panel:
		return
	_exp_bar = ProgressBar.new()
	_exp_bar.name = "EXPBar"
	_exp_bar.anchor_left = 0.0
	_exp_bar.anchor_right = 1.0
	_exp_bar.anchor_top = 0.0
	_exp_bar.anchor_bottom = 0.0
	_exp_bar.offset_top = 86.0
	_exp_bar.offset_bottom = 94.0
	_exp_bar.max_value = 1.0
	_exp_bar.value = 0.0
	_exp_bar.show_percentage = false
	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = Color(0.05, 0.09, 0.14, 0.96)
	style_bg.corner_radius_top_left = 2
	style_bg.corner_radius_top_right = 2
	style_bg.corner_radius_bottom_right = 2
	style_bg.corner_radius_bottom_left = 2
	style_bg.border_width_left = 1
	style_bg.border_width_top = 1
	style_bg.border_width_right = 1
	style_bg.border_width_bottom = 1
	style_bg.border_color = Color(0.28, 0.55, 0.8, 0.68)
	var style_fill := StyleBoxFlat.new()
	style_fill.bg_color = Color(0.34, 0.78, 1.0, 0.98)
	style_fill.corner_radius_top_left = 2
	style_fill.corner_radius_top_right = 2
	style_fill.corner_radius_bottom_right = 2
	style_fill.corner_radius_bottom_left = 2
	_exp_bar.add_theme_stylebox_override("background", style_bg)
	_exp_bar.add_theme_stylebox_override("fill", style_fill)
	_hud_panel.add_child(_exp_bar)
	_exp_level_label = Label.new()
	_exp_level_label.name = "EXPLevelLabel"
	_exp_level_label.anchor_left = 0.0
	_exp_level_label.anchor_right = 1.0
	_exp_level_label.offset_top = 94.0
	_exp_level_label.offset_bottom = 108.0
	_exp_level_label.add_theme_font_size_override("font_size", 11)
	_exp_level_label.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 0.98))
	_exp_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exp_level_label.text = "Lv.1  EXP 0/10"
	_hud_panel.add_child(_exp_level_label)
	_exp_pop_label = Label.new()
	_exp_pop_label.name = "ExpPopLabel"
	_exp_pop_label.visible = false
	_exp_pop_label.anchor_left = 0.0
	_exp_pop_label.anchor_right = 1.0
	_exp_pop_label.offset_top = 80.0
	_exp_pop_label.offset_bottom = 88.0
	_exp_pop_label.add_theme_font_size_override("font_size", 11)
	_exp_pop_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 0.98))
	_exp_pop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exp_pop_label.text = "+0"
	_hud_panel.add_child(_exp_pop_label)
	_build_weapon_icon()
	# Shift existing nodes below EXP down
	if _build_identity:
		_build_identity.offset_top = 110
		_build_identity.offset_bottom = 126
		_build_identity.offset_left = 44
	if _earned_label:
		_earned_label.offset_top = 130
		_earned_label.offset_bottom = 144
	if _total_label:
		_total_label.offset_top = 146
		_total_label.offset_bottom = 162


func _build_weapon_icon() -> void:
	if not _hud_panel:
		return
	_weapon_icon = TextureRect.new()
	_weapon_icon.name = "WeaponIcon"
	_weapon_icon.custom_minimum_size = Vector2(28, 28)
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_icon.anchor_left = 0.0
	_weapon_icon.anchor_top = 0.0
	_weapon_icon.offset_left = 12.0
	_weapon_icon.offset_top = 108.0
	_weapon_icon.offset_right = 40.0
	_weapon_icon.offset_bottom = 136.0
	_hud_panel.add_child(_weapon_icon)


func _get_weapon_icon_texture(weapon_id: String) -> Texture2D:
	const SZ := 28
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var col: Color
	match weapon_id:
		"beam":
			col = Color(0.5, 0.85, 1.0)
			for y in SZ:
				for x in SZ:
					if abs(x - SZ/2) <= 3:
						img.set_pixel(x, y, col)
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
		"spread":
			col = Color(0.6, 0.8, 1.0)
			var cx := SZ / 2.0
			var cy := SZ / 2.0
			for y in SZ:
				for x in SZ:
					var a := atan2(y - cy, x - cx)
					if abs(a) <= 0.5 or abs(a - TAU) <= 0.5:
						img.set_pixel(x, y, col)
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
		"homing":
			col = Color(0.7, 0.6, 1.0)
			for y in SZ:
				for x in SZ:
					if Vector2(x - SZ/2.0, y - SZ/2.0).length() <= SZ/2.0 - 2:
						img.set_pixel(x, y, col)
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
		"burst":
			col = Color(0.9, 0.6, 0.4)
			var cx := SZ / 2.0
			var cy := SZ / 2.0
			for y in SZ:
				for x in SZ:
					if Vector2(x - cx, y - cy).length() <= 4:
						img.set_pixel(x, y, col)
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
		"drones":
			col = Color(0.4, 0.75, 0.95)
			var cx := SZ / 2.0
			var cy := SZ / 2.0
			for y in SZ:
				for x in SZ:
					var d := Vector2(x - cx, y - cy).length()
					if d >= 6 and d <= 10:
						img.set_pixel(x, y, col)
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
		"rear":
			col = Color(0.85, 0.5, 0.6)
			for y in SZ:
				for x in SZ:
					if x < SZ/2 and abs(y - SZ/2) <= 4:
						img.set_pixel(x, y, col)
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
		_:
			col = Color(0.5, 0.7, 0.95)
			for y in SZ:
				for x in SZ:
					if Vector2(x - SZ/2.0, y - SZ/2.0).length() <= SZ/2.0 - 2:
						img.set_pixel(x, y, col)
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _update_weapon_icon(weapon_id: String) -> void:
	if _weapon_icon:
		_weapon_icon.texture = _get_weapon_icon_texture(weapon_id)
		_weapon_icon.show()


func _update_build_identity(weapon_id: String) -> void:
	if not _build_identity:
		return
	var weapon_name: String = WEAPON_DISPLAY.get(weapon_id, weapon_id.capitalize())
	var subtitle: String = "—"
	if BuildVocabulary:
		subtitle = BuildVocabulary.get_weapon_display_desc(weapon_id)
		if subtitle.is_empty():
			var force: String = BuildVocabulary.get_weapon_force(weapon_id)
			subtitle = BuildVocabulary.FORCE_DISPLAY_NAMES.get(force, force.capitalize())
	_build_identity.text = "%s · %s" % [weapon_name, subtitle]
	if _weapon_icon:
		_update_weapon_icon(weapon_id)


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 2 != 0:
		return
	if _hp_label and _player and is_instance_valid(_player):
		if _player is PlayerController:
			var p: PlayerController = _player as PlayerController
			_hp_label.text = "HP %d / %d" % [p.current_hp, p.max_hp]
			if _hp_bar:
				_hp_bar.max_value = float(p.max_hp)
				_hp_bar.value = float(p.current_hp)
			if _exp_bar and _exp_level_label:
				_exp_bar.max_value = float(p.exp_to_next)
				_exp_bar.value = float(p.exp)
				_exp_level_label.text = "Lv.%d  EXP %d/%d" % [p.level, p.exp, p.exp_to_next]
	# Build identity from run weapon (fallback if run_started missed)
	if _build_identity and _build_identity.text == "—" and _stage_mgr:
		var wid: Variant = _stage_mgr.get("run_weapon_id")
		if wid is String and not (wid as String).is_empty():
			_update_build_identity(wid as String)
			_update_weapon_icon(wid as String)


func _on_upgrade_picked() -> void:
	if not _hud_panel:
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_hud_panel, "modulate", Color(1.15, 1.15, 1.1), 0.06)
	tween.tween_property(_hud_panel, "modulate", Color(1.0, 1.0, 1.0), 0.2)


func _on_player_damaged(_amount: int, _source: Node) -> void:
	if not _hud_panel:
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_hud_panel, "modulate", Color(1.0, 0.75, 0.8), 0.08)
	tween.tween_property(_hud_panel, "modulate", Color(1.0, 1.0, 1.0), 0.35)


func _on_boss_clear_show_cleared() -> void:
	_show_clear_label()
	_flash_boss_clear()


func _flash_boss_clear() -> void:
	var flash: ColorRect = get_node_or_null("BossClearFlash") as ColorRect
	if not flash:
		flash = ColorRect.new()
		flash.name = "BossClearFlash"
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.anchor_left = 0.0
		flash.anchor_top = 0.0
		flash.anchor_right = 1.0
		flash.anchor_bottom = 1.0
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.color = Color(0.6, 0.85, 1.0, 0.0)
		add_child(flash)
	flash.color = Color(0.7, 0.9, 1.0, 0.18)
	var tween := create_tween()
	tween.tween_property(flash, "color", Color(0.7, 0.9, 1.0, 0.0), 0.4)
	tween.tween_callback(func() -> void: flash.hide())


func _show_clear_label() -> void:
	if not _clear_label:
		_clear_label = Label.new()
		_clear_label.name = "BossClearLabel"
		_clear_label.text = "CLEAR"
		_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_clear_label.set_anchors_preset(Control.PRESET_CENTER)
		_clear_label.offset_left = -80
		_clear_label.offset_top = -24
		_clear_label.offset_right = 80
		_clear_label.offset_bottom = 24
		_clear_label.add_theme_font_size_override("font_size", 32)
		_clear_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		add_child(_clear_label)
	_clear_label.show()
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(_clear_label):
			_clear_label.hide()
	)


func _on_boss_reward_unlocked(_unlock_type: String, _unlock_id: String, display_name: String) -> void:
	var lbl: Label = get_node_or_null("BossUnlockedLabel") as Label
	if not lbl:
		lbl = Label.new()
		lbl.name = "BossUnlockedLabel"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
		lbl.offset_top = 80
		lbl.offset_left = -120
		lbl.offset_right = 120
		lbl.offset_bottom = 120
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.95))
		add_child(lbl)
	lbl.text = "Unlocked: %s" % display_name
	lbl.show()
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(lbl):
			lbl.hide()
	)
