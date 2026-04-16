extends Node2D
## Mid-distance gameplay composition: player visible, enemies approach, beam slices. Playable feel for Steam GIF / trailer.
## Minimal, sharp, precise. No zoom too close, no full-screen effects, gameplay readable.

# ----- Timing -----
const T_IDLE := 0.9
const T_APPROACH := 1.05
const T_CHARGE := 0.22
const T_FIRE := 0.14
const T_SPLIT_1 := 0.04
const T_SPLIT_2 := 0.05
const T_SPLIT_3 := 0.06
const T_TRAIL := 0.6
const T_RESET := 0.5
const T_LOOP_PAUSE := 0.25

const ENEMY_START_X := 740.0
const ENEMY_Y := 324.0

var _player: Node2D
var _beam: Node2D
var _enemies: Array[Node2D] = []
var _enemy_approach_positions: Array[Vector2] = []
var _time: float = 0.0
var _phase: String = "idle"
var _splits_done: int = 0


func _ready() -> void:
	_player = get_node_or_null("Player")
	_beam = get_node_or_null("Player/Beam") if _player else get_node_or_null("Beam")
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
			_enemy_approach_positions.append(e.position)
			e.position = Vector2(ENEMY_START_X + i * 35.0, ENEMY_Y)
	_phase = "idle"
	_time = 0.0


func _process(delta: float) -> void:
	_time += delta
	match _phase:
		"idle":
			if _time >= T_IDLE:
				_time = 0.0
				_phase = "approach"
				_start_approach()
		"approach":
			if _time >= T_APPROACH:
				_time = 0.0
				_phase = "charge"
				if _beam and _beam.has_method("start_telegraph"):
					_beam.visible = true
					_beam.start_telegraph()
		"charge":
			if _time >= T_CHARGE:
				_time = 0.0
				_phase = "fire"
				_splits_done = 0
				if _beam and _beam.has_method("pulse"):
					_beam.pulse()
		"fire":
			_trigger_splits_when_due()
			if _time >= T_FIRE:
				_time = 0.0
				_phase = "trail"
		"trail":
			if _time >= T_TRAIL:
				_time = 0.0
				_phase = "reset"
		"reset":
			if _time >= T_RESET:
				_reset_all()
				_time = 0.0
				_phase = "reset_hold"
		"reset_hold":
			if _time >= T_LOOP_PAUSE:
				_time = 0.0
				_phase = "idle"


func _start_approach() -> void:
	for i in _enemies.size():
		var e: Node2D = _enemies[i]
		if not e:
			continue
		var target: Vector2 = _enemy_approach_positions[i] if i < _enemy_approach_positions.size() else Vector2(320.0 + i * 130.0, ENEMY_Y)
		var t := e.create_tween()
		t.set_ease(Tween.EASE_IN_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(e, "position", target, T_APPROACH)


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
	for i in _enemies.size():
		var e = _enemies[i]
		if not e:
			continue
		if e.has_method("reset_split"):
			e.reset_split()
		e.position = Vector2(ENEMY_START_X + i * 35.0, ENEMY_Y)
