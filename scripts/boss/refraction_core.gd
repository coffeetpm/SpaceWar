extends Node2D
class_name RefractionCore
## Refraction Examiner: LIGHT-type boss. Precision skill test — teaches reading beam attacks and moving precisely.
## Every attack: telegraph phase, readable direction, dodge window. Clean, sharp visuals; no random spam.
const BOSS_DISPLAY_NAME := "Refraction Examiner"

@export var halo_rotation_speed: float = 0.4
@export var max_hp: int = 420

var current_hp: int
var _shell: Node2D
var _core: Node2D
var _halo: Node2D
var _phase_controller: Node
var _beam_emitters: Node2D
func _ready() -> void:
	current_hp = max_hp
	_shell = get_node_or_null("Visual/Shell")
	_core = get_node_or_null("Visual/Core")
	_halo = get_node_or_null("Visual/Halo")
	_phase_controller = get_node_or_null("PhaseController")
	_beam_emitters = get_node_or_null("BeamEmitters")
	add_to_group("boss")
	if EventBus:
		EventBus.boss_hp_changed.emit(current_hp, max_hp)
	if _phase_controller and _phase_controller.has_signal("phase_changed"):
		_phase_controller.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: int) -> void:
	if EventBus:
		EventBus.boss_phase_changed.emit(phase)


func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	if EventBus:
		EventBus.boss_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		if EventBus and EventBus.has_signal("boss_defeated"):
			EventBus.boss_defeated.emit()


func _process(delta: float) -> void:
	if _halo:
		_halo.rotation += halo_rotation_speed * delta


func stop_all_attacks() -> void:
	if _phase_controller:
		_phase_controller.set_process(false)
	if _beam_emitters:
		_beam_emitters.visible = false
		for child in _beam_emitters.get_children():
			child.visible = false
			if child.has_method("stop"):
				child.stop()


func play_collapse_inward(duration: float) -> void:
	var vis: Node2D = get_node_or_null("Visual")
	if not vis:
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(vis, "scale", Vector2.ZERO, duration)
	await tween.finished
