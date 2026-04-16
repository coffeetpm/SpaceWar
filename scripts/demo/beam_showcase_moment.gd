extends Node2D
## Minimal, stylish beam showcase: Steam GIF, trailer opening, branding.
## Calm power, precision, high-tech. Minimal particles, controlled glow, strong contrast.

# ----- Precise timing (seconds) -----
const T_DARK := 0.7
const T_CHARGE := 0.22
const T_FIRE := 0.14
const T_SPLIT_1 := 0.04
const T_SPLIT_2 := 0.05
const T_SPLIT_3 := 0.06
const T_TRAIL_LINGER := 0.65
const T_RESET_FADE := 0.4
const T_RESET_HOLD := 0.5
const LOOP_PAUSE := 0.2

var _beam: Node2D
var _enemies: Array[Node2D] = []
var _time: float = 0.0
var _phase: String = "dark"
var _fire_start: float = -1.0
var _splits_done: int = 0


func _ready() -> void:
	_beam = get_node_or_null("Beam")
	if _beam:
		_beam.visible = false
		var area: Area2D = _beam.get_node_or_null("BeamArea") as Area2D
		if area:
			area.monitoring = false
			area.monitorable = false
	for i in 3:
		var e := get_node_or_null("Enemy%d" % (i + 1)) as Node2D
		if e:
			_enemies.append(e)
	_phase = "dark"
	_time = 0.0


func _process(delta: float) -> void:
	_time += delta
	match _phase:
		"dark":
			if _time >= T_DARK:
				_time = 0.0
				_phase = "charge"
				if _beam and _beam.has_method("start_telegraph"):
					_beam.visible = true
					_beam.start_telegraph()
		"charge":
			if _time >= T_CHARGE:
				_time = 0.0
				_phase = "fire"
				_fire_start = Time.get_ticks_msec() * 0.001
				_splits_done = 0
				if _beam and _beam.has_method("pulse"):
					_beam.pulse()
		"fire":
			_trigger_splits_when_due()
			if _time >= T_FIRE:
				_time = 0.0
				_phase = "trail"
		"trail":
			if _time >= T_TRAIL_LINGER:
				_time = 0.0
				_phase = "reset"
		"reset":
			if _time >= T_RESET_FADE:
				_reset_all()
				_time = 0.0
				_phase = "reset_hold"
		"reset_hold":
			if _time >= T_RESET_HOLD + LOOP_PAUSE:
				_time = 0.0
				_phase = "dark"


func _trigger_splits_when_due() -> void:
	if _splits_done < 1 and _time >= T_SPLIT_1:
		_splits_done = 1
		_split_enemy(0)
	if _splits_done < 2 and _time >= T_SPLIT_2:
		_splits_done = 2
		_split_enemy(1)
	if _splits_done < 3 and _time >= T_SPLIT_3:
		_splits_done = 3
		_split_enemy(2)


func _split_enemy(index: int) -> void:
	if index < _enemies.size():
		var e = _enemies[index]
		if e and e.has_method("split"):
			e.split()


func _reset_all() -> void:
	if _beam:
		_beam.visible = false
	for e in _enemies:
		if e and e.has_method("reset_split"):
			e.reset_split()
