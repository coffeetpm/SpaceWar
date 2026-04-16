extends Node
## NeonStyleManager（Autoload）
## 目的：集中管理所有敵機 / 單位的程序化霓虹裝飾，避免逐個場景手動設計。
##
## 使用方式：
##   NeonStyleManager.apply_to(enemy)            # Tier 自動推斷
##   NeonStyleManager.apply_to(enemy, 4)         # 強制指定 Tier
##   NeonStyleManager.apply_to(enemy, -1, my_color)  # 指定顏色覆蓋
##
## Tier 等級
##   1 雜兵（Scout/Drone 類）   — 單對細翼
##   2 標準（Basic/Dasher/Shooter） — 翼 + 微光環
##   3 重型（Tank）              — 大翼 + 光環 + 2 碎片環繞
##   4 精英（Elite）             — 大翼 + 光環 + 4 碎片
##   5 Boss / Titan             — 巨翼 + 強光環 + 6 碎片 + 皇冠

const NeonWingGenerator := preload("res://scripts/vfx/neon_wing_generator.gd")
const NeonOrbiter := preload("res://scripts/vfx/neon_orbiter.gd")
const ADDITIVE_MATERIAL_PATH := "res://resources/materials/additive_material.tres"

const STYLE_ROOT_NAME := "NeonStyle"

## Tier 對應視覺參數
const TIER_PRESETS: Dictionary = {
	1: {
		"wing_length": 14.0, "wing_span": 8.0,
		"wing_frequency": 6.5, "wing_intensity": 1.85, "wing_flow_speed": 2.4,
		"halo": false, "halo_radius": 0.0,
		"shards": 0, "shard_radius": 0.0, "shard_size": 0.0, "shard_speed": 0.0,
		"crown": false,
	},
	2: {
		"wing_length": 20.0, "wing_span": 12.0,
		"wing_frequency": 4.0, "wing_intensity": 1.95, "wing_flow_speed": 1.8,
		"halo": true, "halo_radius": 20.0,
		"shards": 0, "shard_radius": 0.0, "shard_size": 0.0, "shard_speed": 0.0,
		"crown": false,
	},
	3: {
		"wing_length": 26.0, "wing_span": 18.0,
		"wing_frequency": 2.4, "wing_intensity": 2.15, "wing_flow_speed": 1.1,
		"halo": true, "halo_radius": 26.0,
		"shards": 2, "shard_radius": 28.0, "shard_size": 5.0, "shard_speed": PI * 0.6,
		"crown": false,
	},
	4: {
		"wing_length": 28.0, "wing_span": 20.0,
		"wing_frequency": 3.6, "wing_intensity": 2.35, "wing_flow_speed": 1.6,
		"halo": true, "halo_radius": 30.0,
		"shards": 4, "shard_radius": 32.0, "shard_size": 6.0, "shard_speed": PI * 0.9,
		"crown": false,
	},
	5: {
		"wing_length": 56.0, "wing_span": 40.0,
		"wing_frequency": 2.8, "wing_intensity": 2.55, "wing_flow_speed": 1.3,
		"halo": true, "halo_radius": 64.0,
		"shards": 6, "shard_radius": 72.0, "shard_size": 10.0, "shard_speed": PI * 0.45,
		"crown": true,
	},
}

## 快取 additive 材質
var _additive_material: Material = null


func _ready() -> void:
	process_priority = -50


# -----------------------------------------------------------------------------
# 公開 API
# -----------------------------------------------------------------------------

## 套用霓虹裝飾。若 tier < 0 則自動推斷；若 color_override 提供則使用指定色。
func apply_to(target: Node2D, tier: int = -1, color_override: Variant = null) -> Node2D:
	if target == null or not is_instance_valid(target):
		return null
	## 防重入：已套用過就返回既有根節點
	var existing := target.get_node_or_null(STYLE_ROOT_NAME) as Node2D
	if existing:
		return existing

	if tier < 0:
		tier = infer_tier(target)
	tier = clampi(tier, 1, TIER_PRESETS.size())
	var preset: Dictionary = TIER_PRESETS[tier]

	var color: Color
	if color_override is Color:
		color = color_override
	else:
		color = _resolve_color(target)

	var style := Node2D.new()
	style.name = STYLE_ROOT_NAME
	style.z_as_relative = true
	style.z_index = -1
	style.set_meta("tier", tier)
	target.add_child(style)

	_add_wings(style, color, preset)
	if preset["halo"]:
		_add_halo(style, color, preset)
	var shard_count: int = int(preset["shards"])
	for i in shard_count:
		_add_shard(style, color, i, shard_count, preset)
	if preset["crown"]:
		_add_crown(style, color, preset)

	return style


