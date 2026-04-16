extends Node
## Shared combat queries: nearest enemy, aim direction. Used by player weapons and systems.

const ENEMY_GROUP := "enemy"


## Returns the nearest node in "enemy" group to origin, or null if none.
func get_nearest_enemy(origin: Vector2, tree: SceneTree) -> Node2D:
	if not tree:
		return null
	var nearest: Node2D = null
	var best_dist_sq := 1e10
	for node in tree.get_nodes_in_group(ENEMY_GROUP):
		if not is_instance_valid(node):
			continue
		var n := node as Node2D
		if not n:
			continue
		var d_sq := origin.distance_squared_to(n.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			nearest = n
	return nearest


## Direction from origin toward nearest enemy. Returns Vector2.ZERO if no enemy.
func get_direction_to_nearest_enemy(origin: Vector2, tree: SceneTree) -> Vector2:
	var nearest: Node2D = get_nearest_enemy(origin, tree) if tree else null
	if not nearest:
		return Vector2.ZERO
	return (nearest.global_position - origin).normalized()
