extends Node2D
class_name WaveSpawner
## Enemies support tempo, not chaos. Aligned to run rhythm: 0–10s light, 10–20s structured waves, 20–30s dense clusters, 30–40s peak formations or boss. No random bursts; readable.

signal wave_cleared
signal enemy_spawned(enemy: Node2D)

@export var spawn_radius: float = 320.0
@export var enemy_scene: PackedScene
## Optional: Chaser (current), Shooter, Dasher. If set, spawn table by stage is used.
@export var chaser_scene: PackedScene
@export var shooter_scene: PackedScene
@export var dasher_scene: PackedScene
## Roguelike 波次：可選額外類型（未設則僅用 chaser / shooter / dasher）。
@export var scout_scene: PackedScene
@export var tank_scene: PackedScene
@export var min_radius_ratio: float = 0.55
## Roguelike 離散波：每隻敵機生成間隔（秒）。
@export var rogu_wave_spawn_stagger: float = 0.07
## Light pressure (0–10s): one per beat, slow.
@export var delay_light: float = 0.36
## Structured waves (10–20s): predictable wave-of-2 rhythm.
@export var delay_structured: float = 0.28
## Dense clusters (20–30s): 2 per beat, clustered.
@export var delay_dense: float = 0.18
## Peak formations (30–35s): 2 per beat, formation spread.
@export var delay_peak: float = 0.12
## Release / boss (35–40s): wind down so boss is readable.
@export var delay_release: float = 0.24
@export var delay_opening: float = 0.11
## Minimum delay between spawn events (avoids random bursts).
@export var min_spawn_delay: float = 0.12
## Formation spread (rad) for peak phase so cluster is readable.
@export var formation_spread_rad: float = 0.35

var _burst_duration: float = 30.0
var _burst_index: int = 0
var _is_boss_burst: bool = false
var _alive_count: int = 0
var _spawn_timer: float = 0.0
var _stopped: bool = true
var _burst_time_remaining: float = 0.0
var _pending_spawn: bool = false
var _spawn_count_this_burst: int = 0
var _beat_count_this_burst: int = 0
## Roguelike：離散波次模式（清光本波敵機後才進下一波）。
var _rogu_wave_mode: bool = false
var _rogu_wave_index: int = 0
var _rogu_mini_stage: int = 0
var _rogu_spawn_queue: Array[PackedScene] = []
var _rogu_stagger: float = 0.0
var _rogu_wave_finish_emitted: bool = false

func _ready() -> void:
	if not enemy_scene:
		enemy_scene = preload("res://scenes/enemies/enemy_basic.tscn")
	if not chaser_scene:
		chaser_scene = preload("res://scenes/enemies/enemy_basic.tscn")
	if not shooter_scene:
		shooter_scene = preload("res://scenes/enemies/enemy_shooter.tscn")
	if not dasher_scene:
		dasher_scene = preload("res://scenes/enemies/enemy_dasher.tscn")
	if not scout_scene:
		if ResourceLoader.exists("res://scenes/enemies/enemy_scout.tscn"):
			scout_scene = load("res://scenes/enemies/enemy_scout.tscn") as PackedScene
		else:
			scout_scene = chaser_scene
	if not tank_scene:
		if ResourceLoader.exists("res://scenes/enemies/enemy_tank.tscn"):
			tank_scene = load("res://scenes/enemies/enemy_tank.tscn") as PackedScene
		else:
			tank_scene = chaser_scene
	var bc_node = get_node_or_null("/root/BeatConductor")
	if bc_node and bc_node.has_signal("beat_pulse"):
		bc_node.beat_pulse.connect(_on_beat_pulse)


func start_burst(burst_index: int, duration: float, is_boss: bool = false) -> void:
	_rogu_wave_mode = false
	_burst_duration = duration
	_burst_index = burst_index
	_is_boss_burst = is_boss
	_alive_count = 0
	_spawn_count_this_burst = 0
	_beat_count_this_burst = 0
	_burst_time_remaining = _burst_duration
	_spawn_timer = _get_phase_spawn_delay()
	_stopped = false
	# First wave: spawn opening enemies immediately so player never idles in empty space.
	if burst_index == 1:
		_spawn_one()
		_spawn_one()


func start_stage(stage_index: int, duration: float = 30.0) -> void:
	start_burst(stage_index, duration, false)


func stop() -> void:
	_stopped = true
	_rogu_wave_mode = false
	_rogu_spawn_queue.clear()