## 移除霓虹裝飾。
func remove_from(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var root := target.get_node_or_null(STYLE_ROOT_NAME)
	if root:
		root.queue_free()


## Tier 自動推斷：優先依名稱關鍵字；否則根據 max_hp / groups。
func infer_tier(target: Node2D) -> int:
	var name_lower := str(target.name).to_lower()
	if name_lower.contains("boss") or name_lower.contains("titan"):
		return 5
	if name_lower.contains("elite") or name_lower.contains("champion"):
		return 4
	if name_lower.contains("tank") or name_lower.contains("heavy"):
		return 3
	if name_lower.contains("scout") or name_lower.contains("drone"):
		return 1

	## 依 max_hp fallback
	if "max_hp" in target:
		var hp: int = int(target.max_hp)
		if hp >= 12: return 5
		if hp >= 6: return 4
		if hp >= 3: return 3
		if hp >= 2: return 2
		return 1

	## 依群組
	if target.is_in_group("boss"):
		return 5
	return 2


# -----------------------------------------------------------------------------
# 顏色決策
# -----------------------------------------------------------------------------

func _resolve_color(target: Node2D) -> Color:
	## 優先使用 NeonWingGenerator 的名稱配色表，確保與既有敵機一致。
	return NeonWingGenerator.resolve_color_for_name(str(target.name))


# -----------------------------------------------------------------------------
# 各裝飾生成
# -----------------------------------------------------------------------------

func _add_wings(parent: Node2D, color: Color, preset: Dictionary) -> void:
	var wings := Node2D.new()
	wings.name = "Wings"
	wings.set_script(NeonWingGenerator)
	wings.auto_color_from_parent = false
	wings.neon_color = color
	wings.wing_length = float(preset["wing_length"])
	wings.wing_span = float(preset["wing_span"])
	wings.wing_frequency = float(preset["wing_frequency"])
	wings.wing_intensity = float(preset["wing_intensity"])
	wings.wing_flow_speed = float(preset["wing_flow_speed"])
	parent.add_child(wings)


func _add_halo(parent: Node2D, color: Color, preset: Dictionary) -> void:
	var halo := Line2D.new()
	halo.name = "Halo"
	halo.z_index = -2
	halo.width = 1.8
	halo.default_color = Color(color.r, color.g, color.b, 0.78)
	halo.material = _get_additive_material()
	halo.joint_mode = Line2D.LINE_JOINT_ROUND
	var radius: float = float(preset["halo_radius"])
	var segments := 28
	var pts := PackedVector2Array()
	pts.resize(segments + 1)
	for i in segments + 1:
		var a: float = TAU * float(i) / float(segments)
		pts[i] = Vector2(cos(a), sin(a)) * radius
	halo.points = pts
	halo.modulate = Color(1, 1, 1, 0.35)
	parent.add_child(halo)
	## 呼吸脈動
	var tw := halo.create_tween().set_loops()
	tw.tween_property(halo, "modulate:a", 0.95, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(halo, "modulate:a", 0.30, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_shard(parent: Node2D, color: Color, idx: int, total: int, preset: Dictionary) -> void:
	var pivot := Node2D.new()
	pivot.name = "Shard%d" % idx
	pivot.set_script(NeonOrbiter)
	pivot.rotation_speed = float(preset["shard_speed"])
	pivot.rotation = TAU * float(idx) / float(maxi(1, total))
	pivot.z_index = -1

	var radius: float = float(preset["shard_radius"])
	var sz: float = float(preset["shard_size"])
	var shard := Polygon2D.new()
	shard.polygon = PackedVector2Array([
		Vector2(radius, -sz * 0.5),
		Vector2(radius + sz, 0.0),
		Vector2(radius, sz * 0.5),
		Vector2(radius - sz * 0.6, 0.0),
	])
	shard.color = color
	shard.material = _get_additive_material()
	pivot.add_child(shard)

	## 微脈動（輕微擴縮）
	parent.add_child(pivot)
	var tw := shard.create_tween().set_loops()
	tw.tween_property(shard, "modulate", Color(1.35, 1.35, 1.35, 1), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(shard, "modulate", Color(0.75, 0.75, 0.75, 1), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_crown(parent: Node2D, color: Color, _preset: Dictionary) -> void:
	## 單片 concave 多邊形：三齒皇冠輪廓（向上 = -y）
	var crown := Polygon2D.new()
	crown.name = "Crown"
	crown.z_index = -1
	crown.position = Vector2(0, -8)
	crown.color = color
	crown.material = _get_additive_material()
	var r := 22.0
	crown.polygon = PackedVector2Array([
		Vector2(-r * 1.05, -r * 0.05),
		Vector2(-r * 0.95, -r * 0.95),
		Vector2(-r * 0.55, -r * 0.45),
		Vector2(-r * 0.30, -r * 1.30),
		Vector2(0.0, -r * 0.55),
		Vector2(r * 0.30, -r * 1.30),
		Vector2(r * 0.55, -r * 0.45),
		Vector2(r * 0.95, -r * 0.95),
		Vector2(r * 1.05, -r * 0.05),
		Vector2(r * 0.80, r * 0.18),
		Vector2(-r * 0.80, r * 0.18),
	])
	parent.add_child(crown)
	var tw := crown.create_tween().set_loops()
	tw.tween_property(crown, "modulate", Color(1.5, 1.5, 1.5, 1), 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(crown, "modulate", Color(0.9, 0.9, 0.9, 1), 0.85).set_trans(Tween.TRANS_SINE)


# -----------------------------------------------------------------------------
# 資源快取
# -----------------------------------------------------------------------------

func _get_additive_material() -> Material:
	if _additive_material:
		return _additive_material
	_additive_material = load(ADDITIVE_MATERIAL_PATH) as Material
	return _additive_material
