extends Control
class_name SystemLab
## First interactive screen after intro. Light-based network: nodes connected by light lines.
## Inactive nodes dim; unlocked nodes pulse. Selecting a node lights the path; preview shows behaviour. Deploy highlights active config.

signal lab_closed
signal deploy_requested(weapon_id: String)

const PADDING := 20
const NODE_SIZE := Vector2(72, 52)
const NODE_GAP := 14
const LINE_DIM := Color(0.22, 0.5, 0.75, 0.2)
const LINE_LIT := Color(0.4, 0.85, 1.05, 0.75)
const LINE_ACTIVE := Color(0.5, 0.95, 1.0, 0.9)
const NODE_BG_DIM := Color(0.06, 0.08, 0.1, 0.85)
const NODE_BG_UNLOCKED := Color(0.08, 0.12, 0.18, 0.9)
const NODE_BG_SELECTED := Color(0.12, 0.22, 0.35, 0.95)
const NODE_BORDER_DIM := Color(0.2, 0.35, 0.5, 0.35)
const NODE_BORDER_UNLOCKED := Color(0.35, 0.7, 0.95, 0.5)
const NODE_BORDER_SELECTED := Color(0.5, 0.9, 1.1, 0.85)
const TEXT_DIM := Color(0.4, 0.6, 0.8, 0.5)
const TEXT_UNLOCKED := Color(0.55, 0.82, 1.0, 0.9)
const PULSE_SPEED := 0.9
const PREVIEW_WIDTH := 220

var _content: Control
var _currency_label: Label
var _starting_weapon_id: String = "spread"
var _pre_run: bool = false
var _network: _LabNetwork
var _preview_label: Label
var _deploy_btn: Button
var _node_by_id: Dictionary = {}
var _edges: Array[Array] = []  # [from_id, to_id]
var _pulse_time: float = 0.0
var _pre_run_panel: Control = null
var _display_settings_panel: Control = null


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Full-screen dark panel so lab is one clear screen, not floating rectangles.
	var bg := ColorRect.new()
	bg.name = "LabBackground"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.04, 0.06, 0.11, 0.96)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_ui()
	_build_pre_run_panel()


func _process(delta: float) -> void:
	_pulse_time += delta * PULSE_SPEED
	# Redraw network only when pulse phase changes noticeably to reduce flashing.
	if _network and Engine.get_process_frames() % 4 == 0:
		_network.queue_redraw()


