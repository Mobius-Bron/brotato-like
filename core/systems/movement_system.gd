class_name MovementSystem
extends RefCounted

var _map_size: Vector2
var _margin: float

func _init(map_size: Vector2) -> void:
	_map_size = map_size
	_margin = MapConfig.play_area_min()

func update(world: ECSWorld, delta: float) -> void:
	_handle_player(world)
	_handle_enemies(world, delta)
	_apply_avoidance(world)
	_move_all(world, delta)

func _handle_player(world: ECSWorld) -> void:
	for pid in world.players:
		if not world.movements.has(pid):
			continue
		var mov = world.movements[pid]
		var input_dir = Vector2.ZERO
		input_dir.x = Input.get_axis("ui_left", "ui_right")
		input_dir.y = Input.get_axis("ui_up", "ui_down")
		if input_dir == Vector2.ZERO:
			input_dir.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
			input_dir.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		mov["direction"] = input_dir.normalized() if input_dir.length() > 0 else Vector2.ZERO

func _handle_enemies(world: ECSWorld, delta: float) -> void:
	for eid in world.enemies:
		if not world.transforms.has(eid) or not world.movements.has(eid):
			continue
		var mov = world.movements[eid]
		var trans = world.transforms[eid]
		var enemy_pos = trans["position"]
		var player_pos = world.player_position

		var dir = (player_pos - enemy_pos).normalized()
		mov["direction"] = dir

		var enemy_data = world.enemies[eid]
		var base_speed = enemy_data.get("base_speed", mov["speed"])
		mov["speed"] = base_speed

		var dist = enemy_pos.distance_to(player_pos)
		if enemy_data.get("is_boss", false) and dist < 80:
			mov["speed"] = base_speed * 0.3
		elif world.weapons.has(eid) and dist < 250:
			mov["speed"] = base_speed * 0.3

func _apply_avoidance(world: ECSWorld) -> void:
	var enemy_list: Array = []
	for eid in world.enemies:
		if world.transforms.has(eid) and world.collisions.has(eid):
			enemy_list.append(eid)

	for i in range(enemy_list.size()):
		for j in range(i + 1, enemy_list.size()):
			var a = enemy_list[i]
			var b = enemy_list[j]
			var pa: Vector2 = world.transforms[a]["position"]
			var pb: Vector2 = world.transforms[b]["position"]
			var dist = pa.distance_to(pb)
			var min_dist = 24.0
			if dist < min_dist and dist > 0.001:
				var push = (pa - pb).normalized() * (min_dist - dist) * 0.5
				world.transforms[a]["position"] = pa + push
				world.transforms[b]["position"] = pb - push

func _move_all(world: ECSWorld, delta: float) -> void:
	var to_destroy := []
	var all_with_movement = world.movements.keys()

	for eid in all_with_movement:
		if not world.transforms.has(eid):
			continue
		var mov = world.movements[eid]
		var trans = world.transforms[eid]
		var pos: Vector2 = trans["position"]
		pos += mov["direction"] * mov["speed"] * delta

		var is_projectile = world.projectiles.has(eid)
		if is_projectile and _is_out_of_bounds(pos):
			to_destroy.append(eid)
			continue

		pos.x = clamp(pos.x, _margin, _map_size.x - _margin)
		pos.y = clamp(pos.y, _margin, _map_size.y - _margin)
		trans["position"] = pos

	for eid in to_destroy:
		world.destroy_entity(eid)

func _is_out_of_bounds(pos: Vector2) -> bool:
	return pos.x < _margin or pos.x > _map_size.x - _margin or pos.y < _margin or pos.y > _map_size.y - _margin
