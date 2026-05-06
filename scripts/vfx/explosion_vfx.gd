extends Node2D
class_name ExplosionVFX
## Impact: clean flash + energy spikes + optional digital glitch. No explosion clouds.

@export var particle_scene: PackedScene
@export var default_scale: float = 1.0
@export var default_color: Color = Color.CYAN

const SPIKE_COUNT := 8
const SPIKE_LENGTH := 28.0
const SPIKE_WIDTH := 2.2
const SPIKE_DURATION := 0.06
const GLITCH_LINE_HALFLEN := 18.0
const GLITCH_DURATION := 0.04

## 效能：additive material 一次性 preload，避免每次爆炸都 load（每爆炸原本呼 3 次）。
const ADDITIVE_MATERIAL := preload("res://resources/materials/additive_material.tres")
## 爆炸節流：同幀大量敵機死亡時降低煙火密度，避免爆幀。
var _explosions_this_frame: int = 0
const MAX_FULL_EXPLOSIONS_PER_FRAME: int = 4


func _ready() -> void:
	EventBus.explosion_requested.connect(_on_explosion_requested)


func _process(_delta: float) -> void:
	_explosions_this_frame = 0


func _on_explosion_requested(global_pos: Vector2, scale_factor: float, explosion_color: Color) -> void:
	if RunState and RunState.is_opening_phase():
		scale_factor *= RunState.opening_intensity_scale
	_spawn_explosion(global_pos, scale_factor, explosion_color)


func _spawn_explosion(pos: Vector2, scale_factor: float, explosion_color: Color) -> void:
	_explosions_this_frame += 1
	## 同幀過多爆炸時省略昂貴特效（只保留核心 burst + 閃光），避免 frame spike。
	var simplified: bool = _explosions_this_frame > MAX_FULL_EXPLOSIONS_PER_FRAME
	NeonExplosionBurst.spawn(self, pos, explosion_color, scale_factor)
	_spawn_core_flash(pos, scale_factor)
	if not simplified:
		_spawn_energy_spikes(pos, scale_factor)
		_spawn_digital_glitch(pos, scale_factor)
	if particle_scene and not simplified:
		var node: Node2D = particle_scene.instantiate()
		node.global_position = pos
		node.scale = Vector2.ONE * scale_factor * default_scale
		get_tree().current_scene.add_child(node)
		if node is GPUParticles2D:
			node.emitting = true
			node.finished.connect(node.queue_free)


func _spawn_core_flash(pos: Vector2, scale_factor: float) -> void:
	var flash := Polygon2D.new()
	var radius := 14.0 * scale_factor
	var points: PackedVector2Array = []
	for i in 12:
		var a := TAU * i / 12.0
		points.append(Vector2(cos(a), sin(a)) * radius)
	flash.polygon = points
	flash.color = ArtDirection.TIER1_EXPLOSION_CORE
	flash.material = ADDITIVE_MATERIAL
	flash.global_position = pos
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.07).from(Vector2(0.3, 0.3))
	tween.tween_property(flash, "modulate:a", 0.0, 0.07).from(1.0)
	tween.chain().tween_callback(func() -> void: flash.queue_free())


func _spawn_energy_spikes(pos: Vector2, scale_factor: float) -> void:
	var len := SPIKE_LENGTH * scale_factor
	var w := SPIKE_WIDTH * scale_factor
	for i in SPIKE_COUNT:
		var a := TAU * float(i) / float(SPIKE_COUNT)
		var line := Line2D.new()
		line.width = w
		line.default_color = ArtDirection.TIER1_ENERGY_SPIKE
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2(cos(a), sin(a)) * len)
		line.material = ADDITIVE_MATERIAL
		line.global_position = pos
		line.top_level = true
		get_tree().current_scene.add_child(line)
		## 合併為單一 tween 鏈，減少 Tween 物件數（原本每條 line 2 個 Tween）。
		var tween := line.create_tween()
		tween.set_parallel(true)
		tween.tween_property(line, "scale", Vector2(1.0, 1.0), SPIKE_DURATION * 0.5).from(Vector2(0.2, 0.2))
		tween.tween_property(line, "default_color:a", 0.0, SPIKE_DURATION).set_delay(SPIKE_DURATION * 0.3)
		tween.chain().tween_callback(func() -> void: line.queue_free())


func _spawn_digital_glitch(pos: Vector2, scale_factor: float) -> void:
	var half := GLITCH_LINE_HALFLEN * scale_factor
	var glitch_color := Color(0.5, 0.9, 1.0, 0.35)
	for dy in [-1, 1]:
		var line := Line2D.new()
		line.width = 1.2 * scale_factor
		line.default_color = glitch_color
		line.add_point(Vector2(-half, dy * 8.0))
		line.add_point(Vector2(half, dy * 8.0))
		line.material = ADDITIVE_MATERIAL
		line.global_position = pos
		line.top_level = true
		get_tree().current_scene.add_child(line)
		var tween := line.create_tween()
		tween.tween_property(line, "default_color:a", 0.0, GLITCH_DURATION)
		tween.tween_callback(func() -> void: line.queue_free())
