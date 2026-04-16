extends RefCounted
class_name NeonExplosionBurst
## 敵機爆炸：雙層 GPUParticles2D（大方塊碎片 + 快火花），霓虹色可自訂。
## 性能：快取共用 texture / shader / base ParticleProcessMaterial，每次僅做 duplicate。

static var _pixel_tex: Texture2D
static var _shard_shader: Shader
static var _base_process_material: ParticleProcessMaterial


static func _ensure_pixel_texture() -> Texture2D:
	if _pixel_tex:
		return _pixel_tex
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_pixel_tex = ImageTexture.create_from_image(img)
	return _pixel_tex


static func _ensure_shard_shader() -> Shader:
	if _shard_shader:
		return _shard_shader
	_shard_shader = preload("res://resources/shaders/particle_neon_shard.gdshader")
	return _shard_shader


static func _ensure_base_process_material() -> ParticleProcessMaterial:
	if _base_process_material:
		return _base_process_material
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 16.0
	pm.particle_flag_disable_z = true
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.angular_velocity_min = -14.0
	pm.angular_velocity_max = 14.0
	pm.gravity = Vector3(0, 0, 0)
	pm.damping_min = 0.22
	pm.damping_max = 1.45
	pm.hue_variation_min = -0.14
	pm.hue_variation_max = 0.14
	_base_process_material = pm
	return _base_process_material


static func spawn(from_node: Node, global_pos: Vector2, neon_color: Color, scale_factor: float) -> void:
	if from_node == null or not is_instance_valid(from_node):
		return
	var tree := from_node.get_tree()
	if tree == null:
		return
	var root := tree.current_scene
	if root == null:
		return
	var s: float = maxf(scale_factor, 0.35)
	var c1 := neon_color
	var c2 := neon_color.lerp(Color(1.0, 0.45, 0.85, 1.0), 0.22)
	_spawn_layer(root, global_pos, c1, s, 1.0, 0.78, 0.96)
	_spawn_layer(root, global_pos, c2, s * 0.9, 1.42, 0.4, 0.9)


static func _spawn_layer(
		root: Node,
		global_pos: Vector2,
		neon_color: Color,
		size_scale: float,
		velocity_mul: float,
		lifetime_scale: float,
		explosiveness: float
	) -> void:
	var gpu := GPUParticles2D.new()
	gpu.z_index = 8
	gpu.global_position = global_pos
	gpu.amount = clampi(int(175 * size_scale * velocity_mul), 80, 440)
	gpu.lifetime = 0.52 * lifetime_scale
	gpu.one_shot = true
	gpu.explosiveness = explosiveness
	gpu.randomness = 0.58
	gpu.local_coords = false
	gpu.visibility_rect = Rect2(-560, -560, 1120, 1120)
	gpu.texture = _ensure_pixel_texture()

	var pm: ParticleProcessMaterial = _ensure_base_process_material().duplicate(true) as ParticleProcessMaterial
	pm.emission_sphere_radius = 16.0 * size_scale
	pm.initial_velocity_min = 95.0 * size_scale * velocity_mul
	pm.initial_velocity_max = 440.0 * size_scale * velocity_mul
	pm.scale_min = 0.26 * size_scale
	pm.scale_max = 1.5 * size_scale
	pm.color = neon_color
	gpu.process_material = pm

	var sm := ShaderMaterial.new()
	sm.shader = _ensure_shard_shader()
	sm.set_shader_parameter("neon", neon_color)
	sm.set_shader_parameter("edge_boost", 8.0)
	gpu.material = sm

	root.add_child(gpu)
	gpu.emitting = true
	gpu.finished.connect(func() -> void:
		if is_instance_valid(gpu):
			gpu.queue_free()
	)
