extends Node
## Music-led gameplay timing: internal beat grid. BPM, beat / bar / phrase markers.
## Beat guides timing; input stays responsive (no lock). Gameplay aligns to grid; BeatConductor handles visual.

signal beat_pulse
signal bar_pulse
signal phrase_pulse

@export_range(90.0, 160.0, 5.0) var bpm: float = 120.0
const BEATS_PER_BAR := 4
const BARS_PER_PHRASE := 4

var _beat_timer: float = 0.0
var _beat_index: int = 0
var _paused: bool = false
var _beat_phase: float = 0.0


func _ready() -> void:
	_beat_timer = get_beat_interval()


func _process(delta: float) -> void:
	if _paused:
		return
	_beat_timer -= delta
	_beat_phase = 1.0 - (_beat_timer / get_beat_interval())
	if _beat_timer <= 0.0:
		_beat_timer += get_beat_interval()
		_beat_index += 1
		beat_pulse.emit()
		if _beat_index % BEATS_PER_BAR == 0:
			bar_pulse.emit()
		if _beat_index % (BEATS_PER_BAR * BARS_PER_PHRASE) == 0:
			phrase_pulse.emit()


func get_beat_interval() -> float:
	return 60.0 / bpm if bpm > 0.0 else 0.5


func get_bpm() -> float:
	return bpm


func set_bpm(value: float) -> void:
	bpm = clampf(value, 90.0, 160.0)


func set_paused(p: bool) -> void:
	_paused = p


func is_paused() -> bool:
	return _paused


func get_beat_index() -> int:
	return _beat_index


func get_bar_index() -> int:
	return _beat_index / BEATS_PER_BAR


func get_phrase_index() -> int:
	return _beat_index / (BEATS_PER_BAR * BARS_PER_PHRASE)


## 0..1 within current beat (0 = beat start, 1 = next beat). For subdivisions / cadence.
func get_beat_phase() -> float:
	return _beat_phase


## Seconds until next beat (0 to beat_interval).
func get_seconds_to_next_beat() -> float:
	return maxf(0.0, _beat_timer)


## True on beat boundary (same frame as beat_pulse). Use to align without locking input.
func is_beat_boundary() -> bool:
	return _beat_phase < 0.05