func _build_ui() -> void:
	_content = Control.new()
	_content.name = "Content"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = PADDING
	_content.offset_top = PADDING
	_content.offset_right = -PADDING
	_content.offset_bottom = -PADDING
	add_child(_content)

	_currency_label = Label.new()
	_currency_label.name = "CurrencyLabel"
	_currency_label.add_theme_font_size_override("font_size", 18)
	_currency_label.add_theme_color_override("font_color", TEXT_UNLOCKED)
	_currency_label.text = _currency_text()
	_currency_label.anchor_left = 1.0
	_currency_label.anchor_top = 0.0
	_currency_label.offset_left = -180
	_currency_label.offset_top = 8
	_currency_label.offset_right = -16
	_currency_label.offset_bottom = 32
	_content.add_child(_currency_label)

	var network_rect := Control.new()
	network_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	network_rect.offset_left = 0
	network_rect.offset_top = 32
	network_rect.offset_right = -PREVIEW_WIDTH - 16
	network_rect.offset_bottom = -56
	_content.add_child(network_rect)

	_network = _LabNetwork.new()
	_network.name = "LabNetwork"
	_network.set_anchors_preset(Control.PRESET_FULL_RECT)
	_network.set_meta("lab", self)
	network_rect.add_child(_network)

	_node_by_id.clear()
	_edges.clear()

	# Deploy node (bottom center of network)
	var net_size := network_rect.get_rect().size
	if net_size.x <= 0:
		net_size = Vector2(400, 320)
	var deploy_pos := Vector2(net_size.x * 0.5 - NODE_SIZE.x * 0.5, net_size.y - NODE_SIZE.y - 8)
	_add_network_node("deploy", "Deploy", deploy_pos, true, true, false, _on_deploy_node_click.bind("deploy"))
	# Primary weapon nodes (row above deploy, only unlocked)
	var unlocked: Array = (SaveManager.get_unlocked_weapons() if SaveManager else []).duplicate()
	if unlocked.is_empty():
		unlocked.append("spread")
	var primary_count := unlocked.size()
	var primary_row_width := primary_count * (NODE_SIZE.x + NODE_GAP) - NODE_GAP
	var primary_start_x := net_size.x * 0.5 - primary_row_width * 0.5 + NODE_GAP * 0.5
	var primary_y := deploy_pos.y - NODE_SIZE.y - NODE_GAP - 8
	for i in range(unlocked.size()):
		var wid: String = unlocked[i]
		if SaveManager and not SaveManager.is_weapon_unlocked(wid):
			continue
		var px := primary_start_x + i * (NODE_SIZE.x + NODE_GAP)
		var nid := "primary_%s" % wid
		_add_network_node(nid, _weapon_display_name(wid), Vector2(px, primary_y), true, wid == _starting_weapon_id, false, _on_primary_node_click.bind(wid))
		_edges.append(["deploy", nid])

	# Tech spine: vertical line from left, nodes branch right
	var tech_y := 12.0
	var tech_left := 12.0
	var tech_node_x := tech_left + 28.0

	# First-lab choice: show 3 mechanics (Temporal Echo, Refraction Split, Orbit Drone) at 80 when pending
	var first_choice := SaveManager.is_first_lab_choice_pending() if SaveManager else false

	# Refraction (display: Refraction Split when first choice)
	var ref_unlocked: bool = SaveManager.is_refraction_unlocked() if SaveManager else false
	var ref_id := "refraction"
	var ref_name: String = "Refraction Split" if first_choice else "Refraction"
	var ref_cost: int = SaveManager.get_effective_first_choice_cost("refraction", "") if SaveManager and SaveManager.get_effective_first_choice_cost("refraction", "") >= 0 else (SaveManager.UNLOCK_COST_REFRACTION if SaveManager else 0)
	_add_network_node(ref_id, ref_name, Vector2(tech_node_x, tech_y), ref_unlocked, false, false, _on_unlock_click.bind(ref_id, ref_name, ref_cost, _unlock_refraction))
	_edges.append(["deploy", ref_id])
	tech_y += NODE_SIZE.y + NODE_GAP

	# Weapon archetypes (unlock); Orbit Drone System when first choice
	var weapon_ids: Array = SaveManager.ALL_WEAPON_IDS if SaveManager else ["spread"]
	for wid in weapon_ids:
		var u: bool = SaveManager.is_weapon_unlocked(wid) if SaveManager else false
		var uid := "weapon_%s" % wid
		var wname: String = "Orbit Drone System" if (first_choice and wid == "drones") else _weapon_display_name(wid)
		var wcost: int = SaveManager.get_effective_first_choice_cost("weapon", wid) if SaveManager and SaveManager.get_effective_first_choice_cost("weapon", wid) >= 0 else (SaveManager.UNLOCK_COST_WEAPON if SaveManager else 0)
		_add_network_node(uid, wname, Vector2(tech_node_x, tech_y), u, false, false, _on_unlock_click.bind(uid, wname, wcost, _unlock_weapon.bind(wid)))
		_edges.append(["deploy", uid])
		tech_y += NODE_SIZE.y + NODE_GAP * 0.6

	# Synergy; Temporal Echo when first choice
	var synergy_ids: Array = SaveManager.ALL_SYNERGY_EFFECT_IDS if SaveManager else []
	for sid in synergy_ids:
		var u: bool = SaveManager.is_synergy_effect_unlocked(sid) if SaveManager else false
		var lid := "synergy_%s" % sid
		var lab: String = "Temporal Echo" if (first_choice and sid == "afterimage") else sid.replace("_", " ").capitalize()
		var scost: int = SaveManager.get_effective_first_choice_cost("synergy", sid) if SaveManager and SaveManager.get_effective_first_choice_cost("synergy", sid) >= 0 else (SaveManager.UNLOCK_COST_SYNERGY if SaveManager else 0)
		_add_network_node(lid, lab, Vector2(tech_node_x, tech_y), u, false, false, _on_unlock_click.bind(lid, lab, scost, _unlock_synergy.bind(sid)))
		_edges.append(["deploy", lid])
		tech_y += NODE_SIZE.y + NODE_GAP * 0.6

	# Force
	var force_ids: Array = SaveManager.ALL_FORCE_PAIR_EFFECT_IDS if SaveManager else []
	for fid in force_ids:
		var u: bool = SaveManager.is_force_pair_effect_unlocked(fid) if SaveManager else false
		var fid2 := "force_%s" % fid
		var lab: String = fid.replace("_", " ").capitalize()
		_add_network_node(fid2, lab, Vector2(tech_node_x, tech_y), u, false, false, _on_unlock_click.bind(fid2, lab, SaveManager.UNLOCK_COST_FORCE_PAIR if SaveManager else 0, _unlock_force.bind(fid)))
		_edges.append(["deploy", fid2])
		tech_y += NODE_SIZE.y + NODE_GAP * 0.6

	# Magnet
	var mag_level: int = SaveManager.get_magnet_level() if SaveManager else 0
	var mag_unlocked := mag_level > 0 or (SaveManager and SaveManager.get_total_currency() >= SaveManager.UNLOCK_COST_MAGNET_PER_LEVEL)
	var mag_id := "magnet"
	_add_network_node(mag_id, "Magnet +%d" % (mag_level * int(SaveManager.MAGNET_RADIUS_PER_LEVEL) if SaveManager else 0), Vector2(tech_node_x, tech_y), mag_level >= SaveManager.MAGNET_MAX_LEVEL if SaveManager else false, false, mag_level < SaveManager.MAGNET_MAX_LEVEL if SaveManager else false, _on_magnet_click)
	_edges.append(["deploy", mag_id])
	tech_y += NODE_SIZE.y + NODE_GAP * 0.6

	# Starting energy
	var se_level: int = SaveManager.get_starting_energy_level() if SaveManager else 0
	var se_id := "starting_energy"
	_add_network_node(se_id, "Start +%d" % (SaveManager.get_starting_energy_bonus() if SaveManager else 0), Vector2(tech_node_x, tech_y), se_level >= SaveManager.STARTING_ENERGY_MAX_LEVEL if SaveManager else false, false, se_level < SaveManager.STARTING_ENERGY_MAX_LEVEL if SaveManager else false, _on_starting_energy_click)
	_edges.append(["deploy", se_id])

	_network.set_meta("edges", _edges)
	_network.set_meta("node_by_id", _node_by_id)
	_network.set_meta("selected_primary", _starting_weapon_id)
	_network.set_meta("pulse_time", _pulse_time)

	# Preview panel (right)
	var preview_panel := Panel.new()
	preview_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	preview_panel.anchor_left = 1.0
	preview_panel.offset_left = -PREVIEW_WIDTH - 8
	preview_panel.offset_top = 32
	preview_panel.offset_right = 8
	preview_panel.offset_bottom = -56
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.06, 0.09, 0.14, 0.92)
	pstyle.border_color = NODE_BORDER_UNLOCKED
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(0)
	pstyle.content_margin_left = 10
	pstyle.content_margin_top = 10
	pstyle.content_margin_right = 10
	pstyle.content_margin_bottom = 10
	preview_panel.add_theme_stylebox_override("panel", pstyle)
	_content.add_child(preview_panel)

	_preview_label = Label.new()
	_preview_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_label.offset_left = 12
	_preview_label.offset_top = 12
	_preview_label.offset_right = -12
	_preview_label.offset_bottom = -12
	_preview_label.add_theme_font_size_override("font_size", 13)
	_preview_label.add_theme_color_override("font_color", TEXT_UNLOCKED)
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.text = _preview_text_for_primary(_starting_weapon_id)
	preview_panel.add_child(_preview_label)

	_deploy_btn = Button.new()
	_deploy_btn.name = "DeployButton"
	_deploy_btn.text = "Deploy"
	_deploy_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_deploy_btn.anchor_left = 0.5
	_deploy_btn.anchor_right = 0.5
	_deploy_btn.anchor_top = 1.0
	_deploy_btn.anchor_bottom = 1.0
	_deploy_btn.offset_left = -90
	_deploy_btn.offset_top = -44
	_deploy_btn.offset_right = 90
	_deploy_btn.offset_bottom = -8
	_deploy_btn.pressed.connect(_on_deploy)
	_content.add_child(_deploy_btn)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	back.offset_left = -100
	back.offset_top = -44
	back.offset_right = -8
	back.offset_bottom = -8
	back.pressed.connect(_on_back)
	_content.add_child(back)

	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "Settings"
	settings_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	settings_btn.offset_left = 8
	settings_btn.offset_top = -44
	settings_btn.offset_right = 108
	settings_btn.offset_bottom = -8
	settings_btn.pressed.connect(_on_settings)
	_content.add_child(settings_btn)


