extends RunWeaponBase
## Piercing Beam: lock-on telegraph then fire. Feels precise; LIGHT identity.

const LOCK_ON_TELEGRAPH := 0.12

var _beam: WeaponBeam
var _telegraph_remaining: float = 0.0


func _ready() -> void:
	weapon_id = "beam"
	super._ready()
	var beam_scene := preload("res://scenes/weapons/beam.tscn") as PackedScene
	if beam_scene:
		_beam = beam_scene.instantiate() as WeaponBeam
		if _beam:
			_beam.telegraph_duration = LOCK_ON_TELEGRAPH
			add_child(_beam)
	if EventBus.has_signal("first_synergy_triggered"):
		EventBus.first_synergy_triggered.connect(_on_first_synergy)


func _on_first_synergy() -> void:
	if _beam and _beam.has_method("play_stability_flicker"):
		_beam.play_stability_flicker()


func _try_fire() -> void:
	var direction := _get_fire_direction()
	if direction == Vector2.ZERO:
		return
	# Lock beam toward nearest enemy (or last aim)
	rotation = atan2(direction.x, -direction.y)
	if _beam:
		_beam.set_damage(_damage_with_bonus())
		if _telegraph_remaining <= 0.0:
			_beam.start_telegraph()
			_telegraph_remaining = LOCK_ON_TELEGRAPH
	fired.emit()


func _process(delta: float) -> void:
	if _telegraph_remaining > 0.0:
		_telegraph_remaining -= delta
		if _telegraph_remaining <= 0.0 and _beam:
			_beam.pulse()
			if EventBus.has_signal("muzzle_flash_requested"):
				EventBus.muzzle_flash_requested.emit(global_position, "beam")
		return
	if _beam and _beam.visible:
		return
	super._process(delta)
