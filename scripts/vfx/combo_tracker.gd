extends Node
## Tracks consecutive kills within a time window. Emits combo_increased for world rhythm / ripple.

const COMBO_DECAY_SEC := 1.5

var _combo: int = 0
var _decay_timer: float = 0.0


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)


func _process(delta: float) -> void:
	if _decay_timer > 0.0:
		_decay_timer -= delta
		if _decay_timer <= 0.0:
			_combo = 0


func _on_enemy_died(_enemy: Node, _global_position: Vector2) -> void:
	_combo += 1
	_decay_timer = COMBO_DECAY_SEC
	if _combo >= 2 and EventBus.has_signal("combo_increased"):
		EventBus.combo_increased.emit(_combo)
