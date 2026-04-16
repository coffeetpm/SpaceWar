extends Node
## Light Language: weapons are light instruments. Each weapon is remembered by rhythm and light behaviour.
## Unique emission rhythm, distinct beam/pulse pattern, identifiable glow timing. Glow is never constant.

# ----- Rhythm types (cadence) -----
const RHYTHM_CONTINUOUS_BREATHING := "continuous_breathing"   # Beam
const RHYTHM_RHYTHMIC_PACKETS := "rhythmic_packets"           # Burst
const RHYTHM_FAN_WAVE := "fan_wave"                           # Spread
const RHYTHM_DELAYED_GLOW := "delayed_glow"                   # Homing
const RHYTHM_REACTIVE_PULSE := "reactive_pulse"               # Rear
const RHYTHM_ORBIT_OSCILLATE := "orbit_oscillate"             # Drones

## weapon_id -> { rhythm_type, pulse_duration, dim_between_mult, beam_breath_speed, trail_delayed_glow, orbit_oscillate_speed, ... }
const LIGHT_CADENCE: Dictionary = {
	"beam": {
		"rhythm_type": RHYTHM_CONTINUOUS_BREATHING,
		"pulse_duration": 0.04,
		"dim_between_mult": 0.0,
		"beam_breath_speed": 8.5,
		"beam_breath_min": 0.72,
		"beam_breath_max": 1.0,
	},
	"burst": {
		"rhythm_type": RHYTHM_RHYTHMIC_PACKETS,
		"pulse_duration": 0.08,
		"dim_between_mult": 0.4,
		"packet_count": 3,
		"packet_interval": 0.08,
	},
	"spread": {
		"rhythm_type": RHYTHM_FAN_WAVE,
		"pulse_duration": 0.06,
		"dim_between_mult": 0.5,
		"fan_pulses": 5,
	},
	"homing": {
		"rhythm_type": RHYTHM_DELAYED_GLOW,
		"pulse_duration": 0.05,
		"dim_between_mult": 0.45,
		"trail_delayed_glow_initial_alpha": 0.32,
		"trail_delayed_glow_ramp_sec": 0.12,
	},
	"rear": {
		"rhythm_type": RHYTHM_REACTIVE_PULSE,
		"pulse_duration": 0.07,
		"dim_between_mult": 0.6,
	},
	"drones": {
		"rhythm_type": RHYTHM_ORBIT_OSCILLATE,
		"pulse_duration": 0.0,
		"orbit_oscillate_speed": 4.2,
		"orbit_trail_alpha_min": 0.5,
		"orbit_trail_alpha_max": 1.0,
	},
}

## Build synergy / ignition: system coming online — light echo radiates outward, world brightens, cool tint. No explosion.
const BUILD_SYNERGY_LIGHT_DURATION := 0.5
const BUILD_SYNERGY_GLOW_STRENGTH := 1.18
const BUILD_SYNERGY_OVERLAY_ALPHA := 0.032
const BUILD_SYNERGY_ECHO_RINGS := 4
const BUILD_SYNERGY_ECHO_SPEED := 320.0
const BUILD_SYNERGY_ECHO_MAX_RADIUS := 180.0

## Readability: gameplay silhouettes remain sharp; light never hides hitboxes.
const GLOW_MAX_ALPHA_OVERLAY := 0.035
const TRAIL_NEVER_OBSCURE_HITBOX := true


func get_emission_rhythm(weapon_id: String) -> String:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return str(cadence.get("rhythm_type", ""))
	return ""


func get_glow_pulse_duration(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("pulse_duration", 0.06))
	return 0.06


func get_dim_between_mult(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("dim_between_mult", 0.5))
	return 0.5


func get_beam_breath_speed(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("beam_breath_speed", 8.0))
	return 8.0


func get_beam_breath_min(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("beam_breath_min", 0.7))
	return 0.7


func get_beam_breath_max(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("beam_breath_max", 1.0))
	return 1.0


func is_delayed_glow_trail(weapon_id: String) -> bool:
	return get_emission_rhythm(weapon_id) == RHYTHM_DELAYED_GLOW


func get_delayed_glow_initial_alpha(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("trail_delayed_glow_initial_alpha", 0.35))
	return 0.35


func get_delayed_glow_ramp_sec(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("trail_delayed_glow_ramp_sec", 0.1))
	return 0.1


func get_orbit_oscillate_speed(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("orbit_oscillate_speed", 4.0))
	return 4.0


func get_orbit_trail_alpha_min(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("orbit_trail_alpha_min", 0.5))
	return 0.5


func get_orbit_trail_alpha_max(weapon_id: String) -> float:
	var cadence: Variant = LIGHT_CADENCE.get(weapon_id, {})
	if cadence is Dictionary:
		return float(cadence.get("orbit_trail_alpha_max", 1.0))
	return 1.0


func get_cadence_config(weapon_id: String) -> Dictionary:
	var out: Dictionary = LIGHT_CADENCE.get(weapon_id, {}).duplicate()
	return out if out is Dictionary else {}
