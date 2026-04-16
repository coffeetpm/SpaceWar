extends Node2D
## Flow: intro activation → pre-run screen (Deploy) → run. System Lab (full) only from Game Over.
## Pre-run uses a simple overlay built here so it always displays; full Lab is for meta progression.

const PRE_RUN_OVERLAY_LAYER := 300

var _player: Node2D
var _camera: Camera2D
var _system_lab: SystemLab
var _world: Node2D
var _pre_run_overlay: CanvasLayer = null

func _ready() -> void:
	_apply_ui_scale()
	var ds: Node = get_node_or_null("/root/DisplaySettings")
	if ds and ds.has_signal("settings_changed"):
		ds.settings_changed.connect(_apply_ui_scale)
	EventBus.game_over.connect(_on_game_over)
	EventBus.sound_kill_requested.connect(_on_kill_sound)
	_world = get_node_or_null("World") as Node2D
	_player = get_node_or_null("World/Player") as Node2D
	_camera = get_node_or_null("Camera2D") as Camera2D
	if _camera:
		_camera.make_current()
	_ensure_system_lab()
	if RunState and RunState.quick_restart:
		RunState.quick_restart = false
		_set_world_active(true)
		var stage_mgr: Node = get_node_or_null("World/StageManager")
		if stage_mgr:
			stage_mgr.set("run_weapon_id", RunState.last_weapon_id)
			if stage_mgr.has_method("start_game"):
				stage_mgr.start_game()
		_hide_weapon_select()
	else:
		_set_world_active(false)
		_hide_weapon_select()
		_run_intro_then_lab()


func _ensure_system_lab() -> void:
	var ui: Control = get_node_or_null("UI") as Control
	if not ui:
		return
	_system_lab = ui.get_node_or_null("SystemLab") as SystemLab
	if not _system_lab or not is_instance_valid(_system_lab):
		_system_lab = SystemLab.new()
		_system_lab.name = "SystemLab"
		_system_lab.visible = false
		ui.add_child(_system_lab)
	if _system_lab and _system_lab.has_signal("deploy_requested") and not _system_lab.deploy_requested.is_connected(_on_lab_deploy):
		_system_lab.deploy_requested.connect(_on_lab_deploy)


func _on_lab_deploy(weapon_id: String) -> void:
	# Single deploy: ignore if run already active (prevents repeated SystemLab from double-click or duplicate signals).
	if RunState and RunState.run_active:
		return
	_set_world_active(true)
	var stage_mgr: Node = get_node_or_null("World/StageManager")
	if stage_mgr and stage_mgr.get("run_weapon_id") != null:
		stage_mgr.set("run_weapon_id", weapon_id)
	if stage_mgr and stage_mgr.has_method("start_game"):
		stage_mgr.start_game()
	if _system_lab and is_instance_valid(_system_lab):
		_system_lab.hide()
	var game_over: Control = get_node_or_null("UI/GameOver") as Control
	if game_over:
		game_over.hide()


func _hide_weapon_select() -> void:
	var ws: Control = get_node_or_null("UI/WeaponSelect") as Control
	if ws:
		ws.hide()


func _set_world_active(active: bool) -> void:
	if not _world:
		return
	_world.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_world.visible = active
	var hud: Control = get_node_or_null("UI/HUD") as Control
	if hud:
		hud.visible = active


func _run_intro_then_lab() -> void:
	var intro: CanvasLayer = get_node_or_null("ActivationIntro") as CanvasLayer
	if intro and intro.has_signal("intro_finished") and intro.has_method("run_intro"):
		intro.run_intro()
		if not intro.intro_finished.is_connected(_show_lab_after_intro):
			intro.intro_finished.connect(_show_lab_after_intro)
		# Fallback: if lab still not visible after 8s (e.g. signal missed), show it.
		get_tree().create_timer(8.0).timeout.connect(_fallback_show_lab, CONNECT_ONE_SHOT)
	else:
		_show_lab_after_intro()


func _show_lab_after_intro() -> void:
	if SaveManager:
		SaveManager.mark_intro_completed()
		SaveManager.grant_first_lab_currency()
	var intro: CanvasLayer = get_node_or_null("ActivationIntro") as CanvasLayer
	if intro:
		intro.queue_free()
	# Show our own pre-run overlay (no dependency on SystemLab UI). Always works.
	get_tree().create_timer(0.2).timeout.connect(_show_pre_run_overlay, CONNECT_ONE_SHOT)


func _show_pre_run_overlay() -> void:
	# Show System Lab only when not yet in a run (single source of truth: lab visible only in pre-run).
	if RunState and RunState.run_active:
		return
	if _system_lab and is_instance_valid(_system_lab):
		_system_lab.show()
		return
	# Fallback: minimal overlay with Deploy (default weapon) if System Lab missing
	if _pre_run_overlay and is_instance_valid(_pre_run_overlay):
		return
	_pre_run_overlay = CanvasLayer.new()
	_pre_run_overlay.name = "PreRunOverlay"
	_pre_run_overlay.layer = PRE_RUN_OVERLAY_LAYER
	add_child(_pre_run_overlay)
	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 0
	bg.offset_top = 0
	bg.offset_right = 0
	bg.offset_bottom = 0
	bg.color = Color(0.05, 0.07, 0.12, 0.98)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pre_run_overlay.add_child(bg)
	bg.size = vp_rect.size
	bg.position = vp_rect.position
	var title := Label.new()
	title.text = "System Lab"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 1.0))
	title.position = Vector2(vp_rect.size.x * 0.5 - 200, 100)
	title.size = Vector2(400, 80)
	_pre_run_overlay.add_child(title)
	var deploy_btn := Button.new()
	deploy_btn.text = "Deploy"
	deploy_btn.add_theme_font_size_override("font_size", 28)
	deploy_btn.size = Vector2(200, 56)
	deploy_btn.position = Vector2(vp_rect.size.x * 0.5 - 100, vp_rect.size.y * 0.5 - 28)
	deploy_btn.pressed.connect(_on_pre_run_deploy)
	_pre_run_overlay.add_child(deploy_btn)


func _on_pre_run_deploy() -> void:
	if _pre_run_overlay and is_instance_valid(_pre_run_overlay):
		_pre_run_overlay.queue_free()
		_pre_run_overlay = null
	if _system_lab and _system_lab.visible:
		_system_lab.hide()
	_on_lab_deploy("spread")


func _fallback_show_lab() -> void:
	# Do not show lab if run is already active (e.g. user deployed before 8s).
	if RunState and RunState.run_active:
		return
	if _pre_run_overlay == null or not is_instance_valid(_pre_run_overlay):
		_show_pre_run_overlay()


func _on_kill_sound() -> void:
	var s := get_node_or_null("KillSound") as AudioStreamPlayer2D
	if s:
		s.play()




## Camera follow is handled by CameraShake on Camera2D (smooth follow + look-ahead).




func _apply_ui_scale() -> void:
	var ds: Node = get_node_or_null("/root/DisplaySettings")
	if not ds:
		return
	var ui_layer: CanvasLayer = get_node_or_null("UI") as CanvasLayer
	if ui_layer:
		var scale_val: float = float(ds.get("ui_scale"))
		ui_layer.scale = Vector2(scale_val, scale_val)


func _on_game_over() -> void:
	# RunEndMenu shows itself and records run on EventBus.game_over
	pass