func _build_pre_run_panel() -> void:
	_pre_run_panel = Control.new()
	_pre_run_panel.name = "PreRunPanel"
	_pre_run_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pre_run_panel.visible = false
	add_child(_pre_run_panel)
	var title := Label.new()
	title.name = "PreRunTitle"
	title.text = "System Lab"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", TEXT_UNLOCKED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.anchor_top = 0.0
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_top = 80
	title.offset_left = -200
	title.offset_right = 200
	title.offset_bottom = 120
	_pre_run_panel.add_child(title)
	var deploy_btn := Button.new()
	deploy_btn.name = "PreRunDeploy"
	deploy_btn.text = "Deploy"
	deploy_btn.add_theme_font_size_override("font_size", 24)
	deploy_btn.set_anchors_preset(Control.PRESET_CENTER)
	deploy_btn.offset_left = -100
	deploy_btn.offset_top = -28
	deploy_btn.offset_right = 100
	deploy_btn.offset_bottom = 28
	deploy_btn.pressed.connect(_on_deploy)
	_pre_run_panel.add_child(deploy_btn)


func _add_network_node(id: String, label_text: String, pos: Vector2, unlocked: bool, selected: bool, can_upgrade: bool, callback: Callable) -> void:
	var node := _LabNode.new()
	node.name = "Node_%s" % id
	node.set_meta("node_id", id)
	node.set_meta("unlocked", unlocked)
	node.set_meta("selected", selected)
	node.set_meta("can_upgrade", can_upgrade)
	node.set_meta("callback", callback)
	node.set_meta("lab", self)
	node.position = pos
	node.size = NODE_SIZE
	node.custom_minimum_size = NODE_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = NODE_BG_DIM
	style.border_color = NODE_BORDER_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	node.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", TEXT_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 4
	lbl.offset_top = 4
	lbl.offset_right = -4
	lbl.offset_bottom = -4
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(lbl)
	node.set_meta("label", lbl)
	_network.add_child(node)
	_node_by_id[id] = node
	node.gui_input.connect(_on_node_gui_input.bind(id, node, callback))
	node.mouse_entered.connect(_on_node_entered.bind(id))
	node.mouse_exited.connect(_on_node_exited)


