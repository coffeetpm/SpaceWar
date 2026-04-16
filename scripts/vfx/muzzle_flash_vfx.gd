extends Node2D
## Procedural muzzle flash per weapon: engineered shapes — directional beams, charged discharge, multi-emitter. Sharp edges.

## weapon_id -> { duration, scale, color, shape }. Cadence = duration per weapon (pulse timing visible).
## Beam = line. Burst = spike (longer). Spread = fan. Homing = line. Rear = emitter. Drones = ring.
const FLASH_STYLES: Dictionary = {
	"beam": {"duration": 0.035, "scale": 5.5, "color": Color(0.35, 0.9, 1.0, 0.68), "shape": "line"},
	"burst": {"duration": 0.09, "scale": 7.5, "color": Color(0.95, 0.75, 0.4, 0.78), "shape": "spike"},
	"spread": {"duration": 0.055, "scale": 9.0, "color": Color(0.45, 0.88, 1.0, 0.7), "shape": "fan"},
	"homing": {"duration": 0.048, "scale": 5.0, "color": Color(0.4, 1.0, 0.65, 0.65), "shape": "line"},
	"rear": {"duration": 0.065, "scale": 7.0, "color": Color(0.88, 0.5, 0.92, 0.62), "shape": "emitter"},
	"drones": {"duration": 0.05, "scale": 6.0, "color": Color(0.4, 0.8, 1.0, 0.5), "shape": "ring"},
}

var _flashes: Array[CanvasItem] = []
var _flash_timers: Array[float] = []
var _add_mat: Material


func _ready() -> void:
	_add_mat = load("res://resources/materials/additive_material.tres") as Material
	if EventBus.has_signal("muzzle_flash_requested"):
		EventBus.muzzle_flash_requested.connect(_on_muzzle_flash_requested)


func _on_muzzle_flash_requested(global_pos: Vector2, weapon_id: String) -> void:
	var style: Variant = FLASH_STYLES.get(weapon_id, {})
	if style is Dictionary and style.size() == 0:
		return
	var duration: float = float(style.get("duration", 0.06))
	if duration <= 0.0:
		return
	if LightLanguage and LightLanguage.has_method("get_glow_pulse_duration"):
		var rhythm_duration: float = LightLanguage.get_glow_pulse_duration(weapon_id)
		if rhythm_duration > 0.0:
			duration = rhythm_duration
	var scale_val: float = float(style.get("scale", 8.0))
	var color_val: Color = style.get("color", Color(0.5, 0.8, 1.0, 0.5))
	var shape: String = str(style.get("shape", "line"))
	var node: CanvasItem = _make_engineered_flash(shape, scale_val, color_val)
	if not node:
		return
	node.position = global_pos
	node.top_level = true
	add_child(node)
	_flashes.append(node)
	_flash_timers.append(duration)


func _make_engineered_flash(shape: String, scale_val: float, color_val: Color) -> CanvasItem:
	if shape == "spike":
		var line := Line2D.new()
		line.width = scale_val * 0.5
		line.default_color = color_val
		line.add_point(Vector2(0, 0))
		line.add_point(Vector2(0, -scale_val * 1.1))
		if _add_mat:
			line.material = _add_mat
		return line
	if shape == "fan":
		var container := Node2D.new()
		container.name = "FanFlash"
		var spread_deg := 22.0
		for i in 3:
			var a := deg_to_rad(-spread_deg + spread_deg * i)
			var line := Line2D.new()
			line.width = scale_val * 0.35
			line.default_color = color_val
			line.add_point(Vector2(0, 0))
			line.add_point(Vector2(sin(a), -cos(a)) * scale_val)
			if _add_mat:
				line.material = _add_mat
			container.add_child(line)
		return container
	if shape == "emitter":
		var poly := Polygon2D.new()
		var pts: PackedVector2Array = []
		for i in 6:
			var a := TAU * i / 6.0
			pts.append(Vector2(cos(a), sin(a)) * scale_val * 0.6)
		poly.polygon = pts
		poly.color = color_val
		if _add_mat:
			poly.material = _add_mat
		return poly
	if shape == "ring":
		var line := Line2D.new()
		line.width = scale_val * 0.25
		line.default_color = color_val
		var pts: PackedVector2Array = []
		const SEG := 12
		for i in SEG + 1:
			var a := TAU * float(i) / float(SEG)
			pts.append(Vector2(cos(a), sin(a)) * scale_val * 0.5)
		line.points = pts
		if _add_mat:
			line.material = _add_mat
		return line
	var line := Line2D.new()
	line.width = scale_val * 0.45
	line.default_color = color_val
	line.add_point(Vector2(0, 0))
	line.add_point(Vector2(0, -scale_val))
	if _add_mat:
		line.material = _add_mat
	return line


func _process(delta: float) -> void:
	for i in range(_flash_timers.size() - 1, -1, -1):
		_flash_timers[i] -= delta
		if _flash_timers[i] <= 0.0:
			var n: CanvasItem = _flashes[i]
			if is_instance_valid(n):
				n.queue_free()
			_flashes.remove_at(i)
			_flash_timers.remove_at(i)
