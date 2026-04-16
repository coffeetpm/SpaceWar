extends Control
## Game Over overlay: message + R to restart.
## StageManager is the single authority: it shows UI/GameOver (Run End Menu). This panel stays hidden to avoid duplicate overlays.

func _ready() -> void:
	hide()
	EventBus.game_over.connect(_on_game_over)


func _on_game_over() -> void:
	# Do not show here; StageManager already showed the Run Over panel (game_over_path).
	pass


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_R:
			get_tree().reload_current_scene()
