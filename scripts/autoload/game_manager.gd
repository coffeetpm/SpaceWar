extends Node
## Manages game state and flow: waves, upgrades, win/lose.
## Listens to EventBus and drives the playable loop.

var current_wave: int = 0
var is_in_combat: bool = false
var is_choosing_upgrade: bool = false

func _ready() -> void:
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.player_died.connect(_on_player_died)


func start_game() -> void:
	current_wave = 0
	is_in_combat = false
	is_choosing_upgrade = false
	_start_next_wave()


func _start_next_wave() -> void:
	current_wave += 1
	is_in_combat = true
	is_choosing_upgrade = false
	EventBus.wave_started.emit(current_wave)


func _on_wave_cleared(_wave_number: int) -> void:
	is_in_combat = false
	is_choosing_upgrade = true
	EventBus.upgrade_choice_requested.emit(_get_upgrade_choices())


func _get_upgrade_choices() -> Array:
	# Returns 3 upgrade resources; override or load from pool.
	var pool: Array = _get_upgrade_pool()
	var choices: Array = []
	var indices: Array = range(pool.size())
	indices.shuffle()
	for i in min(3, indices.size()):
		choices.append(pool[indices[i]])
	return choices


func _get_upgrade_pool() -> Array:
	var pool: Array = []
	# Default pool; add more .tres under resources/upgrades/ and load via DirAccess
	pool.append(load("res://resources/upgrades/upgrade_fire_rate.tres") as Resource)
	pool.append(load("res://resources/upgrades/upgrade_damage.tres") as Resource)
	pool.append(load("res://resources/upgrades/upgrade_max_hp.tres") as Resource)
	return pool


func choose_upgrade(upgrade_resource: Resource) -> void:
	if upgrade_resource is UpgradeData:
		UpgradeManager.apply(upgrade_resource as UpgradeData)
	is_choosing_upgrade = false
	_start_next_wave()


func _on_player_died() -> void:
	is_in_combat = false
	# Game Over overlay and emit are handled only by World/StageManager (single responsibility).
