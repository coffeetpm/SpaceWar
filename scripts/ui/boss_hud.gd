extends Control
## Boss fight UI: top center — boss name (large), long horizontal health bar. Clean neon line, thin glow.
## Shows on boss_spawned, hides on boss_despawned. Bar animates on damage, flashes on phase change.

@onready var _panel: Panel = $BossPanel
@onready var _name_label: Label = $BossPanel/NameLabel
@onready var _bar: ProgressBar = $BossPanel/HealthBar

var _boss: Node
var _max_hp: int = 1

func _ready() -> void:
	hide()
	if EventBus.has_signal("boss_spawned"):
		EventBus.boss_spawned.connect(_on_boss_spawned)
	if EventBus.has_signal("boss_despawned"):
		EventBus.boss_despawned.connect(_on_boss_despawned)
	if EventBus.has_signal("boss_hp_changed"):
		EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	if EventBus.has_signal("boss_phase_changed"):
		EventBus.boss_phase_changed.connect(_on_boss_phase_changed)


func _on_boss_spawned(boss: Node) -> void:
	_boss = boss
	var name_str := "BOSS"
	## 優先 BaseBoss 嘅 boss_name
	if boss.get("boss_name") != null and String(boss.get("boss_name")) != "":
		name_str = String(boss.get("boss_name"))
	elif boss is RefractionCore:
		name_str = RefractionCore.BOSS_DISPLAY_NAME
	elif boss.get("DISPLAY_NAME") != null:
		name_str = String(boss.get("DISPLAY_NAME"))
	## HP：BaseBoss 用 max_health；NeonTitan/RefractionCore 用 max_hp
	_max_hp = 400
	if boss.get("max_health") != null and int(boss.get("max_health")) > 0:
		_max_hp = int(boss.get("max_health"))
	elif boss.get("max_hp") != null and int(boss.get("max_hp")) > 0:
		_max_hp = int(boss.get("max_hp"))
	if _name_label:
		_name_label.text = name_str
	if _bar:
		_bar.max_value = float(_max_hp)
		_bar.value = float(_max_hp)
	if _panel:
		_panel.show()
		_panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	show()


func _on_boss_despawned() -> void:
	_boss = null
	var tween := create_tween()
	if _panel:
		tween.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void: hide())


func _on_boss_hp_changed(current: int, maximum: int) -> void:
	_max_hp = maximum
	if _bar:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_bar, "value", float(current), 0.15)


func _on_boss_phase_changed(_phase: int) -> void:
	if not _panel:
		return
	_panel.modulate = Color(1.12, 1.05, 0.95)
	var tween := create_tween()
	tween.tween_property(_panel, "modulate", Color(1, 1, 1), 0.35)
