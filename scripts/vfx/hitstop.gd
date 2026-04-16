extends Node
## Single time-scale manager: hitstop (enemy hit) and player damage dip.
## Keeps minimum scale and maximum end time so both can run without fighting.

var _end_time_msec: int = 0
var _current_scale: float = 1.0

func _ready() -> void:
	EventBus.hitstop_requested.connect(_on_hitstop)
	EventBus.time_scale_dip_requested.connect(_on_dip)


func _on_hitstop(duration_sec: float, time_scale: float) -> void:
	_apply(duration_sec, time_scale)


func _on_dip(duration_sec: float, time_scale: float) -> void:
	_apply(duration_sec, time_scale)


func _apply(duration_sec: float, time_scale: float) -> void:
	var end := Time.get_ticks_msec() + int(duration_sec * 1000.0)
	_end_time_msec = maxi(_end_time_msec, end)
	_current_scale = minf(_current_scale, time_scale)
	Engine.time_scale = _current_scale


func _process(_delta: float) -> void:
	if _end_time_msec > 0 and Time.get_ticks_msec() >= _end_time_msec:
		_end_time_msec = 0
		_current_scale = 1.0
		Engine.time_scale = 1.0
