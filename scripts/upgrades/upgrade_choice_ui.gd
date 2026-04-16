extends Control
class_name UpgradeChoiceUI
## Upgrade selection preserves flow: world slows, does not stop.
## Choices appear as light constructs; minimal UI framing; selection feels like tuning energy.
## Quick decision encouraged — no hard pause.

signal upgrade_selected(upgrade: UpgradeData)
signal upgrade_chosen(upgrade_resource: Resource)
## For VFX: card center in screen/UI coordinates when a choice is committed.
signal upgrade_selected_for_vfx(screen_center: Vector2)

@export var choice_container: Container
@export var choice_button_scene: PackedScene

const HINT_COLOR := Color(0.7, 0.8, 0.95, 0.75)
const OVERLAY_FADE_IN := 0.12
const CARD_STAGGER := 0.06
const SELECT_CONFIRM_DELAY := 0.08
const EXIT_FADE := 0.14

var _current_choices: Array[UpgradeData] = []
var _cards: Array[UpgradeCard] = []
var _focused_card: UpgradeCard = null
var _overlay_dim: ColorRect
var _overlay_glow: ColorRect
var _cards_container: Control
var _exiting: bool = false


func _ready() -> void:
	hide()
	modulate.a = 0.0
	if not choice_container:
		choice_container = get_node_or_null("ChoiceContainer") as Container
	_build_overlay()
	EventBus.upgrade_choice_requested.connect(_on_choices_requested)


func _build_overlay() -> void:
	_overlay_dim = ColorRect.new()
	_overlay_dim.name = "OverlayDim"
	_overlay_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_dim.anchor_left = 0.0
	_overlay_dim.anchor_right = 1.0
	_overlay_dim.anchor_top = 0.0
	_overlay_dim.anchor_bottom = 1.0
	_overlay_dim.offset_left = -400
	_overlay_dim.offset_top = -400
	_overlay_dim.offset_right = 2000
	_overlay_dim.offset_bottom = 2000
	_overlay_dim.color = Color(0.04, 0.06, 0.12, 0.62)
	_overlay_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_dim)
	move_child(_overlay_dim, 0)
	_overlay_glow = ColorRect.new()
	_overlay_glow.name = "OverlayGlow"
	_overlay_glow.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_glow.anchor_left = 0.5
	_overlay_glow.anchor_right = 0.5
	_overlay_glow.anchor_top = 0.5
	_overlay_glow.anchor_bottom = 0.5
	_overlay_glow.offset_left = -320
	_overlay_glow.offset_top = -200
	_overlay_glow.offset_right = 320
	_overlay_glow.offset_bottom = 200
	_overlay_glow.color = Color(0.35, 0.6, 0.9, 0.06)
	_overlay_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_glow)
	move_child(_overlay_glow, 1)


func _input(event: InputEvent) -> void:
	if not visible or _current_choices.is_empty() or _cards.is_empty():
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		# 1/2/3 keys: direct pick
		var idx: int = -1
		if ke.keycode == KEY_1 or ke.keycode == KEY_KP_1:
			idx = 0
		elif ke.keycode == KEY_2 or ke.keycode == KEY_KP_2:
			idx = 1
		elif ke.keycode == KEY_3 or ke.keycode == KEY_KP_3:
			idx = 2
		if idx >= 0 and idx < _current_choices.size():
			_pick_choice_by_index(idx)
			get_viewport().set_input_as_handled()
			return
		# move_left / move_right: change focus across cards
		if Input.is_action_just_pressed("move_left"):
			_focus_prev_card()
			get_viewport().set_input_as_handled()
			return
		if Input.is_action_just_pressed("move_right"):
			_focus_next_card()
			get_viewport().set_input_as_handled()
			return
		# move_up / move_down: confirm selection (same as click)
		if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
			if _focused_card:
				_commit_selection(_focused_card)
			get_viewport().set_input_as_handled()


func _focus_index() -> int:
	for i in _cards.size():
		if _cards[i] == _focused_card:
			return i
	return 0


func _focus_prev_card() -> void:
	if _cards.is_empty() or _exiting:
		return
	var i := _focus_index()
	i = (i - 1 + _cards.size()) % _cards.size()
	set_focused_card(_cards[i])


func _focus_next_card() -> void:
	if _cards.is_empty() or _exiting:
		return
	var i := _focus_index()
	i = (i + 1) % _cards.size()
	set_focused_card(_cards[i])


