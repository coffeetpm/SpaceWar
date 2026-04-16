extends Node
## Build vocabulary: all weapons and upgrades derive from abstract forces LIGHT / TIME / SPACE.
## Run identity = combination of forces. Synergies occur when forces interact.

# ----- Force constants -----
const FORCE_LIGHT := "light"
const FORCE_TIME := "time"
const FORCE_SPACE := "space"

## Outer-layer display names (for discovery only — not main UI). Inner logic still uses light/time/space.
const FORCE_DISPLAY_NAMES: Dictionary = {
	"light": "Photon",
	"time": "Temporal",
	"space": "Gravitic",
}

# ----- Sub-tags per force (gameplay vocabulary) -----
const LIGHT_TAGS: Array[String] = ["refraction", "split", "echo", "mirror", "electric"]
const TIME_TAGS: Array[String] = ["slow", "freeze", "delay", "rewind"]
const SPACE_TAGS: Array[String] = ["pull", "orbit", "warp", "compress"]

# ----- Weapon → primary force (weapons inherit from at least one force) -----
# Beam → LIGHT, Drone → SPACE, Pulse (spread/burst/homing) → TIME
const WEAPON_FORCE: Dictionary = {
	"beam": FORCE_LIGHT,
	"spread": FORCE_TIME,
	"burst": FORCE_TIME,
	"homing": FORCE_TIME,
	"rear": FORCE_TIME,
	"drones": FORCE_SPACE,
}

## Sub-tags per weapon (which force-tags this weapon embodies).
const WEAPON_FORCE_TAGS: Dictionary = {
	"beam": ["refraction", "echo"],
	"spread": ["delay", "split"],
	"burst": ["delay", "split"],
	"homing": ["delay", "rewind"],
	"rear": ["delay", "rewind"],
	"drones": ["orbit", "pull"],
}

# ----- Force-pair synergy effects (when two forces interact) -----
const FORCE_PAIR_EFFECTS: Dictionary = {
	# LIGHT + SPACE = bending beams
	"light_space": "bending_beams",
	"space_light": "bending_beams",
	# TIME + LIGHT = afterimage attacks
	"time_light": "afterimage",
	"light_time": "afterimage",
	# SPACE + TIME = gravity slow zones
	"space_time": "gravity_slow",
	"time_space": "gravity_slow",
}

# ----- Trigger names per force (for SynergyManager) -----
const TRIGGER_LIGHT_PULSE := "light_pulse"   # beam fires
const TRIGGER_TIME_PULSE := "time_pulse"     # spread/burst/homing fire
const TRIGGER_SPACE_TICK := "space_tick"     # drone contact/orbit

# ----- Build Ignition (weapon + tag → "build has come online" moment) -----
## When run has this weapon and an upgrade adds this tag, trigger ignition once. Keys: "weapon_id|tag" -> { effect_id, display_name, duration_sec, damage_mult }
const IGNITION_TRIGGERS: Dictionary = {
	"beam|split": {"effect_id": "beam_net", "display_name": "Beam Net", "duration_sec": 8.0, "damage_mult": 1.5},
	"drones|electric": {"effect_id": "chain_shock", "display_name": "Chain Shock", "duration_sec": 8.0, "damage_mult": 1.5},
	"drones|orbit": {"effect_id": "chain_shock", "display_name": "Chain Shock", "duration_sec": 8.0, "damage_mult": 1.5},
	"spread|delay": {"effect_id": "shockwave_cascade", "display_name": "Shockwave Cascade", "duration_sec": 8.0, "damage_mult": 1.5},
	"spread|echo": {"effect_id": "shockwave_cascade", "display_name": "Shockwave Cascade", "duration_sec": 8.0, "damage_mult": 1.5},
	"burst|delay": {"effect_id": "shockwave_cascade", "display_name": "Shockwave Cascade", "duration_sec": 8.0, "damage_mult": 1.5},
	"burst|echo": {"effect_id": "shockwave_cascade", "display_name": "Shockwave Cascade", "duration_sec": 8.0, "damage_mult": 1.5},
	"homing|delay": {"effect_id": "shockwave_cascade", "display_name": "Shockwave Cascade", "duration_sec": 8.0, "damage_mult": 1.5},
	"homing|echo": {"effect_id": "shockwave_cascade", "display_name": "Shockwave Cascade", "duration_sec": 8.0, "damage_mult": 1.5},
	"rear|delay": {"effect_id": "shockwave_cascade", "display_name": "Shockwave Cascade", "duration_sec": 8.0, "damage_mult": 1.5},
	"rear|echo": {"effect_id": "shockwave_cascade", "display_name": "Shockwave Cascade", "duration_sec": 8.0, "damage_mult": 1.5},
}

# ----- Signature builds (memorable run identities; see docs/SIGNATURE_BUILDS.md) -----
const BUILD_LIGHT_REFRACTION := "Light Refraction"
const BUILD_TIME_COLLAPSE := "Time Collapse"
const BUILD_SPACE_ORBIT := "Space Orbit"

## Weapon ID -> signature build name when this weapon is the run core.
const WEAPON_SIGNATURE_BUILD: Dictionary = {
	"beam": BUILD_LIGHT_REFRACTION,
	"spread": BUILD_TIME_COLLAPSE,
	"burst": BUILD_TIME_COLLAPSE,
	"homing": BUILD_TIME_COLLAPSE,
	"rear": BUILD_TIME_COLLAPSE,
	"drones": BUILD_SPACE_ORBIT,
}