## Roguelike：單一小關卡內的第 `wave_index` 波（清光後由 StageManager 決定下一波或強化）。
func start_rogu_wave(mini_stage_index: int, wave_index: int) -> void:
	_rogu_wave_mode = true
	_stopped = false
	_burst_index = mini_stage_index
	_rogu_mini_stage = mini_stage_index
	_rogu_wave_index = wave_index
	_alive_count = 0
	_spawn_count_this_burst = 0
	_beat_count_this_burst = 0
	_pending_spawn = false
	_rogu_wave_finish_emitted = false
	_rogu_spawn_queue.clear()
	var count := _compute_rogu_wave_enemy_count(mini_stage_index, wave_index)
	for i in count:
		_rogu_spawn_queue.append(_pick_enemy_scene_for_rogu_wave(mini_stage_index, wave_index))
	_rogu_stagger = 0.0
	if EventBus:
		EventBus.wave_started.emit(wave_index)


func _compute_rogu_wave_enemy_count(mini_stage_index: int, wave_index: int) -> int:
	var base := 5 + wave_index * 2 + mini(mini_stage_index / 2, 8)
	if wave_index == 1:
		base += 1
	return clampi(base, 5, 20)


func _pick_enemy_scene_for_rogu_wave(mini_stage_index: int, wave_index: int) -> PackedScene:
	## 每波重新加權隨機，並依波次加深威脅組合（可擴充為 Resource 表）。
	var tier := clampi(mini_stage_index, 1, 99)
	var wave_roll := randf() + float(wave_index) * 0.07 + float(tier) * 0.01
	var w_chase := 0.34 - wave_roll * 0.08
	var w_shoot := 0.30 + sin(wave_roll * 5.3) * 0.08
	var w_dash := 0.20 + cos(wave_roll * 4.1) * 0.07
	var scout_bonus := 0.11 if wave_index == 1 else 0.02
	var w_scout := 0.10 + scout_bonus
	var w_tank := 0.05 + float(tier) * 0.01
	w_chase = maxf(w_chase, 0.08)
	w_shoot = maxf(w_shoot, 0.05)
	w_dash = maxf(w_dash, 0.03)
	w_scout = maxf(w_scout, 0.0)
	w_tank = maxf(w_tank, 0.0)
	var sum_w := w_chase + w_shoot + w_dash + w_scout + w_tank
	var r := randf() * sum_w
	var acc := 0.0
	acc += w_chase
	if r < acc:
		return chaser_scene
	acc += w_shoot
	if r < acc:
		return shooter_scene
	acc += w_dash
	if r < acc:
		return dasher_scene
	acc += w_scout
	if r < acc:
		return scout_scene
	return tank_scene


func _try_finish_rogu_wave() -> void:
	if _rogu_wave_finish_emitted:
		return
	if _rogu_spawn_queue.size() > 0:
		return
	if _alive_count > 0:
		return
	_rogu_wave_finish_emitted = true
	wave_cleared.emit(_rogu_wave_index)
	if EventBus:
		EventBus.wave_cleared.emit(_rogu_wave_index)


func set_burst_time_remaining(remaining: float) -> void:
	_burst_time_remaining = remaining


func set_stage_time_remaining(remaining: float) -> void:
	_burst_time_remaining = remaining


func _process(delta: float) -> void:
	if RunState and RunState.gameplay_frozen:
		return
	if _rogu_wave_mode:
		if _stopped:
			return
		if _rogu_spawn_queue.size() > 0:
			_rogu_stagger -= delta
			if _rogu_stagger <= 0.0:
				var sc: PackedScene = _rogu_spawn_queue.pop_front() as PackedScene
				_instantiate_at(_random_spawn_position(), sc)
				_rogu_stagger = rogu_wave_spawn_stagger
		_try_finish_rogu_wave()
		return
	if _stopped or _burst_time_remaining <= 0.0:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_pending_spawn = true
		_spawn_timer = _get_phase_spawn_delay()


func _on_beat_pulse() -> void:
	if _rogu_wave_mode:
		return
	_beat_count_this_burst += 1
	if not _pending_spawn:
		return
	_pending_spawn = false
	var elapsed := _burst_duration - _burst_time_remaining
	var phase := _get_rhythm_phase(elapsed)
	if _spawn_count_this_burst == 0 and _burst_index == 1:
		_spawn_one()
		_spawn_one()
		return
	match phase:
		0: # light: one per beat
			_spawn_one()
		1: # structured waves: wave of 2 every 2nd beat
			if _beat_count_this_burst % 2 == 0:
				_spawn_wave(2)
			else:
				_spawn_one()
		2: # dense clusters: 2 per beat, clustered
			_spawn_cluster(2)
		3: # peak formations: 2 per beat, formation spread
			_spawn_formation(2)
		4: # release / boss: one per beat, readable
			_spawn_one()
		_:
			_spawn_one()