func _on_node_gui_input(event: InputEvent, id: String, node: Control, callback: Callable) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			callback.call()


func _on_node_entered(id: String) -> void:
	_set_preview_for_node(id)


func _on_node_exited() -> void:
	if _preview_label and _starting_weapon_id:
		_preview_label.text = _preview_text_for_primary(_starting_weapon_id)


func _set_preview_for_node(id: String) -> void:
	if not _preview_label:
		return
	if id.begins_with("primary_"):
		_preview_label.text = _preview_text_for_primary(id.trim_prefix("primary_"))
	elif id == "deploy":
		_preview_label.text = "Deploy run with selected primary system.\n\nActive: %s" % _weapon_display_name(_starting_weapon_id)
	elif id == "refraction":
		var c: int = SaveManager.get_effective_first_choice_cost("refraction", "") if SaveManager and SaveManager.get_effective_first_choice_cost("refraction", "") >= 0 else (SaveManager.UNLOCK_COST_REFRACTION if SaveManager else 0)
		if SaveManager and SaveManager.is_first_lab_choice_pending():
			_preview_label.text = "Refraction Split.\nProjectiles create a second path — refracted, lethal. One choice opens the way.\nCost: %d" % c
		else:
			_preview_label.text = "Refraction Duplication.\nProjectiles create refracted echo paths (visual + functional).\nCost: %d" % c
	elif id.begins_with("weapon_"):
		var wid := id.trim_prefix("weapon_")
		var cost: int = SaveManager.get_effective_first_choice_cost("weapon", wid) if SaveManager and SaveManager.get_effective_first_choice_cost("weapon", wid) >= 0 else (SaveManager.UNLOCK_COST_WEAPON if SaveManager else 0)
		if wid == "drones" and SaveManager and SaveManager.is_first_lab_choice_pending():
			_preview_label.text = "Orbit Drone System.\nDeploy drones that orbit you; contact damage, space control. Yours to command.\nCost: %d" % cost
		else:
			_preview_label.text = "Unlock weapon: %s.\nCost: %d" % [_weapon_display_name(wid), cost]
	elif id.begins_with("synergy_"):
		var sid := id.trim_prefix("synergy_")
		var cost: int = SaveManager.get_effective_first_choice_cost("synergy", sid) if SaveManager and SaveManager.get_effective_first_choice_cost("synergy", sid) >= 0 else (SaveManager.UNLOCK_COST_SYNERGY if SaveManager else 0)
		if sid == "afterimage" and SaveManager and SaveManager.is_first_lab_choice_pending():
			_preview_label.text = "Temporal Echo.\nHits leave a delayed echo — a second impact, a ripple in time. Choose how time fights for you.\nCost: %d" % cost
		else:
			_preview_label.text = "Unlock synergy: %s.\nCost: %d" % [sid.replace("_", " ").capitalize(), cost]
	elif id.begins_with("force_"):
		var fid := id.trim_prefix("force_")
		_preview_label.text = "Unlock force pair: %s.\nCost: %d" % [fid.replace("_", " ").capitalize(), SaveManager.UNLOCK_COST_FORCE_PAIR if SaveManager else 0]
	elif id == "magnet":
		_preview_label.text = "Magnet: pickup radius +%d per level (max %d). Cost: %d" % [int(SaveManager.MAGNET_RADIUS_PER_LEVEL) if SaveManager else 0, SaveManager.MAGNET_MAX_LEVEL if SaveManager else 3, SaveManager.UNLOCK_COST_MAGNET_PER_LEVEL if SaveManager else 0]
	elif id == "starting_energy":
		_preview_label.text = "Starting energy: +%d fragments at run start. Cost: %d" % [SaveManager.get_starting_energy_bonus() if SaveManager else 0, SaveManager.UNLOCK_COST_STARTING_ENERGY if SaveManager else 0]
	else:
		_preview_label.text = _preview_text_for_primary(_starting_weapon_id)


