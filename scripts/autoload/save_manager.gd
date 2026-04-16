extends Node
## Persists MetaState to user://save.json. Meta progression = new possibilities (weapons, synergies, tech). Minimal stat upgrades (magnet, starting energy).

const SAVE_PATH := "user://save.json"

## Display name for currency in UI.
const CURRENCY_DISPLAY_NAME := "Energy Fragments"

const META_TOTAL_CURRENCY := "total_currency"
const META_TOTAL_RUNS := "total_runs"
const META_BEST_STAGE := "best_stage"
const META_UNLOCKED_WEAPONS := "unlocked_weapons"
const META_UNLOCKED_SYNERGY_EFFECTS := "unlocked_synergy_effects"
const META_UNLOCKED_FORCE_PAIR_EFFECTS := "unlocked_force_pair_effects"
const META_MAGNET_LEVEL := "magnet_level"
const META_STARTING_ENERGY_LEVEL := "starting_energy_level"
const META_STARTING_HP_LEVEL := "starting_hp_level"
const META_REFRACTION_DUPLICATION := "refraction_duplication"
const META_TIME_MODULES := "time_modules"
const META_REFRACTION_MODULES := "refraction_modules"
const META_INTRO_COMPLETED := "intro_completed"
const META_FIRST_LAB_CHOICE_GRANTED := "first_lab_currency_granted"
const META_FIRST_LAB_CHOICE_MADE := "first_lab_choice_made"

## First lab: player chooses one of three mechanics; enough currency for exactly one.
const FIRST_LAB_CHOICE_CURRENCY := 80

## Cost to unlock. Refraction = first meta (new system feel). Focus on new possibilities; minimal stat upgrades only (magnet, starting energy).
const UNLOCK_COST_REFRACTION := 80
const UNLOCK_COST_WEAPON := 350
const UNLOCK_COST_SYNERGY := 220
const UNLOCK_COST_FORCE_PAIR := 300
const UNLOCK_COST_MAGNET_PER_LEVEL := 150
const UNLOCK_COST_STARTING_ENERGY := 120
const UNLOCK_COST_STARTING_HP := 140
const UNLOCK_COST_TIME_MODULE := 180
const UNLOCK_COST_REFRACTION_MODULE := 200
const MAGNET_MAX_LEVEL := 3
## Magnet is expressed as a % multiplier on pickup attract radius (+10% per level).
const MAGNET_RADIUS_MULT_PER_LEVEL := 0.10
const STARTING_ENERGY_BONUS := 5
const STARTING_ENERGY_MAX_LEVEL := 3
const STARTING_HP_BONUS := 1
const STARTING_HP_MAX_LEVEL := 2

const ALL_TIME_MODULE_IDS: Array[String] = ["temporal_echo", "delay_burst", "rewind"]
const ALL_REFRACTION_MODULE_IDS: Array[String] = ["split", "prism", "phase"]

## All unlockable ids (for UI / validation). Meta expands these, never flat stats.
const ALL_WEAPON_IDS: Array[String] = ["beam", "spread", "drones", "burst", "homing", "rear"]
## Synergy effects from upgrades (synergy_effect on .tres). Force-pair-only effects are in ALL_FORCE_PAIR_EFFECT_IDS.
const ALL_SYNERGY_EFFECT_IDS: Array[String] = ["afterimage", "shockwave_split", "electric_burst", "spreading_fire"]
const ALL_FORCE_PAIR_EFFECT_IDS: Array[String] = ["afterimage", "bending_beams", "gravity_slow"]

var meta: Dictionary = {}


func _ready() -> void:
	load_meta()


func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		meta = _default_meta()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		meta = _default_meta()
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		meta = _default_meta()
		return
	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		meta = _default_meta()
		return
	meta = data
	_ensure_meta_keys()


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(meta))
	file.close()


