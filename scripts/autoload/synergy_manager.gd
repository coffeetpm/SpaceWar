extends Node
## Synergy-driven upgrades: trigger off weapon/upgrade tags and force vocabulary (LIGHT/TIME/SPACE).
## Run identity = combination of forces. Synergies occur when forces interact.

const AFTERIMAGE_DELAY := 0.06
const AFTERIMAGE_DAMAGE_SCALE := 0.6
const ELECTRIC_BURST_RADIUS := 48.0
const ELECTRIC_BURST_DAMAGE := 2
const SHOCKWAVE_SPLIT_ANGLE := 0.35
const GRAVITY_SLOW_RADIUS := 80.0
const GRAVITY_SLOW_DURATION := 1.2

## Trigger name -> force (for force-pair synergies).
const TRIGGER_FORCE: Dictionary = {
	"pierce_pulse": "light",
	"light_pulse": "light",
	"pulse_fired": "time",
	"time_pulse": "time",
	"orbit_tick": "space",
	"space_tick": "space",
}

var _synergies: Array[Dictionary] = []
var _applied_tags: Array[String] = []
var _applied_forces: Array[String] = []   # force names from upgrades (light, time, space)
var _run_weapon_force: String = ""        # set when run starts
var _run_weapon_id: String = ""          # for build ignition (weapon + tag)
var _ignited_effects: Array[String] = []  # effect_ids already triggered this run


func _ready() -> void:
	pass


## Set run weapon force when run starts (run identity = combination of forces).
func set_run_weapon_force(weapon_id: String) -> void:
	_run_weapon_id = weapon_id
	if BuildVocabulary:
		_run_weapon_force = BuildVocabulary.get_weapon_force(weapon_id)
	else:
		_run_weapon_force = "light"


## Call when any upgrade is applied. Records tags and primary_force for synergy; checks build ignition.
func record_upgrade(upgrade: UpgradeData) -> void:
	if not upgrade:
		return
	var forces_before: int = get_run_forces().size()
	if upgrade.primary_force and upgrade.primary_force not in _applied_forces:
		_applied_forces.append(upgrade.primary_force)
	var newly_added_tags: Array[String] = []
	for tag in upgrade.tags:
		if tag and tag not in _applied_tags:
			_applied_tags.append(tag)
			newly_added_tags.append(tag)
	if upgrade.effect_type == &"synergy" and upgrade.synergy_trigger and upgrade.synergy_effect:
		_synergies.append({
			"trigger": upgrade.synergy_trigger,
			"effect": upgrade.synergy_effect,
			"require_source_tags": upgrade.require_source_tags,
			"require_upgrade_tags": upgrade.require_upgrade_tags,
		})
	if forces_before < 2 and get_run_forces().size() >= 2:
		if EventBus.has_signal("first_synergy_triggered"):
			EventBus.first_synergy_triggered.emit()
	_check_build_ignition(newly_added_tags)


func _check_build_ignition(new_tags: Array[String]) -> void:
	if not BuildVocabulary or _run_weapon_id.is_empty():
		return
	for tag in new_tags:
		var trigger: Dictionary = BuildVocabulary.get_ignition_trigger(_run_weapon_id, tag)
		if trigger.is_empty():
			continue
		var effect_id: String = trigger.get("effect_id", "")
		if effect_id.is_empty() or effect_id in _ignited_effects:
			continue
		var was_first_ignition: bool = _ignited_effects.is_empty()
		_ignited_effects.append(effect_id)
		if was_first_ignition and EventBus.has_signal("second_synergy_triggered"):
			EventBus.second_synergy_triggered.emit()
		var display_name: String = trigger.get("display_name", effect_id)
		var duration_sec: float = float(trigger.get("duration_sec", 8.0))
		var damage_mult: float = float(trigger.get("damage_mult", 1.5))
		if RunState and RunState.has_method("set_ignition"):
			RunState.set_ignition(duration_sec, damage_mult)
		if EventBus.has_signal("build_ignited"):
			EventBus.build_ignited.emit(effect_id, display_name, duration_sec)
		break


## Called by weapons/beam/drone when something happens. context: position, direction, damage, weapon_tags.
func fire_trigger(trigger_name: String, context: Dictionary) -> void:
	var weapon_tags: Array = context.get("weapon_tags", [])
	# Tag-based synergies (require_source_tags / require_upgrade_tags)
	for s in _synergies:
		if s.trigger != trigger_name:
			continue
		var req_src: Array = s.get("require_source_tags", [])
		var req_up: Array = s.get("require_upgrade_tags", [])
		if req_src.size() > 0:
			var ok := false
			for t in req_src:
				if t in weapon_tags:
					ok = true
					break
			if not ok:
				continue
		if req_up.size() > 0:
			var ok := false
			for t in req_up:
				if t in _applied_tags:
					ok = true
					break
			if not ok:
				continue
		_run_effect(s.effect, context)
	# Force-pair synergies (LIGHT+SPACE, TIME+LIGHT, SPACE+TIME)
	var trigger_force: String = TRIGGER_FORCE.get(trigger_name, "")
	if trigger_force and BuildVocabulary:
		var run_forces: Array[String] = []
		if _run_weapon_force:
			run_forces.append(_run_weapon_force)
		for f in _applied_forces:
			if f not in run_forces:
				run_forces.append(f)
		for other in run_forces:
			if other == trigger_force:
				continue
			var pair_effect: String = BuildVocabulary.get_force_pair_effect(trigger_force, other)
			if pair_effect:
				_run_effect(pair_effect, context)


