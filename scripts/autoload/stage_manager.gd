extends Node
class_name StageManager
## Stage-based gameplay: each stage 60s, timer → clear → upgrade menu → next stage.
## Controls stage_index, stage_timer, stage_state. Pauses on stage clear; resumes after upgrade.

enum State {
	RUNNING,
	CHOOSING_UPGRADE,
	RUN_END
}

var stage_index: int = 0
var stage_timer: float = 0.0
var stage_state: State = State.RUN_END
var stages_cleared: int = 0  # RunState: number of stages completed this run

const STAGE_DURATION := 60.0

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	if stage_state != State.RUNNING:
		return
	stage_timer -= delta
	if stage_timer <= 0.0:
		_on_stage_timer_end()


func start_game() -> void:
	stage_state = State.RUNNING
	stage_index = 1
	stages_cleared = 0
	stage_timer = STAGE_DURATION
	Engine.time_scale = 1.0
	EventBus.stage_started.emit(stage_index)


func _on_stage_timer_end() -> void:
	stages_cleared = stage_index
	stage_state = State.CHOOSING_UPGRADE
	Engine.time_scale = 0.0
	EventBus.stage_cleared.emit(stage_index)
	EventBus.upgrade_choice_requested.emit(_get_upgrade_choices())


func _get_upgrade_choices() -> Array:
	var pool: Array = _get_upgrade_pool()
	var choices: Array = []
	var indices: Array = range(pool.size())
	indices.shuffle()
	for i in min(3, indices.size()):
		choices.append(pool[indices[i]])
	return choices


func _get_upgrade_pool() -> Array:
	var pool: Array = []
	pool.append(load("res://resources/upgrades/upgrade_fire_rate.tres") as Resource)
	pool.append(load("res://resources/upgrades/upgrade_damage.tres") as Resource)
	pool.append(load("res://resources/upgrades/upgrade_max_hp.tres") as Resource)
	return pool


func choose_upgrade(upgrade_resource: Resource) -> void:
	if upgrade_resource is UpgradeData:
		UpgradeManager.apply(upgrade_resource as UpgradeData)
	stage_state = State.RUNNING
	stage_index += 1
	stage_timer = STAGE_DURATION
	Engine.time_scale = 1.0
	EventBus.stage_started.emit(stage_index)


func _on_player_died() -> void:
	stage_state = State.RUN_END
	Engine.time_scale = 1.0
	EventBus.game_over.emit()
