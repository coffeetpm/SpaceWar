extends GPUParticles2D
class_name HitSpark
## 子彈命中 / 消散小型霓虹火花。
## 自動 one-shot 發射，發射結束後 queue_free。
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

var _mat: ParticleProcessMaterial


func _ready() -> void:
	one_shot = true
	emitting = false
	explosiveness = 1.0
	lifetime = spark_lifetime
	amount = spark_amount
	_build_process_material()
	_apply_color()
	finished.connect(queue_free)


func _build_process_material() -> void:
	if _mat:
		return
	_mat = ParticleProcessMaterial.new()
	_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	_mat.direction = Vector3(0, 0, 0)
	_mat.spread = rad_to_deg(spread)
	_mat.flatness = 1.0
	_mat.initial_velocity_min = initial_speed * 0.6
	_mat.initial_velocity_max = initial_speed
	_mat.gravity = Vector3.ZERO
	_mat.damping_min = 420.0
	_mat.damping_max = 680.0
	_mat.scale_min = 0.35
	_mat.scale_max = 0.9
	## 尾段縮放衰減
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	_mat.scale_curve = scale_tex
	process_material = _mat
	if texture == null:
		texture = _make_spark_texture()


static func _make_spark_texture() -> Texture2D:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func _apply_color() -> void:
	modulate = hdr_color
	if _mat == null:
		return
	## 色彩漸變（頭端最亮，尾端透明）
	var grad := Gradient.new()
	grad.add_point(0.0, Color(hdr_color.r * 1.2, hdr_color.g * 1.2, hdr_color.b * 1.2, 1.0))
	grad.add_point(0.55, Color(hdr_color.r, hdr_color.g, hdr_color.b, 0.6))
	grad.add_point(1.0, Color(hdr_color.r, hdr_color.g, hdr_color.b, 0.0))
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	_mat.color_ramp = gtex


## 一次性建立 + 發射：掛到場景樹上，發射完畢自動釋放。
static func spawn(at: Node, at_position: Vector2, color: Color = Color(0.4, 1.6, 3.0, 1.0), spark_amount: int = 14) -> HitSpark:
	var spark := HitSpark.new()
	spark.hdr_color = color
	spark.spark_amount = spark_amount
	spark.global_position = at_position
	at.add_child(spark)
	spark.emitting = true
	return spark
