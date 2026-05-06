extends CanvasLayer
class_name BossWarning
## Boss 進場警報：紅色全螢幕閃兩下 + 大型 "BOSS" 字樣 + 名稱 + bass boost + WorldEnvironment glow pulse。
## 使用方式：
##   var w := BossWarning.spawn(get_tree().current_scene, "NEON TANK")
## 或者由 EventBus.boss_warning_requested 觸發（預先 add 到 main.tscn 或 autoload 監聽）。
## 會喺 duration 秒後自動 queue_free。

@export var duration: float = 2.2
@export var flash_count: int = 2
## 進場時 WorldEnvironment glow pulse 倍數
@export var glow_pulse_scale: float = 1.8

var _bg: ColorRect
var _title: Label
var _name_label: Label
var _world_env: WorldEnvironment
var _base_glow_intensity: float = 1.0


static func spawn(parent: Node, boss_name: String, dur: float = 2.2) -> BossWarning:
	var w: BossWarning = BossWarning.new()
	w.duration = dur
	parent.add_child(w)
	w.call_deferred("_play", boss_name)
	return w


func _ready() -> void:
	layer = 100  ## 頂層
	_build_ui()
	if EventBus and EventBus.has_signal("boss_warning_requested"):
		EventBus.boss_warning_requested.connect(_on_warning_requested)


func _on_warning_requested(boss_name: String, dur: float) -> void:
	## 如果被 autoload 式使用（只得一個常駐實例），可由 EventBus 觸發。
	duration = dur if dur > 0.0 else duration
	_play(boss_name)


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.9, 0.1, 0.15, 0.0)
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_title = Label.new()
	_title.text = "!! BOSS APPROACHING !!"
	_title.add_theme_font_size_override("font_size", 56)
	_title.add_theme_color_override("font_color", Color(2.5, 1.2, 1.2, 1.0))
	_title.anchor_left = 0.0
	_title.anchor_right = 1.0
	_title.anchor_top = 0.35
	_title.anchor_bottom = 0.35
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_name_label = Label.new()
	_name_label.text = ""
	_name_label.add_theme_font_size_override("font_size", 36)
	_name_label.add_theme_color_override("font_color", Color(3.5, 2.0, 3.5, 1.0))
	_name_label.anchor_left = 0.0
	_name_label.anchor_right = 1.0
	_name_label.anchor_top = 0.5
	_name_label.anchor_bottom = 0.5
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.modulate.a = 0.0
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)


func _play(boss_name: String) -> void:
	_name_label.text = boss_name
	_capture_world_env()
	_pulse_glow()
	_boost_bass()
	## 紅光閃 N 次
	var per_flash: float = 0.22
	var tween := create_tween()
	for i in flash_count:
		tween.tween_property(_bg, "color:a", 0.55, per_flash)
		tween.tween_property(_bg, "color:a", 0.0, per_flash)
	## 文字淡入
	var text_tween := create_tween()
	text_tween.tween_interval(0.15)
	text_tween.parallel().tween_property(_title, "modulate:a", 1.0, 0.3)
	text_tween.parallel().tween_property(_name_label, "modulate:a", 1.0, 0.4)
	## 維持然後淡出
	var fade_tween := create_tween()
	fade_tween.tween_interval(duration - 0.4)
	fade_tween.parallel().tween_property(_title, "modulate:a", 0.0, 0.35)
	fade_tween.parallel().tween_property(_name_label, "modulate:a", 0.0, 0.35)
	fade_tween.parallel().tween_property(_bg, "color:a", 0.0, 0.35)
	fade_tween.tween_callback(_restore_world_env)
	fade_tween.tween_callback(queue_free)


func _capture_world_env() -> void:
	var roots := get_tree().get_nodes_in_group("world_environment")
	if roots.is_empty():
		## 向 main scene 搵第一個 WorldEnvironment
		_world_env = _find_world_env(get_tree().current_scene)
	else:
		_world_env = roots[0] as WorldEnvironment
	if _world_env and _world_env.environment:
		_base_glow_intensity = _world_env.environment.glow_intensity


func _find_world_env(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n
	for c in n.get_children():
		var r := _find_world_env(c)
		if r:
			return r
	return null


func _pulse_glow() -> void:
	if not _world_env or not _world_env.environment:
		return
	var env: Environment = _world_env.environment
	var peak: float = _base_glow_intensity * glow_pulse_scale
	var tween := create_tween()
	tween.tween_property(env, "glow_intensity", peak, 0.25)
	tween.tween_property(env, "glow_intensity", _base_glow_intensity * 1.15, 0.35)
	tween.tween_property(env, "glow_intensity", peak * 0.9, 0.2)
	tween.tween_property(env, "glow_intensity", _base_glow_intensity, 0.45)


func _restore_world_env() -> void:
	if _world_env and _world_env.environment:
		_world_env.environment.glow_intensity = _base_glow_intensity


# =============================================================================
# Bass boost（AudioServer global bus EQ / filter）
# =============================================================================

func _boost_bass() -> void:
	var bus_name: String = "Music"
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		bus_idx = 0  ## fallback 到 Master
	## 暫時加一個 low-shelf boost
	var eq := AudioEffectEQ.new()
	eq.set_band_gain_db(0, 8.0)   ## 32Hz
	eq.set_band_gain_db(1, 6.0)   ## 100Hz
	var slot: int = AudioServer.get_bus_effect_count(bus_idx)
	AudioServer.add_bus_effect(bus_idx, eq)
	## duration 秒後移除
	get_tree().create_timer(duration * 1.2).timeout.connect(func() -> void:
		var cnt: int = AudioServer.get_bus_effect_count(bus_idx)
		for i in range(cnt - 1, -1, -1):
			var fx: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
			if fx == eq:
				AudioServer.remove_bus_effect(bus_idx, i)
				break
	)