func _preview_text_for_primary(wid: String) -> String:
	var desc: String
	match wid:
		"beam": desc = "Sustained beam."
		"spread": desc = "Wide spread shot."
		"drones": desc = "Deploy drones."
		"burst": desc = "Pulse burst."
		"homing": desc = "Homing projectiles."
		"rear": desc = "Rear fire."
		_: desc = "Primary system."
	return "Primary system: %s.\n%s" % [_weapon_display_name(wid), desc]


func _on_primary_node_click(wid: String) -> void:
	_starting_weapon_id = wid
	_preview_label.text = _preview_text_for_primary(wid)
	for nid in _node_by_id:
		var n: Control = _node_by_id[nid]
		if not nid.begins_with("primary_"):
			continue
		var sel: bool = nid == "primary_%s" % wid
		n.set_meta("selected", sel)
		var sty: StyleBoxFlat = n.get_theme_stylebox("panel") as StyleBoxFlat
		if sty:
			sty.border_color = NODE_BORDER_SELECTED if sel else NODE_BORDER_UNLOCKED
			sty.bg_color = NODE_BG_SELECTED if sel else NODE_BG_UNLOCKED
		var lbl: Label = n.get_meta("label", null)
		if lbl:
			lbl.add_theme_color_override("font_color", TEXT_UNLOCKED if sel else TEXT_DIM)
		n.queue_redraw()
	_network.set_meta("selected_primary", wid)
	_network.queue_redraw()


