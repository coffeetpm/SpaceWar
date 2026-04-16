extends Node
## Tetris Effect–style emotional feedback: the world reacts to player actions.
## Not louder — more expressive. Emotion stays in atmosphere layer; gameplay clarity always priority.
## States: calm, tension, release, focus. Smooth transitions.

enum Emotion { CALM, TENSION, RELEASE, FOCUS }

const LAYER_EMOTION := -202
const LERP_SPEED := 2.0
const TENSION_DURATION := 6.0
const RELEASE_DURATION_BUILD := 2.0
const RELEASE_DURATION_STAGE := 2.0
const RELEASE_DURATION_BOSS := 3.0
const FOCUS_DURATION := 1.0

# Per-state: tint (RGB + alpha for overlay), breath intensity, shimmer (distant particles), pulse (env wave)
var _params: Dictionary = {
	Emotion.CALM:   { "tint": Color(1.0, 1.0, 1.0, 0.0),   "breath": 1.0,  "shimmer": 0.0,  "pulse": 0.0 },
	Emotion.TENSION: { "tint": Color(0.98, 0.92, 0.95, 0.03), "breath": 1.12, "shimmer": 0.25, "pulse": 0.15 },
	Emotion.RELEASE: { "tint": Color(0.88, 0.95, 1.02, 0.04), "breath": 1.06, "shimmer": 0.45, "pulse": 0.25 },
	Emotion.FOCUS:  { "tint": Color(0.94, 0.97, 1.02, 0.02), "breath": 0.96, "shimmer": 0.08, "pulse": 0.05 },
}

var _current_tint: Color = Color(1, 1, 1, 0)
var _current_breath: float = 1.0
var _current_shimmer: float = 0.0
var _current_pulse: float = 0.0

var _target_emotion: Emotion = Emotion.CALM
var _target_until: float = 0.0
var _overlay: ColorRect

func _ready() -> void:
	_setup_overlay()
	_connect_events()

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now >= _target_until and _target_emotion != Emotion.CALM:
		set_target_emotion(Emotion.CALM, 1.5)
	var p: Dictionary = _params[_target_emotion]
	_current_tint = _current_tint.lerp(p.tint, LERP_SPEED * delta)
	_current_breath = move_toward(_current_breath, p.breath, LERP_SPEED * delta * 0.5)
	_current_shimmer = move_toward(_current_shimmer, p.shimmer, LERP_SPEED * delta)
	_current_pulse = move_toward(_current_pulse, p.pulse, LERP_SPEED * delta)
	if _overlay:
		_overlay.color = _current_tint

func _setup_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = LAYER_EMOTION
	layer.name = "EmotionOverlayLayer"
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(1, 1, 1, 0)
	layer.add_child(_overlay)

func _connect_events() -> void:
	if EventBus.run_started.is_connected(_on_run_started) == false:
		EventBus.run_started.connect(_on_run_started)
	if EventBus.has_signal("build_ignited") and EventBus.build_ignited.is_connected(_on_build_ignited) == false:
		EventBus.build_ignited.connect(_on_build_ignited)
	if EventBus.has_signal("first_synergy_triggered") and EventBus.first_synergy_triggered.is_connected(_on_first_synergy) == false:
		EventBus.first_synergy_triggered.connect(_on_first_synergy)
	if EventBus.has_signal("second_synergy_triggered") and EventBus.second_synergy_triggered.is_connected(_on_second_synergy) == false:
		EventBus.second_synergy_triggered.connect(_on_second_synergy)
	if EventBus.has_signal("boss_defeated") and EventBus.boss_defeated.is_connected(_on_boss_defeated) == false:
		EventBus.boss_defeated.connect(_on_boss_defeated)
	if EventBus.stage_cleared.is_connected(_on_stage_cleared) == false:
		EventBus.stage_cleared.connect(_on_stage_cleared)
	if EventBus.player_damaged.is_connected(_on_player_damaged) == false:
		EventBus.player_damaged.connect(_on_player_damaged)

func _on_run_started(_weapon_id: String) -> void:
	set_target_emotion(Emotion.CALM, 1.0)

func _on_build_ignited(_effect_id: String, _display_name: String, _duration_sec: float) -> void:
	set_target_emotion(Emotion.RELEASE, RELEASE_DURATION_BUILD)

func _on_first_synergy() -> void:
	set_target_emotion(Emotion.FOCUS, FOCUS_DURATION)

func _on_second_synergy() -> void:
	set_target_emotion(Emotion.RELEASE, RELEASE_DURATION_BUILD * 0.75)

func _on_boss_defeated() -> void:
	set_target_emotion(Emotion.RELEASE, RELEASE_DURATION_BOSS)

func _on_stage_cleared(_stage: int) -> void:
	set_target_emotion(Emotion.RELEASE, RELEASE_DURATION_STAGE)

func _on_player_damaged(_amount: int, _source: Node) -> void:
	set_target_emotion(Emotion.TENSION, TENSION_DURATION)

func set_target_emotion(emotion: Emotion, duration_sec: float = 2.0) -> void:
	_target_emotion = emotion
	_target_until = Time.get_ticks_msec() * 0.001 + duration_sec

func get_emotion_tint() -> Color:
	return _current_tint

func get_emotion_breath_intensity() -> float:
	return _current_breath

func get_emotion_shimmer_strength() -> float:
	return _current_shimmer

func get_emotion_pulse_strength() -> float:
	return _current_pulse
