extends Node2D
class_name NeonOrbiter
## 極輕量自旋節點：用於 NeonStyleManager 產生嘅護甲碎片環繞動畫。
## 獨立 _process 避免 Tween.set_loops() 回捲時嘅視覺跳動。

@export var rotation_speed: float = PI  # rad/s（正數逆時針）

func _process(delta: float) -> void:
	if RunState and RunState.gameplay_frozen:
		return
	rotation += rotation_speed * delta
