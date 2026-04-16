extends Node2D
## Signature beam moment for trailer, store GIF, main menu background.
## Timeline: brief pause → charge (telegraph) → fire → refraction trail + impact at tip.

const CHARGE_DELAY := 0.55
const TELEGRAPH_DURATION := 0.12
const PULSE_DURATION := 0.14
const LOOP_DELAY := 1.8

var _beam: Node2D
var _timer: float = 0.0
var _phase: String = "wait"


func _ready() -> void:
	_beam = get_node_or_null("Beam")
	if _beam:
		_beam.visible = false
		# Disable collision for demo
		var area: Area2D = _beam.get_node_or_null("BeamArea") as Area2D
		if area:
			area.monitoring = false
			area.monitorable = false
	_timer = CHARGE_DELAY
	_phase = "wait"


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if _phase == "wait":
		_phase = "charge"
		if _beam and _beam.has_method("start_telegraph"):
			_beam.visible = true
			_beam.start_telegraph()
		_timer = TELEGRAPH_DURATION
		return
	if _phase == "charge":
		_phase = "fire"
		if _beam and _beam.has_method("pulse"):
			_beam.pulse()
		_timer = PULSE_DURATION
		return
	if _phase == "fire":
		_phase = "wait"
		_timer = LOOP_DELAY
		return