func _run_effect(effect_name: String, context: Dictionary) -> void:
	if effect_name in ["afterimage", "bending_beams", "gravity_slow"]:
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.has_method("is_force_pair_effect_unlocked") and not save_mgr.is_force_pair_effect_unlocked(effect_name):
			return
	match effect_name:
		"afterimage":
			_effect_afterimage(context)
		"electric_burst":
			_effect_electric_burst(context)
		"shockwave_split":
			_effect_shockwave_split(context)
		"spreading_fire":
			_effect_spreading_fire(context)
		"bending_beams":
			_effect_bending_beams(context)
		"gravity_slow":
			_effect_gravity_slow(context)
		_:
			pass


func _effect_afterimage(context: Dictionary) -> void:
	var pos: Vector2 = context.get("position", Vector2.ZERO)
	var dir: Vector2 = context.get("direction", Vector2.UP).normalized()
	var damage: int = int(float(context.get("damage", 2)) * AFTERIMAGE_DAMAGE_SCALE)
	damage = maxi(1, damage)
	var speed: float = context.get("speed", 400.0) * 0.85
	get_tree().create_timer(AFTERIMAGE_DELAY).timeout.connect(func() -> void:
		EventBus.bullet_spawn_requested.emit(pos, dir, speed, damage, true, "")
	)


func _effect_electric_burst(context: Dictionary) -> void:
	var pos: Vector2 = context.get("position", Vector2.ZERO)
	var damage: int = context.get("damage", ELECTRIC_BURST_DAMAGE)
	var tree := get_tree()
	var space := tree.current_scene
	if not space:
		return
	for node in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue
		var n := node as Node2D
		if pos.distance_to(n.global_position) <= ELECTRIC_BURST_RADIUS:
			if n.has_method("take_damage"):
				n.take_damage(damage)
	EventBus.explosion_requested.emit(pos, 0.5, Color(0.5, 0.85, 1.0))


func _effect_shockwave_split(context: Dictionary) -> void:
	var pos: Vector2 = context.get("position", Vector2.ZERO)
	var dir: Vector2 = context.get("direction", Vector2.UP).normalized()
	var damage: int = context.get("damage", 2)
	var speed: float = context.get("speed", 450.0)
	var base_angle: float = dir.angle()
	for side in [-1, 1]:
		var angle: float = base_angle + side * SHOCKWAVE_SPLIT_ANGLE
		var d := Vector2.from_angle(angle)
		EventBus.bullet_spawn_requested.emit(pos, d, speed, damage, true, "")


func _effect_spreading_fire(context: Dictionary) -> void:
	var pos: Vector2 = context.get("position", Vector2.ZERO)
	var damage: int = context.get("damage", 1)
	var tree := get_tree()
	var spread_radius := 72.0
	var best: Node2D = null
	var best_d := spread_radius
	for node in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue
		var n := node as Node2D
		var d := pos.distance_to(n.global_position)
		if d < best_d and n.has_method("take_damage"):
			best_d = d
			best = n
	if best:
		best.take_damage(damage)
		EventBus.explosion_requested.emit(best.global_position, 0.25, Color(1.0, 0.5, 0.2))


func _effect_bending_beams(context: Dictionary) -> void:
	# LIGHT + SPACE: extra projectile at angle (bent beam).
	var pos: Vector2 = context.get("position", Vector2.ZERO)
	var dir: Vector2 = context.get("direction", Vector2.UP).normalized()
	var damage: int = context.get("damage", 2)
	var speed: float = context.get("speed", 400.0) * 0.7
	var bend_angle := 0.22
	for side in [-1, 1]:
		var d := Vector2.from_angle(dir.angle() + side * bend_angle)
		EventBus.bullet_spawn_requested.emit(pos, d, speed, damage, true, "")
	EventBus.explosion_requested.emit(pos, 0.2, Color(0.6, 0.9, 1.0))


func _effect_gravity_slow(context: Dictionary) -> void:
	# SPACE + TIME: apply slow to enemies in zone (via time_scale or slow flag).
	var pos: Vector2 = context.get("position", Vector2.ZERO)
	EventBus.explosion_requested.emit(pos, 0.6, Color(0.4, 0.5, 0.9))
	# Optional: emit a signal for slow zone; for now visual only to avoid new enemy logic.
	if EventBus.has_signal("time_scale_dip_requested"):
		EventBus.time_scale_dip_requested.emit(0.08, 0.4)


## Run forces (weapon + upgrades) for discovery UI. Empty until run has started and at least one upgrade applied.
func get_run_forces() -> Array[String]:
	var out: Array[String] = []
	if _run_weapon_force and _run_weapon_force not in out:
		out.append(_run_weapon_force)
	for f in _applied_forces:
		if f not in out:
			out.append(f)
	return out


## Weapon evolution tier: 1 = Core Tech (engineered, precise), 2 = Experimental (unstable phenomena).
## Tier 2 when run has 2+ forces or at least one build ignition. Use for visuals/UI (e.g. trail stability, "Unstable" feel).
func get_evolution_tier() -> int:
	if get_run_forces().size() >= 2:
		return 2
	if _ignited_effects.size() > 0:
		return 2
	return 1


## Clear on new run.
func clear_run() -> void:
	_synergies.clear()
	_applied_tags.clear()
	_applied_forces.clear()
	_run_weapon_force = ""
	_run_weapon_id = ""
	_ignited_effects.clear()