func _default_meta() -> Dictionary:
	return {
		META_TOTAL_CURRENCY: 0,
		META_TOTAL_RUNS: 0,
		META_BEST_STAGE: 0,
		META_UNLOCKED_WEAPONS: ["beam", "spread", "burst"],
		META_UNLOCKED_SYNERGY_EFFECTS: [],
		META_UNLOCKED_FORCE_PAIR_EFFECTS: [],
		META_MAGNET_LEVEL: 1,
		META_STARTING_ENERGY_LEVEL: 0,
		META_STARTING_HP_LEVEL: 0,
		META_REFRACTION_DUPLICATION: false,
		META_TIME_MODULES: [],
		META_REFRACTION_MODULES: [],
		META_INTRO_COMPLETED: false,
		META_FIRST_LAB_CHOICE_GRANTED: false,
		META_FIRST_LAB_CHOICE_MADE: false,
	}


func _ensure_meta_keys() -> void:
	if not meta.has(META_TOTAL_CURRENCY):
		meta[META_TOTAL_CURRENCY] = 0
	if not meta.has(META_TOTAL_RUNS):
		meta[META_TOTAL_RUNS] = 0
	if not meta.has(META_BEST_STAGE):
		meta[META_BEST_STAGE] = 0
	if not meta.has(META_UNLOCKED_WEAPONS):
		meta[META_UNLOCKED_WEAPONS] = ["beam", "spread"]
	if not meta.has(META_UNLOCKED_SYNERGY_EFFECTS):
		meta[META_UNLOCKED_SYNERGY_EFFECTS] = ["afterimage", "shockwave_split"]
	if not meta.has(META_UNLOCKED_FORCE_PAIR_EFFECTS):
		meta[META_UNLOCKED_FORCE_PAIR_EFFECTS] = ["afterimage"]
	# Migrate legacy saves: ensure arrays
	for key in [META_UNLOCKED_WEAPONS, META_UNLOCKED_SYNERGY_EFFECTS, META_UNLOCKED_FORCE_PAIR_EFFECTS]:
		if typeof(meta[key]) != TYPE_ARRAY:
			meta[key] = (_default_meta())[key]
	if not meta.has(META_MAGNET_LEVEL):
		meta[META_MAGNET_LEVEL] = 0
	if not meta.has(META_STARTING_ENERGY_LEVEL):
		meta[META_STARTING_ENERGY_LEVEL] = 0
	if not meta.has(META_STARTING_HP_LEVEL):
		meta[META_STARTING_HP_LEVEL] = 0
	if not meta.has(META_REFRACTION_DUPLICATION):
		meta[META_REFRACTION_DUPLICATION] = false
	if not meta.has(META_TIME_MODULES):
		meta[META_TIME_MODULES] = []
	if not meta.has(META_REFRACTION_MODULES):
		meta[META_REFRACTION_MODULES] = []
	if not meta.has(META_INTRO_COMPLETED):
		meta[META_INTRO_COMPLETED] = false
	# Migrate legacy refraction flag into module list.
	if bool(meta.get(META_REFRACTION_DUPLICATION, false)) and not is_refraction_module_unlocked("split"):
		var mods: Array = get_unlocked_refraction_modules()
		mods.append("split")
		meta[META_REFRACTION_MODULES] = mods

	# Ensure module lists are arrays.
	for key in [META_TIME_MODULES, META_REFRACTION_MODULES]:
		if typeof(meta[key]) != TYPE_ARRAY:
			meta[key] = []

	save()

	if not meta.has(META_FIRST_LAB_CHOICE_GRANTED):
		meta[META_FIRST_LAB_CHOICE_GRANTED] = false
	if not meta.has(META_FIRST_LAB_CHOICE_MADE):
		meta[META_FIRST_LAB_CHOICE_MADE] = false


func is_first_run() -> bool:
	return not meta.get(META_INTRO_COMPLETED, false)


func mark_intro_completed() -> void:
	meta[META_INTRO_COMPLETED] = true
	save()


func grant_first_lab_currency() -> void:
	if meta.get(META_FIRST_LAB_CHOICE_GRANTED, false):
		return
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) + FIRST_LAB_CHOICE_CURRENCY
	meta[META_FIRST_LAB_CHOICE_GRANTED] = true
	save()


