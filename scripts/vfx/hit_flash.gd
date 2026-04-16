extends Node
class_name HitFlash
## One-shot hit flash on a CanvasItem, or full-screen vignette when target is null.

@export var default_duration: float = 0.1
@export var flash_color: Color = Color.WHITE
@export var flash_modulate: Color = Color(2.0, 2.0, 2.0)
@export var fullscreen_flash_color: Color = Color(0.9, 0.4, 0.5, 0.4)

@onready var _fullscreen_rect: ColorRect = $FlashLayer/FullScreenFlash

func _ready() -> void:
	EventBus.hit_flash_requested.connect(_on_hit_flash_requested)
	if _fullscreen_rect:
		_fullscreen_rect.color = Color(0, 0, 0, 0)
		fullscreen_flash_color = ArtDirection.PLAYER_DAMAGE_FLASH
		var mat := load("res://resources/materials/vignette_flash_material.tres") as Material
		if mat:
			_fullscreen_rect.material = mat


func _on_hit_flash_requested(target: CanvasItem, duration: float) -> void:
	_run_flash(target, duration if duration > 0 else default_duration)


func _run_flash(target: CanvasItem, duration: float) -> void:
	if target != null:
		if not is_instance_valid(target):
			return
		var original := target.modulate
		target.modulate = flash_modulate
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(target):
			target.modulate = original
	else:
		_run_fullscreen_flash(duration)


func _run_fullscreen_flash(duration: float) -> void:
	if not _fullscreen_rect:
		return
	_fullscreen_rect.color = fullscreen_flash_color
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(_fullscreen_rect):
		_fullscreen_rect.color = Color(0, 0, 0, 0)