func _on_deploy_node_click(_id: String) -> void:
	# Deploy is a button; clicking it is handled by _deploy_btn. This is for the deploy *node* in the graph (visual only or trigger deploy).
	_on_deploy()


func _on_unlock_click(node_id: String, _label: String, cost: int, unlock_cb: Callable) -> void:
	var node: Control = _node_by_id.get(node_id, null)
	if not node:
		return
	if node.get_meta("unlocked", false):
		return
	if SaveManager and SaveManager.get_total_currency() >= cost:
		unlock_cb.call()
		_play_activation_effect(node_id, node)
	else:
		_set_preview_for_node(node_id)


func _play_activation_effect(node_id: String, target_node: Control) -> void:
	var deploy_node: Control = _node_by_id.get("deploy", null)
	if not deploy_node or not target_node or not _network:
		_refresh()
		return
	var from_global := deploy_node.global_position + deploy_node.size * 0.5
	var to_global := target_node.global_position + target_node.size * 0.5
	var overlay := _ActivationEffect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_meta("from_global", from_global)
	overlay.set_meta("to_global", to_global)
	overlay.set_meta("on_done", _refresh)
	add_child(overlay)


func _unlock_refraction() -> void:
	if SaveManager:
		SaveManager.unlock_refraction()


func _unlock_weapon(wid: String) -> void:
	if SaveManager:
		SaveManager.unlock_weapon(wid)


func _on_magnet_click() -> void:
	if SaveManager and SaveManager.get_magnet_level() < SaveManager.MAGNET_MAX_LEVEL and SaveManager.get_total_currency() >= SaveManager.UNLOCK_COST_MAGNET_PER_LEVEL:
		SaveManager.unlock_magnet_level()
		_refresh()


func _on_starting_energy_click() -> void:
	if SaveManager and SaveManager.get_starting_energy_level() < SaveManager.STARTING_ENERGY_MAX_LEVEL and SaveManager.get_total_currency() >= SaveManager.UNLOCK_COST_STARTING_ENERGY:
		SaveManager.unlock_starting_energy()
		_refresh()


func _currency_text() -> String:
	if not SaveManager:
		return "Energy Fragments: 0"
	return "%s: %d" % [SaveManager.CURRENCY_DISPLAY_NAME, SaveManager.get_total_currency()]


func _weapon_display_name(wid: String) -> String:
	match wid:
		"beam": return "Beam"
		"spread": return "Spread"
		"drones": return "Drones"
		"burst": return "Pulse"
		"homing": return "Homing"
		"rear": return "Rear"
	return wid.capitalize()


func _unlock_synergy(sid: String) -> void:
	if SaveManager:
		SaveManager.unlock_synergy_effect(sid)


func _unlock_force(fid: String) -> void:
	if SaveManager:
		SaveManager.unlock_force_pair_effect(fid)


func _refresh() -> void:
	if _content:
		_content.queue_free()
		_content = null
	_currency_label = null
	_network = null
	_preview_label = null
	_deploy_btn = null
	_node_by_id.clear()
	_build_ui()
	if _currency_label:
		_currency_label.text = _currency_text()
	# Restore preview to primary
	if _preview_label:
		_preview_label.text = _preview_text_for_primary(_starting_weapon_id)