func is_first_lab_choice_pending() -> bool:
	return bool(meta.get(META_FIRST_LAB_CHOICE_GRANTED, false)) and not bool(meta.get(META_FIRST_LAB_CHOICE_MADE, false))


func mark_first_lab_choice_made() -> void:
	meta[META_FIRST_LAB_CHOICE_MADE] = true
	save()


## Effective cost for display/unlock when in first-lab state (Temporal Echo, Refraction Split, Orbit Drone = 80).
func get_effective_first_choice_cost(category: String, id: String) -> int:
	if not is_first_lab_choice_pending():
		return -1
	if category == "refraction":
		return FIRST_LAB_CHOICE_CURRENCY
	if category == "weapon" and id == "drones":
		return FIRST_LAB_CHOICE_CURRENCY
	if category == "synergy" and id == "afterimage":
		return FIRST_LAB_CHOICE_CURRENCY
	if category == "time" and id == "temporal_echo":
		return FIRST_LAB_CHOICE_CURRENCY
	if category == "refraction_module" and id == "split":
		return FIRST_LAB_CHOICE_CURRENCY
	return -1


func add_currency(amount: int) -> void:
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) + amount
	save()


## Updates total_runs and best_stage; call after add_currency for this run.
func record_run(stages: int) -> void:
	meta[META_TOTAL_RUNS] = int(meta.get(META_TOTAL_RUNS, 0)) + 1
	var best: int = int(meta.get(META_BEST_STAGE, 0))
	if stages > best:
		meta[META_BEST_STAGE] = stages
	save()


func get_total_currency() -> int:
	return int(meta.get(META_TOTAL_CURRENCY, 0))


func get_total_runs() -> int:
	return int(meta.get(META_TOTAL_RUNS, 0))


func get_best_stage() -> int:
	return int(meta.get(META_BEST_STAGE, 0))


# ----- Meta progression: gameplay unlocks (no stat upgrades) -----

func get_unlocked_weapons() -> Array:
	var a = meta.get(META_UNLOCKED_WEAPONS, ["beam", "spread", "burst"])
	return a if typeof(a) == TYPE_ARRAY else ["beam", "spread", "burst"]


func is_weapon_unlocked(weapon_id: String) -> bool:
	return weapon_id in get_unlocked_weapons()


func unlock_weapon(weapon_id: String) -> bool:
	if weapon_id in get_unlocked_weapons():
		return true
	if weapon_id not in ALL_WEAPON_IDS:
		return false
	var cost: int = get_effective_first_choice_cost("weapon", weapon_id) if get_effective_first_choice_cost("weapon", weapon_id) >= 0 else UNLOCK_COST_WEAPON
	if get_total_currency() < cost:
		return false
	var list: Array = get_unlocked_weapons()
	list.append(weapon_id)
	meta[META_UNLOCKED_WEAPONS] = list
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) - cost
	if is_first_lab_choice_pending():
		mark_first_lab_choice_made()
	save()
	return true


func get_unlocked_synergy_effects() -> Array:
	var a = meta.get(META_UNLOCKED_SYNERGY_EFFECTS, [])
	return a if typeof(a) == TYPE_ARRAY else []


func is_synergy_effect_unlocked(effect_id: String) -> bool:
	return effect_id in get_unlocked_synergy_effects()


func unlock_synergy_effect(effect_id: String) -> bool:
	if effect_id in get_unlocked_synergy_effects():
		return true
	if effect_id not in ALL_SYNERGY_EFFECT_IDS:
		return false
	var cost: int = get_effective_first_choice_cost("synergy", effect_id) if get_effective_first_choice_cost("synergy", effect_id) >= 0 else UNLOCK_COST_SYNERGY
	if get_total_currency() < cost:
		return false
	var list: Array = get_unlocked_synergy_effects()
	list.append(effect_id)
	meta[META_UNLOCKED_SYNERGY_EFFECTS] = list
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) - cost
	if is_first_lab_choice_pending():
		mark_first_lab_choice_made()
	save()
	return true


