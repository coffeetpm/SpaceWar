extends Node
## Run-opening and restart state. Drives opening burst, early visuals, and quick restart.

## Seconds left of opening fire-rate boost (set to 5.0 at run start).
var opening_burst_remaining: float = 0.0
## Seconds left of "opening phase" for spawn rate and early visuals (set to 15.0 at run start).
var opening_phase_remaining: float = 0.0
## Explosion scale multiplier during opening (e.g. 1.35).
var opening_intensity_scale: float = 1.35
## Pickup/visual scale during opening (e.g. 1.25).
var opening_visual_scale: float = 1.25

## Skip weapon select and start immediately with last_weapon_id (set on death for quick restart).
var quick_restart: bool = false
var last_weapon_id: String = "spread"

## Build Ignition: temporary power spike (visual/audio triggered by SynergyManager).
var ignition_damage_mult: float = 1.0
var ignition_remaining: float = 0.0

## True while a run is active (deploy → game over). Combat loop and spawner use this.
var run_active: bool = false

## When true, gameplay (enemies, bullets, timers, movement) is frozen; upgrade UI stays interactive.
var gameplay_frozen: bool = false


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if ignition_remaining > 0.0:
		ignition_remaining = maxf(0.0, ignition_remaining - delta)
		if ignition_remaining <= 0.0:
			ignition_damage_mult = 1.0


func set_ignition(duration_sec: float, damage_mult: float) -> void:
	ignition_remaining = duration_sec
	ignition_damage_mult = damage_mult


func get_ignition_damage_mult() -> float:
	return ignition_damage_mult if ignition_remaining > 0.0 else 1.0


func reset_ignition() -> void:
	ignition_remaining = 0.0
	ignition_damage_mult = 1.0


func is_opening_burst() -> bool:
	return opening_burst_remaining > 0.0


func is_opening_phase() -> bool:
	return opening_phase_remaining > 0.0


func set_opening(burst_sec: float = 5.0, phase_sec: float = 15.0) -> void:
	opening_burst_remaining = burst_sec
	opening_phase_remaining = phase_sec


func tick_opening(delta: float) -> void:
	if opening_burst_remaining > 0.0:
		opening_burst_remaining = maxf(0.0, opening_burst_remaining - delta)
	if opening_phase_remaining > 0.0:
		opening_phase_remaining = maxf(0.0, opening_phase_remaining - delta)
