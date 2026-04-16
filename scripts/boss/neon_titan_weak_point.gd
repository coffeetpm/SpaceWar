extends Area2D
class_name NeonTitanWeakPoint
## NeonTitan 弱點代理：由 bullet.gd 的 _on_area_entered 呼叫 take_damage。
## 將傷害轉發至 parent boss 的 damage_weak_point(index, amount)。

@export var weak_point_index: int = 0


func _ready() -> void:
	if not is_in_group("boss"):
		add_to_group("boss")
	if not is_in_group("boss_weak_point"):
		add_to_group("boss_weak_point")


func take_damage(amount: int) -> void:
	var p: Node = get_parent()
	while p and not (p is NeonTitan):
		p = p.get_parent()
	if p and p.has_method("damage_weak_point"):
		var idx: int = weak_point_index
		if has_meta("weak_point_index"):
			idx = int(get_meta("weak_point_index"))
		p.damage_weak_point(idx, amount)