func get_unlocked_force_pair_effects() -> Array:
	var a = meta.get(META_UNLOCKED_FORCE_PAIR_EFFECTS, [])
	return a if typeof(a) == TYPE_ARRAY else []


func is_force_pair_effect_unlocked(effect_id: String) -> bool:
	return effect_id in get_unlocked_force_pair_effects()


func unlock_force_pair_effect(effect_id: String) -> bool:
	if effect_id in get_unlocked_force_pair_effects():
		return true
	if effect_id not in ALL_FORCE_PAIR_EFFECT_IDS:
		return false
	var cost: int = UNLOCK_COST_FORCE_PAIR
	if get_total_currency() < cost:
		return false
	var list: Array = get_unlocked_force_pair_effects()
	list.append(effect_id)
	meta[META_UNLOCKED_FORCE_PAIR_EFFECTS] = list
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) - cost
	save()
	return true


# ----- Boss reward: grant one unlock for free (no stat boost). "I unlocked a new way to play." -----

func grant_unlock_weapon(weapon_id: String) -> bool:
	if weapon_id in get_unlocked_weapons():
		return true
	if weapon_id not in ALL_WEAPON_IDS:
		return false
	var list: Array = get_unlocked_weapons()
	list.append(weapon_id)
	meta[META_UNLOCKED_WEAPONS] = list
	save()
	return true


func grant_unlock_synergy_effect(effect_id: String) -> bool:
	if effect_id in get_unlocked_synergy_effects():
		return true
	if effect_id not in ALL_SYNERGY_EFFECT_IDS:
		return false
	var list: Array = get_unlocked_synergy_effects()
	list.append(effect_id)
	meta[META_UNLOCKED_SYNERGY_EFFECTS] = list
	save()
	return true


func grant_unlock_force_pair_effect(effect_id: String) -> bool:
	if effect_id in get_unlocked_force_pair_effects():
		return true
	if effect_id not in ALL_FORCE_PAIR_EFFECT_IDS:
		return false
	var list: Array = get_unlocked_force_pair_effects()
	list.append(effect_id)
	meta[META_UNLOCKED_FORCE_PAIR_EFFECTS] = list
	save()
	return true


# ----- Magnet tech: pickup radius bonus (stacks with base 3x radius) -----

func get_magnet_level() -> int:
	return int(meta.get(META_MAGNET_LEVEL, 0))


func get_magnet_radius_bonus() -> float:
	# Kept for backward-compat callers; bonus is expressed as an additive radius.
	# Prefer get_magnet_radius_multiplier() for % scaling.
	return 0.0


func get_magnet_radius_multiplier() -> float:
	return 1.0 + float(get_magnet_level()) * MAGNET_RADIUS_MULT_PER_LEVEL


func unlock_magnet_level() -> bool:
	var level: int = get_magnet_level()
	if level >= MAGNET_MAX_LEVEL:
		return true
	var cost: int = UNLOCK_COST_MAGNET_PER_LEVEL
	if get_total_currency() < cost:
		return false
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) - cost
	meta[META_MAGNET_LEVEL] = level + 1
	save()
	return true


# ----- Refraction Duplication (first meta: new gameplay system) -----

func is_refraction_unlocked() -> bool:
	# Back-compat: legacy boolean OR split module.
	return bool(meta.get(META_REFRACTION_DUPLICATION, false)) or is_refraction_module_unlocked("split")


func unlock_refraction() -> bool:
	if is_refraction_unlocked():
		return true
	var cost: int = get_effective_first_choice_cost("refraction", "") if get_effective_first_choice_cost("refraction", "") >= 0 else UNLOCK_COST_REFRACTION
	if get_total_currency() < cost:
		return false
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) - cost
	meta[META_REFRACTION_DUPLICATION] = true
	# Also mark split module for new progression.
	if not is_refraction_module_unlocked("split"):
		var mods: Array = get_unlocked_refraction_modules()
		mods.append("split")
		meta[META_REFRACTION_MODULES] = mods
	if is_first_lab_choice_pending():
		mark_first_lab_choice_made()
	save()
	return true