func _on_back() -> void:
	hide()
	lab_closed.emit()


func _on_settings() -> void:
	if not _display_settings_panel:
		_display_settings_panel = preload("res://scripts/ui/display_settings_panel.gd").new()
		_display_settings_panel.closed.connect(_on_display_settings_closed)
		add_child(_display_settings_panel)
	_display_settings_panel.show()


func _on_display_settings_closed() -> void:
	if _display_settings_panel:
		_display_settings_panel.hide()


func _on_deploy() -> void:
	deploy_requested.emit(_starting_weapon_id)


func show_lab(pre_run: bool = false) -> void:
	_pre_run = pre_run
	_starting_weapon_id = _get_default_starting_weapon()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1152, 648)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = vp_size
	size = vp_size
	var bg: ColorRect = get_node_or_null("LabBackground") as ColorRect
	if bg:
		bg.size = vp_size
		bg.position = Vector2.ZERO
	if pre_run and _pre_run_panel:
		_content.visible = false
		_pre_run_panel.visible = true
	else:
		_refresh()
		_content.visible = true
		if _pre_run_panel:
			_pre_run_panel.visible = false
	var back_btn: Control = _content.get_node_or_null("BackButton")
	if back_btn:
		back_btn.visible = not pre_run
	show()


func _get_default_starting_weapon() -> String:
	var unlocked: Array = SaveManager.get_unlocked_weapons() if SaveManager else []
	if unlocked.is_empty():
		return "spread"
	if _starting_weapon_id in unlocked:
		return _starting_weapon_id
	return unlocked[0] if unlocked.size() > 0 else "spread"


# ---- Inner: unlock activation effect (energy line, node glow, pulse, harmonic ring) ----
class _ActivationEffect:
	extends Control
	## Powering-on feel: lines connect, node lights up, subtle pulse, short harmonic glow. No explosion.
	const DURATION := 0.7
	const LINE_GROW_TIME := 0.22
	const PULSE_PEAK := 0.28
	const RING_GROW_TIME := 0.48
	const RING_MAX_R := 48.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= DURATION:
			var on_done: Callable = get_meta("on_done", Callable())
			if on_done.is_valid():
				on_done.call()
			queue_free()

	func _draw() -> void:
		var from_global: Vector2 = get_meta("from_global", Vector2.ZERO)
		var to_global: Vector2 = get_meta("to_global", Vector2.ZERO)
		var inv := get_global_transform_with_canvas().affine_inverse()
		var from_local: Vector2 = inv * from_global
		var to_local: Vector2 = inv * to_global

		# 1) Energy line connects (grows from deploy to node)
		var line_progress: float = clampf(_t / LINE_GROW_TIME, 0.0, 1.0)
		line_progress = 1.0 - (1.0 - line_progress) * (1.0 - line_progress)
		var line_end := from_local.lerp(to_local, line_progress)
		var line_alpha: float = 0.42 + 0.25 * (1.0 - clampf(_t / 0.4, 0.0, 1.0))
		var line_col := Color(0.35, 0.78, 0.98, line_alpha)
		draw_line(from_local, line_end, line_col)

		# 2) Node lights up + 3) subtle system pulse (soft rise, hold, gentle fade)
		var node_alpha: float = 0.0
		if _t >= LINE_GROW_TIME * 0.4:
			var pulse_t := (_t - LINE_GROW_TIME * 0.4) / (PULSE_PEAK - LINE_GROW_TIME * 0.4)
			pulse_t = clampf(pulse_t, 0.0, 1.0)
			node_alpha = sin(pulse_t * PI)
			if _t > PULSE_PEAK:
				var fade := clampf((_t - PULSE_PEAK) / (DURATION - PULSE_PEAK), 0.0, 1.0)
				node_alpha = 0.65 + 0.2 * (1.0 - fade)
		var node_r := 36.0 + 3.0 * sin(_t * 10.0) if _t < PULSE_PEAK else 37.0
		var border_col := Color(0.42, 0.85, 1.0, node_alpha * 0.85)
		var fill_col := Color(0.08, 0.18, 0.3, node_alpha * 0.75)
		draw_arc(to_local, node_r, 0.0, TAU, 24, border_col)
		draw_arc(to_local, node_r - 1.5, 0.0, TAU, 24, fill_col)

		# 4) Short harmonic glow (expanding ring, smooth fade)
		if _t >= 0.1:
			var ring_t := (_t - 0.1) / RING_GROW_TIME
			ring_t = clampf(ring_t, 0.0, 1.0)
			var r := ring_t * RING_MAX_R
			var ring_alpha := 0.28 * (1.0 - ring_t) * (1.0 - ring_t)
			if ring_alpha > 0.002:
				var ring_col := Color(0.38, 0.78, 0.98, ring_alpha)
				draw_arc(to_local, r, 0.0, TAU, 32, ring_col)