func _pick_choice_by_index(idx: int) -> void:
	if idx < 0 or idx >= _current_choices.size() or _exiting:
		return
	if idx >= _cards.size():
		return
	var card: UpgradeCard = _cards[idx]
	set_focused_card(card)
	_commit_selection(card)


func _on_card_selected(upgrade: UpgradeData) -> void:
	if _exiting:
		return
	var card: UpgradeCard = null
	for c in _cards:
		if c.upgrade_data == upgrade:
			card = c
			break
	if card:
		_commit_selection(card)


func _commit_selection(card: UpgradeCard) -> void:
	if _exiting:
		return
	_exiting = true
	var chosen: UpgradeData = card.upgrade_data
	card.play_select()
	# Other cards fade out quickly
	for c in _cards:
		if c != card:
			var t := c.create_tween()
			t.set_ease(Tween.EASE_OUT)
			t.tween_property(c, "modulate:a", 0.0, 0.12)
	# Brief visual confirm then apply and exit
	await get_tree().create_timer(SELECT_CONFIRM_DELAY).timeout
	if not is_instance_valid(self):
		return
	var card_center: Vector2 = card.get_global_rect().get_center()
	upgrade_selected_for_vfx.emit(card_center)
	upgrade_selected.emit(chosen)
	upgrade_chosen.emit(chosen as Resource)
	# StageManager may hide us immediately; skip exit tween if already hidden to avoid extra work/lag
	if not visible:
		return
	var exit_tween := create_tween()
	exit_tween.set_ease(Tween.EASE_OUT)
	if _overlay_dim:
		exit_tween.parallel().tween_property(_overlay_dim, "modulate:a", 0.0, EXIT_FADE)
	if _overlay_glow:
		exit_tween.parallel().tween_property(_overlay_glow, "modulate:a", 0.0, EXIT_FADE)
	exit_tween.parallel().tween_property(self, "modulate:a", 0.0, EXIT_FADE)
	await exit_tween.finished
	if is_instance_valid(self):
		hide()


func _on_choices_requested(choices: Array) -> void:
	_exiting = false
	_current_choices.clear()
	_cards.clear()
	_focused_card = null
	for c in choices:
		if c is UpgradeData:
			_current_choices.append(c)
	_populate_ui()
	# Overlay starts dimmed
	if _overlay_dim:
		_overlay_dim.modulate.a = 0.0
	if _overlay_glow:
		_overlay_glow.modulate.a = 0.0
	modulate.a = 0.0
	show()
	# Overlay entrance: dim + center glow + self fade in 0.12s
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	if _overlay_dim:
		t.parallel().tween_property(_overlay_dim, "modulate:a", 1.0, OVERLAY_FADE_IN)
	if _overlay_glow:
		t.parallel().tween_property(_overlay_glow, "modulate:a", 1.0, OVERLAY_FADE_IN)
	t.parallel().tween_property(self, "modulate:a", 1.0, OVERLAY_FADE_IN)


func _populate_ui() -> void:
	if not choice_container:
		return
	for child in choice_container.get_children():
		child.queue_free()
	_cards.clear()
	var existing := get_node_or_null("FlowHint")
	if existing:
		existing.queue_free()
	for i in _current_choices.size():
		var choice: UpgradeData = _current_choices[i]
		var card := UpgradeCard.new()
		card.setup(choice, self)
		card.card_selected.connect(_on_card_selected)
		choice_container.add_child(card)
		_cards.append(card)
	call_deferred("_start_card_entrances")
	# Initial focus on first card
	call_deferred("_set_initial_focus")


func _start_card_entrances() -> void:
	for i in _cards.size():
		_cards[i].play_enter(i * CARD_STAGGER)
	var hint := _make_hint_label()
	if hint:
		hint.name = "FlowHint"
		hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		hint.offset_top = -28
		hint.offset_bottom = -8
		add_child(hint)


func _set_initial_focus() -> void:
	if _cards.size() > 0:
		set_focused_card(_cards[0])


func set_focused_card(card: UpgradeCard) -> void:
	if _focused_card == card:
		return
	if _focused_card:
		_focused_card.set_focused(false)
	_focused_card = card
	if _focused_card:
		_focused_card.set_focused(true)


func clear_focused_card(_card: UpgradeCard) -> void:
	if _focused_card:
		_focused_card.set_focused(false)
		_focused_card = null


func _make_hint_label() -> Control:
	var label := Label.new()
	label.name = "FlowHint"
	label.text = "← → focus  ·  ↑ ↓ or click — select"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", HINT_COLOR)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	return label