# ----- Starting energy (minimal stat: slight starting fragments per run) -----

func get_starting_energy_level() -> int:
	return int(meta.get(META_STARTING_ENERGY_LEVEL, 0))


func get_starting_energy_bonus() -> int:
	return get_starting_energy_level() * STARTING_ENERGY_BONUS


func unlock_starting_energy() -> bool:
	var level: int = get_starting_energy_level()
	if level >= STARTING_ENERGY_MAX_LEVEL:
		return true
	if get_total_currency() < UNLOCK_COST_STARTING_ENERGY:
		return false
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) - UNLOCK_COST_STARTING_ENERGY
	meta[META_STARTING_ENERGY_LEVEL] = level + 1
	save()
	return true


# ----- Starting HP (minimal stat: +1 max HP per level) -----

func get_starting_hp_level() -> int:
	return int(meta.get(META_STARTING_HP_LEVEL, 0))


func get_starting_hp_bonus() -> int:
	return get_starting_hp_level() * STARTING_HP_BONUS


func unlock_starting_hp() -> bool:
	var level: int = get_starting_hp_level()
	if level >= STARTING_HP_MAX_LEVEL:
		return true
	if get_total_currency() < UNLOCK_COST_STARTING_HP:
		return false
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) - UNLOCK_COST_STARTING_HP
	meta[META_STARTING_HP_LEVEL] = level + 1
	save()
	return true


# ----- Time Tech modules (meta systems) -----

func get_unlocked_time_modules() -> Array:
	var a = meta.get(META_TIME_MODULES, [])
	return a if typeof(a) == TYPE_ARRAY else []


func is_time_module_unlocked(module_id: String) -> bool:
	return module_id in get_unlocked_time_modules()


func unlock_time_module(module_id: String) -> bool:
	if is_time_module_unlocked(module_id):
		return true
	if module_id not in ALL_TIME_MODULE_IDS:
		return false
	var cost: int = get_effective_first_choice_cost("time", module_id) if get_effective_first_choice_cost("time", module_id) >= 0 else UNLOCK_COST_TIME_MODULE
	if get_total_currency() < cost:
		return false
	var list: Array = get_unlocked_time_modules()
	list.append(module_id)
	meta[META_TIME_MODULES] = list
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) - cost
	if is_first_lab_choice_pending():
		mark_first_lab_choice_made()
	save()
	return true


# ----- Refraction modules (meta systems) -----

func get_unlocked_refraction_modules() -> Array:
	var a = meta.get(META_REFRACTION_MODULES, [])
	return a if typeof(a) == TYPE_ARRAY else []


func is_refraction_module_unlocked(module_id: String) -> bool:
	return module_id in get_unlocked_refraction_modules()


func unlock_refraction_module(module_id: String) -> bool:
	if is_refraction_module_unlocked(module_id):
		return true
	if module_id not in ALL_REFRACTION_MODULE_IDS:
		return false
	var cost: int = get_effective_first_choice_cost("refraction_module", module_id) if get_effective_first_choice_cost("refraction_module", module_id) >= 0 else UNLOCK_COST_REFRACTION_MODULE
	if get_total_currency() < cost:
		return false
	var list: Array = get_unlocked_refraction_modules()
	list.append(module_id)
	meta[META_REFRACTION_MODULES] = list
	meta[META_TOTAL_CURRENCY] = int(meta.get(META_TOTAL_CURRENCY, 0)) - cost
	# Back-compat flag: split implies refraction unlocked for beam scripts still using is_refraction_unlocked.
	if module_id == "split":
		meta[META_REFRACTION_DUPLICATION] = true
	if is_first_lab_choice_pending():
		mark_first_lab_choice_made()
	save()
	return true
