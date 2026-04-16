extends RunWeaponBase
## Burst Cannon: 3-shot pulse then pause, synced to beat. Rhythmic packets; TIME identity.

@export var bursts_per_cycle: int = 3
@export var burst_interval: float = 0.08
@export var cycle_pause: float = 0.35

var _burst_remaining: int = 0
var _burst_timer: float = 0.0
var _in_pause: bool = false
var _pause_timer: float = 0.0
var _waiting_for_beat: bool = false


func _ready() -> void:
	weapon_id = "burst"
	super._ready()
	if BeatConductor and BeatConductor.has_signal("beat_pulse"):
		BeatConductor.beat_pulse.connect(_on_beat_pulse)


func _on_beat_pulse() -> void:
	if _waiting_for_beat:
		_waiting_for_beat = false
		_in_pause = false
		_burst_remaining = bursts_per_cycle
		_burst_timer = 0.0


func _process(delta: float) -> void:
	if _in_pause:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			if BeatConductor and BeatConductor.has_signal("beat_pulse"):
				_waiting_for_beat = true
			else:
				_in_pause = false
				_burst_remaining = bursts_per_cycle
				_burst_timer = 0.0
		return
	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_fire_one_burst_shot()
			_burst_remaining -= 1
			_burst_timer = burst_interval
		return
	_time_until_shot -= delta
	if _time_until_shot <= 0.0:
		_burst_remaining = bursts_per_cycle
		_burst_timer = 0.0
		_fire_one_burst_shot()
		_burst_remaining -= 1
		_burst_timer = burst_interval
		var rate := _get_effective_fire_rate()
		_time_until_shot = 1.0 / maxf(rate, 0.5)


func _fire_one_burst_shot() -> void:
	var direction := _get_fire_direction()
	if direction == Vector2.ZERO:
		return
	_fire_single(global_position, direction)
	if SynergyManager:
		SynergyManager.fire_trigger("pulse_fired", {
			"position": global_position,
			"direction": direction,
			"damage": _damage_with_bonus(),
			"speed": _speed_with_bonus(),
			"weapon_tags": get_weapon_tags(),
		})


func _try_fire() -> void:
	# Burst uses custom _process; base _try_fire not used for timing
	pass
