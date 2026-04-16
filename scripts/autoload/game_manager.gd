extends Node
## Manages game state and flow: waves, upgrades, win/lose.
## Listens to EventBus and drives the playable loop.

var current_wave: int = 0
var is_in_combat: bool = false
var is_choosing_upgrade: bool = false

func _ready() -> void:
	# 實際遊玩循環由 World/StageManager 與 LevelManager 驅動；避免與波次完成重複彈出強化。
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


## 強化實際套用由 World/StageManager 統一負責（單一責任），這裡僅推進內部波次狀態。
func choose_upgrade(_upgrade_resource: Resource) -> void:
	is_choosing_upgrade = false
	_start_next_wave()


func _on_player_died() -> void:
	is_in_combat = false
	# Game Over overlay and emit are handled only by World/StageManager (single responsibility).