## Short subtitle per weapon for HUD / build identity (cadence or identity hook).
const WEAPON_DISPLAY_DESC: Dictionary = {
	"beam": "Lock-on · LIGHT",
	"spread": "Wide cone · TIME",
	"burst": "Rhythmic burst · TIME",
	"homing": "Straight then curve · TIME",
	"rear": "Fire while moving · TIME",
	"drones": "Orbit · SPACE",
}

## Two behavioral (non–flat-stat) upgrades per weapon. Keys: upgrade_id, display_name, description, behavior_key.
const WEAPON_SPECIFIC_UPGRADES: Dictionary = {
	"beam": [
		{"id": "beam_split", "display_name": "Beam Split", "description": "Second beam at angle after lock-on", "behavior_key": "beam_split"},
		{"id": "beam_echo", "display_name": "Beam Echo", "description": "Brief echo pulse 0.05s after main beam", "behavior_key": "beam_echo"},
	],
	"spread": [
		{"id": "spread_wide", "display_name": "Wider Cone", "description": "Spread angle +8°", "behavior_key": "spread_wide"},
		{"id": "spread_extra", "display_name": "Extra Pellet", "description": "One more projectile per volley", "behavior_key": "spread_extra"},
	],
	"burst": [
		{"id": "burst_faster", "display_name": "Tighter Burst", "description": "Shorter interval between shots in burst", "behavior_key": "burst_faster"},
		{"id": "burst_four", "display_name": "Fourth Shot", "description": "4-shot burst instead of 3", "behavior_key": "burst_four"},
	],
	"homing": [
		{"id": "homing_stronger", "display_name": "Stronger Curve", "description": "Homing turn rate +30%", "behavior_key": "homing_stronger"},
		{"id": "homing_dash", "display_name": "Faster Dash", "description": "Initial straight phase 25% faster", "behavior_key": "homing_dash"},
	],
	"rear": [
		{"id": "rear_lower", "display_name": "Easier Trigger", "description": "Fire at slightly lower movement speed", "behavior_key": "rear_lower"},
		{"id": "rear_twin", "display_name": "Twin Shot", "description": "Two shots slightly apart when firing", "behavior_key": "rear_twin"},
	],
	"drones": [
		{"id": "drones_faster", "display_name": "Faster Orbit", "description": "Orbit speed +20%", "behavior_key": "drones_faster"},
		{"id": "drones_react", "display_name": "Reactive Spin", "description": "Orbit responds more to movement speed", "behavior_key": "drones_react"},
	],
}


func _ready() -> void:
	pass


## For discovery UI only (e.g. run summary "Resonance: Photon, Temporal"). Not the main visual language.
func get_force_display_name(force: String) -> String:
	return FORCE_DISPLAY_NAMES.get(force, force)


func get_force_tags(force: String) -> Array[String]:
	match force:
		FORCE_LIGHT:
			return LIGHT_TAGS.duplicate()
		FORCE_TIME:
			return TIME_TAGS.duplicate()
		FORCE_SPACE:
			return SPACE_TAGS.duplicate()
	return []


## Primary force for this weapon_id (e.g. "beam" -> "light").
func get_weapon_force(weapon_id: String) -> String:
	return WEAPON_FORCE.get(weapon_id, FORCE_LIGHT)


## Full tag list for weapon: [force, ...force_sub_tags].
func get_weapon_tags_for_id(weapon_id: String) -> Array[String]:
	var force := get_weapon_force(weapon_id)
	var sub: Array = WEAPON_FORCE_TAGS.get(weapon_id, [])
	var out: Array[String] = [force]
	for t in sub:
		out.append(t)
	return out


## All valid tags (forces + sub-tags) for upgrade/run checks.
func get_all_force_tags() -> Array[String]:
	var out: Array[String] = [FORCE_LIGHT, FORCE_TIME, FORCE_SPACE]
	out.append_array(LIGHT_TAGS)
	out.append_array(TIME_TAGS)
	out.append_array(SPACE_TAGS)
	return out


## Effect key for two forces present (e.g. "light" + "space" -> "bending_beams").
func get_force_pair_effect(force_a: String, force_b: String) -> String:
	if force_a == force_b:
		return ""
	var key := force_a + "_" + force_b
	if FORCE_PAIR_EFFECTS.has(key):
		return FORCE_PAIR_EFFECTS[key]
	key = force_b + "_" + force_a
	return FORCE_PAIR_EFFECTS.get(key, "")


## Signature build name for this run (for run summary UI). Returns build name or empty string.
## Optional: only return build when run has at least two forces (synergy achieved, early–mid run).
func get_signature_build(weapon_id: String, run_forces: Array, require_synergy: bool = true) -> String:
	var build_name: String = WEAPON_SIGNATURE_BUILD.get(weapon_id, "")
	if build_name.is_empty():
		return ""
	if require_synergy and run_forces.size() < 2:
		return ""
	return build_name


## Build Ignition: when run has weapon_id and an upgrade added this tag, return trigger data or null.
func get_ignition_trigger(weapon_id: String, tag: String) -> Dictionary:
	var key: String = weapon_id + "|" + tag
	return IGNITION_TRIGGERS.get(key, {})


## Short subtitle for weapon (HUD / build identity). E.g. "Lock-on · LIGHT".
func get_weapon_display_desc(weapon_id: String) -> String:
	return WEAPON_DISPLAY_DESC.get(weapon_id, "")


## Two weapon-specific behavioral upgrades for this weapon. Array of { id, display_name, description, behavior_key }.
func get_weapon_specific_upgrades(weapon_id: String) -> Array:
	return WEAPON_SPECIFIC_UPGRADES.get(weapon_id, []).duplicate()
