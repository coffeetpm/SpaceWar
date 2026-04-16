extends BossBeamBase
class_name BossLockShot
## Delayed aim at player: direction locked at telegraph start (readable), then beam fires. Teaches precise movement.

@export var telegraph_show_sec: float = 0.55
@export var lock_delay_after_telegraph: float = 0.15
@export var beam_duration: float = 0.38

var _player: Node2D


func _ready() -> void:
	super._ready()
	_player = get_tree().get_first_node_in_group(player_group) as Node2D
	var tl: Node = get_node_or_null("TelegraphLine")
	if tl and "telegraph_duration" in tl:
		tl.set("telegraph_duration", telegraph_show_sec)


func start_attack() -> void:
	if _player and is_instance_valid(_player):
		var dir := (_player.global_position - global_position).normalized()
		rotation = Vector2.UP.angle_to(dir)
	telegraph_duration = telegraph_show_sec + lock_delay_after_telegraph
	super.start_attack()


func _get_beam_duration() -> float:
	return beam_duration


func _tick_beam(_delta: float) -> void:
	pass
