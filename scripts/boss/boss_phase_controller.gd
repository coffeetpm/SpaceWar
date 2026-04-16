extends Node
class_name BossPhaseController
## Refraction Examiner: fixed intervals, no random spam. 1=Sweep 2=+Reflection+LockShot 3=+PrecisionGrid.

signal phase_changed(phase: int)

@export var sweep_interval_phase1: float = 3.6
@export var sweep_interval_phase2: float = 3.0
@export var sweep_interval_phase3: float = 2.6
@export var reflection_interval: float = 4.8
@export var lock_shot_interval: float = 4.2
@export var precision_grid_interval: float = 6.0

var _stage_manager: Node
var _current_phase: int = 0
var _sweep_timer: float = 0.0
var _reflection_timer: float = 0.0
var _lock_shot_timer: float = 0.0
var _grid_timer: float = 0.0
var _sweep_node: Node
var _reflection_node: Node
var _lock_shot_node: Node
var _grid_node: Node


func _ready() -> void:
	var root := get_tree().current_scene
	if root:
		_stage_manager = root.get_node_or_null("World/StageManager")
	if not _stage_manager:
		_stage_manager = get_tree().get_first_node_in_group("stage_manager")
	var n := get_parent()
	while n and not _stage_manager:
		_stage_manager = n.get_node_or_null("StageManager")
		n = n.get_parent()
	_sweep_node = get_parent().get_node_or_null("BeamEmitters/SweepBeam")
	_reflection_node = get_parent().get_node_or_null("BeamEmitters/ReflectionBeams")
	_lock_shot_node = get_parent().get_node_or_null("BeamEmitters/LockShot")
	_grid_node = get_parent().get_node_or_null("BeamEmitters/PrecisionGrid")
	if not _grid_node:
		_grid_node = get_parent().get_node_or_null("BeamEmitters/GridBeams")


func _process(delta: float) -> void:
	var phase := 0
	if _stage_manager and _stage_manager.has_method("get_boss_phase"):
		phase = _stage_manager.get_boss_phase()
	if phase != _current_phase:
		_current_phase = phase
		phase_changed.emit(phase)
	if phase <= 0:
		return
	_sweep_timer += delta
	_reflection_timer += delta
	_lock_shot_timer += delta
	_grid_timer += delta
	var sweep_interval := sweep_interval_phase1
	if phase >= 2:
		sweep_interval = sweep_interval_phase2
	if phase >= 3:
		sweep_interval = sweep_interval_phase3
	if _sweep_node and _sweep_node.has_method("start_attack") and phase >= 1:
		if _sweep_timer >= sweep_interval:
			_sweep_timer = 0.0
			_sweep_node.start_attack()
	if _reflection_node and _reflection_node.has_method("start_attack") and phase >= 2:
		if _reflection_timer >= reflection_interval:
			_reflection_timer = 0.0
			_reflection_node.start_attack()
	if _lock_shot_node and _lock_shot_node.has_method("start_attack") and phase >= 2:
		if _lock_shot_timer >= lock_shot_interval:
			_lock_shot_timer = 0.0
			_lock_shot_node.start_attack()
	if _grid_node and _grid_node.has_method("start_attack") and phase >= 3:
		if _grid_timer >= precision_grid_interval:
			_grid_timer = 0.0
			_grid_node.start_attack()
