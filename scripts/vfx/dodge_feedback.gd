extends Node
## Near-dodge feedback: light ripple at player, micro screen shake, sound hook. Visual/audio only.

@export var player_path: NodePath = NodePath("../World/Player")
@export var ripple_radius: float = 28.0
@export var ripple_duration: float = 0.12
@export var shake_intensity: float = 0.06
@export var shake_duration: float = 0.04

var _player: Node2D
var _sound: AudioStreamPlayer2D


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_sound = get_node_or_null("DodgeSound") as AudioStreamPlayer2D
	EventBus.near_dodge_feedback.connect(_on_near_dodge)


func _on_near_dodge() -> void:
	if _player and is_instance_valid(_player):
		_spawn_ripple(_player.global_position)
	EventBus.screen_shake_requested.emit(shake_intensity, shake_duration)
	if _sound:
		_sound.play()


func _spawn_ripple(world_pos: Vector2) -> void:
	var ripple := Polygon2D.new()
	var points: PackedVector2Array = []
	for i in 16:
		var a := TAU * i / 16.0
		points.append(Vector2(cos(a), sin(a)) * ripple_radius)
	ripple.polygon = points
	ripple.color = Color(0.4, 0.75, 1.0, 0.45)
	ripple.material = load("res://resources/materials/additive_material.tres") as Material
	ripple.z_index = 10
	ripple.global_position = world_pos
	get_tree().current_scene.add_child(ripple)
	var tween := ripple.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ripple, "scale", Vector2(1.6, 1.6), ripple_duration).from(Vector2(0.4, 0.4))
	tween.tween_property(ripple, "modulate:a", 0.0, ripple_duration).from(1.0)
	tween.chain().tween_callback(func() -> void: ripple.queue_free())
