extends RunWeaponBase
## Orbit Drones: drones orbit player, contact damage. Run identity = drone build.

@export var drone_count: int = 2
@export var drone_scene: PackedScene

var _drones: Array[Node] = []


func _ready() -> void:
	weapon_id = "drones"
	super._ready()
	if not drone_scene:
		drone_scene = preload("res://scenes/weapons/orbit_drone.tscn") as PackedScene
	_spawn_drones()


func _spawn_drones() -> void:
	var root := get_tree().current_scene
	var world := root.get_node_or_null("World") as Node2D
	if not world:
		world = root as Node2D
	for i in drone_count:
		var drone: Node = drone_scene.instantiate()
		if drone is OrbitDrone:
			var o := drone as OrbitDrone
			o.set_contact_damage(_damage_with_bonus())
			o._angle = TAU * float(i) / float(drone_count)
			o.weapon_tags = get_weapon_tags()
		world.add_child(drone)
		_drones.append(drone)


func _try_fire() -> void:
	# Drones do damage by contact; no per-shot fire. Keep base fire_rate from affecting anything.
	pass


func _process(delta: float) -> void:
	# Still run base to consume upgrade signals; no shot timer effect
	_time_until_shot -= delta
	if _time_until_shot <= 0.0:
		var rate := fire_rate + _fire_rate_bonus
		_time_until_shot = 1.0 / maxf(rate, 0.5)
	# Optionally refresh drone damage from upgrades
	for d in _drones:
		if is_instance_valid(d) and d is OrbitDrone:
			(d as OrbitDrone).set_contact_damage(_damage_with_bonus())
