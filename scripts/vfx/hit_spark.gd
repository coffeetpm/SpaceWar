extends GPUParticles2D
class_name HitSpark
## 子彈命中 / 消散小型霓虹火花。
## 自動 one-shot 發射，發射結束後 queue_free。
##
## 效能：共用 texture / scale curve，ParticleProcessMaterial 依顏色快取 duplicate，
## 避免每次 spawn 重新構造 GPU 資源。
##
## 使用：
##   HitSpark.spawn(scene_tree_root, global_pos, hdr_color)

@export var hdr_color: Color = Color(0.4, 1.6, 3.0, 1.0):
	set(v):
		hdr_color = v
		_apply_color()

@export_range(0.05, 0.8) var spark_lifetime: float = 0.28
@export var spark_amount: int = 14
@export var initial_speed: float = 260.0
@export_range(0.0, PI) var spread: float = PI  # 全方位

## 靜態快取：多個 HitSpark 共用同一組 texture + curve，避免每次 new。
static var _shared_texture: Texture2D = null
static var _shared_scale_curve_tex: CurveTexture = null
## 每種 HDR 色快取一份 ParticleProcessMaterial（duplicate base 而非重建）。
## key = Color 的 stringify；value = ParticleProcessMaterial。
static var _material_cache: Dictionary = {}

var _mat: ParticleProcessMaterial


func _ready() -> void:
	one_shot = true
	emitting = false
	explosiveness = 1.0
	lifetime = spark_lifetime
	amount = spark_amount
	if texture == null:
		texture = _get_shared_texture()
	_apply_color()
	finished.connect(queue_free)


## 取得 / 建立該 HDR 色對應的 ParticleProcessMaterial（快取）。
static func _get_or_create_material(c: Color) -> ParticleProcessMaterial:
	var key: String = "%.2f_%.2f_%.2f" % [c.r, c.g, c.b]
	if _material_cache.has(key):
		return _material_cache[key] as ParticleProcessMaterial
	var m: ParticleProcessMaterial = ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	m.direction = Vector3(0, 0, 0)
	m.spread = 180.0
	m.flatness = 1.0
	m.initial_velocity_min = 156.0
	m.initial_velocity_max = 260.0
	m.gravity = Vector3.ZERO
	m.damping_min = 420.0
	m.damping_max = 680.0
	m.scale_min = 0.35
	m.scale_max = 0.9
	m.scale_curve = _get_shared_scale_curve()
	## 色彩漸變（頭端最亮，尾端透明）— 依顏色建立，共用於同色 spark。
	var grad: Gradient = Gradient.new()
	grad.add_point(0.0, Color(c.r * 1.2, c.g * 1.2, c.b * 1.2, 1.0))
	grad.add_point(0.55, Color(c.r, c.g, c.b, 0.6))
	grad.add_point(1.0, Color(c.r, c.g, c.b, 0.0))
	var gtex: GradientTexture1D = GradientTexture1D.new()
	gtex.gradient = grad
	m.color_ramp = gtex
	_material_cache[key] = m
	return m


static func _get_shared_scale_curve() -> CurveTexture:
	if _shared_scale_curve_tex:
		return _shared_scale_curve_tex
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	_shared_scale_curve_tex = CurveTexture.new()
	_shared_scale_curve_tex.curve = curve
	return _shared_scale_curve_tex


static func _get_shared_texture() -> Texture2D:
	if _shared_texture:
		return _shared_texture
	var img: Image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_shared_texture = ImageTexture.create_from_image(img)
	return _shared_texture


func _apply_color() -> void:
	modulate = hdr_color
	_mat = _get_or_create_material(hdr_color)
	process_material = _mat


## 一次性建立 + 發射：掛到場景樹上，發射完畢自動釋放。
static func spawn(at: Node, at_position: Vector2, color: Color = Color(0.4, 1.6, 3.0, 1.0), spark_count: int = 14) -> HitSpark:
	var spark: HitSpark = HitSpark.new()
	spark.hdr_color = color
	spark.spark_amount = spark_count
	spark.global_position = at_position
	at.add_child(spark)
	spark.emitting = true
	return spark
