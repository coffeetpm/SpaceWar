extends Node
## PlayerRef autoload：提供 O(1) 存取 player 節點，取代遍歷整棵場景樹的 group 查詢。
## 用法：`var p := PlayerRef.get_player()` 或 `PlayerRef.player`。
## 自動透過 EventBus.run_started / player_died 維護；也接受外部手動註冊。

signal player_registered(player: Node2D)
signal player_cleared()

var player: Node2D = null


func _ready() -> void:
	process_priority = -1000
	if EventBus:
		if EventBus.has_signal("run_started"):
			EventBus.run_started.connect(_on_run_started)
		if EventBus.has_signal("player_died"):
			EventBus.player_died.connect(_on_player_died)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if player != null and is_instance_valid(player):
		return
	if node is Node2D and node.is_in_group("player"):
		register(node as Node2D)


func _on_run_started(_weapon_id: String) -> void:
	if player == null or not is_instance_valid(player):
		_refresh_from_tree()


func _on_player_died() -> void:
	## 不清除參照：UI / 死亡攝影機仍需存取最後位置。
	pass


func _refresh_from_tree() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var p := tree.get_first_node_in_group("player") as Node2D
	if p:
		register(p)


func register(p: Node2D) -> void:
	if p == player:
		return
	player = p
	player_registered.emit(p)
	if p and not p.tree_exited.is_connected(_on_player_tree_exited):
		p.tree_exited.connect(_on_player_tree_exited)


func _on_player_tree_exited() -> void:
	player = null
	player_cleared.emit()


func get_player() -> Node2D:
	if player and is_instance_valid(player):
		return player
	_refresh_from_tree()
	return player


func get_player_position() -> Vector2:
	var p := get_player()
	if p:
		return p.global_position
	return Vector2.ZERO


func has_player() -> bool:
	return player != null and is_instance_valid(player)