## 0 = light (0–10s), 1 = structured (10–20s), 2 = dense (20–30s), 3 = peak (30–35s), 4 = release (35–40s).
func _get_rhythm_phase(elapsed: float) -> int:
	if elapsed < 10.0: return 0
	if elapsed < 20.0: return 1
	if elapsed < 30.0: return 2
	if elapsed < 35.0: return 3
	return 4


func _get_phase_spawn_delay() -> float:
	if _burst_index == 1 and RunState and RunState.is_opening_phase():
		return maxf(delay_opening, min_spawn_delay)
	var elapsed := _burst_duration - _burst_time_remaining
	# Run rhythm: 0–10 light, 10–20 structured, 20–30 dense, 30–40 peak. Enemies support tempo.
	if _burst_duration >= 35.0 and _burst_duration <= 42.0:
		var base_delay: float
		if elapsed < 10.0:
			base_delay = delay_light
		elif elapsed < 20.0:
			base_delay = delay_structured
		elif elapsed < 30.0:
			base_delay = delay_dense
		elif elapsed < 35.0:
			base_delay = delay_peak
		else:
			base_delay = delay_release
		return maxf(base_delay, min_spawn_delay)
	# Legacy: thirds
	var third := _burst_duration / 3.0
	var base_delay: float
	if elapsed < third:
		base_delay = delay_structured
	elif elapsed < third * 2.0:
		base_delay = delay_dense
	else:
		base_delay = delay_peak
	if _is_boss_burst:
		base_delay *= 0.85
	# Difficulty: denser spawns per stage (faster spawn rate).
	var burst_scale := 1.0 - (_burst_index - 1) * 0.06
	burst_scale = clampf(burst_scale, 0.5, 1.0)
	return maxf(base_delay * burst_scale, min_spawn_delay)


func _spawn_one() -> void:
	var pos := _random_spawn_position()
	_instantiate_at(pos)


func _spawn_wave(count: int) -> void:
	for i in count:
		_spawn_one()


func _spawn_cluster(count: int) -> void:
	var center := _get_spawn_center()
	var angle := randf() * TAU
	var base_r := spawn_radius * (min_radius_ratio + randf() * (1.0 - min_radius_ratio))
	for i in count:
		var r := base_r * (0.92 + randf() * 0.16)
		var a := angle + (randf() - 0.5) * 0.4
		var pos := center + Vector2.from_angle(a) * r
		_instantiate_at(pos)


func _spawn_formation(count: int) -> void:
	var center := _get_spawn_center()
	var base_angle := randf() * TAU
	var base_r := spawn_radius * (min_radius_ratio + randf() * (1.0 - min_radius_ratio))
	for i in count:
		var a := base_angle + (float(i) - (count - 1) * 0.5) * formation_spread_rad
		var r := base_r * (0.95 + randf() * 0.1)
		var pos := center + Vector2.from_angle(a) * r
		_instantiate_at(pos)


func _pick_enemy_scene_for_stage() -> PackedScene:
	if chaser_scene and shooter_scene and dasher_scene:
		# Weights [chaser, shooter, dasher] by stage: early = mostly chaser, later = more variety.
		var w: Array[float]
		if _burst_index <= 1:
			w = [1.0, 0.0, 0.0]
		elif _burst_index == 2:
			w = [0.78, 0.22, 0.0]
		elif _burst_index == 3:
			w = [0.58, 0.28, 0.14]
		else:
			w = [0.48, 0.28, 0.24]
		var r := randf()
		if r < w[0]:
			return chaser_scene
		if r < w[0] + w[1]:
			return shooter_scene
		return dasher_scene
	return enemy_scene if enemy_scene else chaser_scene


func _instantiate_at(pos: Vector2, scene_override: PackedScene = null) -> void:
	var scene: PackedScene = scene_override if scene_override else _pick_enemy_scene_for_stage()
	var enemy: Node2D = scene.instantiate()
	enemy.global_position = pos
	get_parent().add_child(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	if enemy.has_method("apply_stage_scaling"):
		enemy.apply_stage_scaling(_burst_index)
	_alive_count += 1
	_spawn_count_this_burst += 1
	enemy_spawned.emit(enemy)


func _random_spawn_position() -> Vector2:
	var center := _get_spawn_center()
	var angle := randf() * TAU
	var r := spawn_radius * (min_radius_ratio + randf() * (1.0 - min_radius_ratio))
	return center + Vector2.from_angle(angle) * r


func _get_spawn_center() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and is_instance_valid(p):
		return p.global_position
	return get_viewport().get_visible_rect().get_center() if get_viewport() else Vector2(576, 324)


func _on_enemy_died(_enemy: Node, _at: Vector2) -> void:
	_alive_count -= 1
	if _rogu_wave_mode:
		_try_finish_rogu_wave()
