extends BossBeamBase
class_name BossBeamSweep
## Sweep Beam: slow scan, clear telegraph. Readable direction + dodge window; teaches beam dodging.

@export var sweep_angle_degrees: float = 120.0
@export var sweep_duration: float = 2.2
@export var start_angle_degrees: float = -60.0

var _sweep_angle_rad: float = 0.0
var _start_angle_rad: float = 0.0


func _ready() -> void:
	super._ready()
	_sweep_angle_rad = deg_to_rad(sweep_angle_degrees)
	_start_angle_rad = deg_to_rad(start_angle_degrees)


func _get_beam_duration() -> float:
	return sweep_duration


func _tick_beam(delta: float) -> void:
	var t := 1.0 - (_timer / sweep_duration)
	rotation = _start_angle_rad + _sweep_angle_rad * t
