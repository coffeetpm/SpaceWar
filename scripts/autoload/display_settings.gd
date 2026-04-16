extends Node
## Manages display mode, resolution, and UI scale. Saves to user://settings.cfg.
## On first launch: borderless fullscreen at desktop resolution.

const CONFIG_PATH := "user://settings.cfg"
const SECTION_DISPLAY := "display"

## Display mode enum for internal use.
const MODE_WINDOWED := 0
const MODE_FULLSCREEN := 1
const MODE_BORDERLESS := 2

## UI scale range.
const UI_SCALE_MIN := 0.9
const UI_SCALE_MAX := 1.3
const UI_SCALE_STEP := 0.1

## Common PC resolutions.
const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

signal settings_changed

var display_mode: int = MODE_BORDERLESS
var resolution: Vector2i = Vector2i(1920, 1080)
var ui_scale: float = 1.0


func _ready() -> void:
	_load_settings()
	_apply_display()


func is_first_run() -> bool:
	return not FileAccess.file_exists(CONFIG_PATH)


func _load_settings() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		_set_defaults_for_first_run()
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		_set_defaults_for_first_run()
		return
	display_mode = cfg.get_value(SECTION_DISPLAY, "display_mode", MODE_BORDERLESS)
	var rx: int = cfg.get_value(SECTION_DISPLAY, "resolution_x", 1920)
	var ry: int = cfg.get_value(SECTION_DISPLAY, "resolution_y", 1080)
	resolution = Vector2i(rx, ry)
	ui_scale = clampf(cfg.get_value(SECTION_DISPLAY, "ui_scale", 1.0), UI_SCALE_MIN, UI_SCALE_MAX)


func _set_defaults_for_first_run() -> void:
	display_mode = MODE_BORDERLESS
	resolution = DisplayServer.screen_get_size()
	ui_scale = 1.0


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_DISPLAY, "display_mode", display_mode)
	cfg.set_value(SECTION_DISPLAY, "resolution_x", resolution.x)
	cfg.set_value(SECTION_DISPLAY, "resolution_y", resolution.y)
	cfg.set_value(SECTION_DISPLAY, "ui_scale", ui_scale)
	cfg.save(CONFIG_PATH)


func apply_settings() -> void:
	_apply_display()
	save_settings()
	settings_changed.emit()


func set_display_mode(mode: int) -> void:
	display_mode = mode


func set_resolution(res: Vector2i) -> void:
	resolution = res


func set_ui_scale(scale_val: float) -> void:
	ui_scale = clampf(scale_val, UI_SCALE_MIN, UI_SCALE_MAX)


func _apply_display() -> void:
	match display_mode:
		MODE_WINDOWED:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
		MODE_FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size := DisplayServer.screen_get_size()
			DisplayServer.window_set_size(screen_size)
			DisplayServer.window_set_position(Vector2i(0, 0))


func get_resolution_index() -> int:
	for i in range(COMMON_RESOLUTIONS.size()):
		if COMMON_RESOLUTIONS[i] == resolution:
			return i
	# If current resolution not in list, add/use closest or desktop
	return _closest_resolution_index(resolution)


func _closest_resolution_index(res: Vector2i) -> int:
	var best := 0
	var best_dist := INF
	for i in range(COMMON_RESOLUTIONS.size()):
		var r: Vector2i = COMMON_RESOLUTIONS[i]
		var d := (res.x - r.x) * (res.x - r.x) + (res.y - r.y) * (res.y - r.y)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func get_ui_scale_slider_value() -> float:
	return (ui_scale - UI_SCALE_MIN) / (UI_SCALE_MAX - UI_SCALE_MIN)


func set_ui_scale_from_slider(normalized: float) -> void:
	ui_scale = UI_SCALE_MIN + normalized * (UI_SCALE_MAX - UI_SCALE_MIN)

