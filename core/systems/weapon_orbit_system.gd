class_name WeaponOrbitSystem
extends RefCounted

const ORBIT_RADIUS: float = 32.0
const TWO_PI: float = PI * 2.0

func update(world: ECSWorld, delta: float) -> void:
	if world.players.size() == 0:
		return
	if world.weapon_entities.size() == 0:
		return

	var player_pos = world.player_position
	var weapon_count = world.weapon_entities.size()

	var nearest_enemy_id = _find_nearest_enemy(world)
	var nearest_pos: Vector2 = player_pos + Vector2.RIGHT * 100
	if nearest_enemy_id != -1:
		nearest_pos = world.transforms[nearest_enemy_id]["position"]

	for weid in world.weapon_entities:
		if not world.transforms.has(weid):
			continue
		var wedata = world.weapon_entities[weid]
		var index = wedata["index"]
		var total = wedata["total"]

		var angle = _calc_orbit_angle(index, total)
		var target_pos = player_pos + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS

		var trans = world.transforms[weid]
		trans["position"] = target_pos

		if world.sprites.has(weid):
			if nearest_enemy_id != -1:
				var aim_dir = (nearest_pos - target_pos).angle()
				world.sprites[weid]["rotation"] = aim_dir
			else:
				world.sprites[weid]["rotation"] = angle + PI / 2.0

func _calc_orbit_angle(index: int, total: int) -> float:
	if total == 1:
		return 0.0
	var angle_step = TWO_PI / total
	var start_angle = -PI / 2.0
	return start_angle + angle_step * index

func _find_nearest_enemy(world: ECSWorld) -> int:
	var player_pos = world.player_position
	var closest_id = -1
	var closest_dist = INF

	for eid in world.enemies:
		if not world.transforms.has(eid):
			continue
		var enemy_pos = world.transforms[eid]["position"]
		var dist = player_pos.distance_squared_to(enemy_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_id = eid
	return closest_id