# ---- Inner: network canvas (draws light lines + hosts nodes) ----
class _LabNetwork:
	extends Control
	func _draw() -> void:
		var lab: SystemLab = get_meta("lab", null)
		if not lab:
			return
		var edges: Array = get_meta("edges", [])
		var node_by_id: Dictionary = get_meta("node_by_id", {})
		var selected_primary: String = get_meta("selected_primary", "")
		var pulse_time: float = lab._pulse_time if lab else 0.0
		var pulse: float = 0.5 + 0.35 * sin(pulse_time)
		for edge in edges:
			var from_id: String = edge[0]
			var to_id: String = edge[1]
			var from_n: Control = node_by_id.get(from_id, null)
			var to_n: Control = node_by_id.get(to_id, null)
			if not from_n or not to_n:
				continue
			var a: Vector2 = from_n.position + from_n.size * 0.5
			var b: Vector2 = to_n.position + to_n.size * 0.5
			var lit: bool = (to_id == "deploy" and from_id == "primary_%s" % selected_primary) or (from_id == "deploy" and to_id == "primary_%s" % selected_primary)
			var col: Color
			if lit:
				col = LINE_ACTIVE
			else:
				var to_unlocked: bool = to_n.get_meta("unlocked", false)
				col = LINE_DIM.lerp(LINE_LIT, pulse * 0.5 if to_unlocked else 0.0)
			draw_line(a, b, col)
		# Spine line (left tech column)
		var tech_y_min := 12.0
		var tech_y_max := size.y - 60.0
		if tech_y_max > tech_y_min:
			var spine_col: Color = LINE_DIM.lerp(LINE_LIT, pulse * 0.4)
			draw_line(Vector2(24, tech_y_min + 26), Vector2(24, tech_y_max), spine_col)


# ---- Inner: single node (panel with pulse when unlocked) ----
class _LabNode:
	extends Panel
	func _process(_delta: float) -> void:
		var lab: SystemLab = get_meta("lab", null)
		if not lab:
			return
		var unlocked: bool = get_meta("unlocked", false)
		var selected: bool = get_meta("selected", false)
		var sty: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
		if not sty:
			return
		# Softer, slower pulse so it doesn’t look like constant flashing.
		var pulse: float = 0.5 + 0.2 * sin(lab._pulse_time * 1.2) if unlocked else 0.0
		if selected:
			sty.border_color = NODE_BORDER_SELECTED
			sty.bg_color = NODE_BG_SELECTED
		elif unlocked:
			sty.border_color = NODE_BORDER_UNLOCKED.lerp(NODE_BORDER_SELECTED, pulse * 0.2)
			sty.bg_color = NODE_BG_UNLOCKED.lerp(NODE_BG_SELECTED, pulse * 0.08)
		else:
			sty.border_color = NODE_BORDER_DIM
			sty.bg_color = NODE_BG_DIM
		# Redraw only every few frames to reduce flicker.
		if Engine.get_process_frames() % 3 == 0:
			queue_redraw()
