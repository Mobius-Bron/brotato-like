class_name EnemyFactory
extends RefCounted

var _world: ECSWorld
var _map_size: Vector2

func _init(world: ECSWorld, map_size: Vector2) -> void:
	_world = world
	_map_size = map_size

func create_enemy(enemy_id: String, position: Vector2 = Vector2.ZERO) -> int:
	var cfg = ConfigLoader.get_enemy(enemy_id)
	if cfg.is_empty():
		return -1

	var eid = _world.create_entity()
	var pos = position
	if pos == Vector2.ZERO:
		pos = _random_edge_position()

	_world.transforms[eid] = {"position": pos}
	_world.healths[eid] = {"current_hp": cfg["hp"], "max_hp": cfg["hp"], "invincible_time": 0.1, "invincible_timer": 0.0}
	_world.movements[eid] = {"speed": cfg["speed"], "direction": Vector2.ZERO, "is_player": false}
	_world.collisions[eid] = {"radius": cfg["size"] * 0.5}
	_world.sprites[eid] = _make_enemy_sprite(cfg)
	_world.enemies[eid] = {
		"enemy_id": enemy_id,
		"damage": cfg["damage"],
		"xp_drop": cfg["xp_drop"],
		"coin_drop": cfg["coin_drop"],
		"is_boss": cfg.get("is_boss", false),
		"base_speed": cfg["speed"]
	}

	var weapon_id = cfg.get("weapon_id", "")
	if weapon_id != "":
		_world.weapons[eid] = WeaponFactory.create_weapon_component(weapon_id)

	return eid

func _random_edge_position() -> Vector2:
	var spawn_margin = MapConfig.SPAWN_MARGIN
	var wall = MapConfig.WALL_THICKNESS
	var min_x = wall + spawn_margin
	var max_x = _map_size.x - wall - spawn_margin
	var min_y = wall + spawn_margin
	var max_y = _map_size.y - wall - spawn_margin

	var side = randi() % 4
	match side:
		0: return Vector2(randf_range(min_x, max_x), min_y - 20.0)
		1: return Vector2(randf_range(min_x, max_x), max_y + 20.0)
		2: return Vector2(min_x - 20.0, randf_range(min_y, max_y))
		3: return Vector2(max_x + 20.0, randf_range(min_y, max_y))
	return Vector2.ZERO

func _hex_to_color(hex: String) -> Color:
	if hex.length() < 6:
		return Color.WHITE
	var r = hex.substr(0, 2).hex_to_int() / 255.0
	var g = hex.substr(2, 2).hex_to_int() / 255.0
	var b = hex.substr(4, 2).hex_to_int() / 255.0
	return Color(r, g, b, 1.0)

func _make_enemy_sprite(cfg: Dictionary) -> Dictionary:
	var shape: String = cfg["shape"]
	var color: Color = _hex_to_color(cfg["color"])
	var size: float = cfg["size"]
	var dark = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 1.0)
	var bright = Color(min(color.r * 1.4, 1.0), min(color.g * 1.4, 1.0), min(color.b * 1.4, 1.0), 1.0)
	var white = Color(1.0, 1.0, 1.0, 0.95)
	var black = Color(0.0, 0.0, 0.0, 0.9)

	match shape:
		"rect":
			return _sprite_combo(size * 0.55, [
				{"shape": "rect", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "rect", "offset": Vector2(-size * 0.18, -size * 0.18), "color": white, "size": size * 0.28},
				{"shape": "rect", "offset": Vector2(size * 0.18, -size * 0.18), "color": white, "size": size * 0.28},
				{"shape": "rect", "offset": Vector2(-size * 0.18, -size * 0.16), "color": black, "size": size * 0.12},
				{"shape": "rect", "offset": Vector2(size * 0.18, -size * 0.16), "color": black, "size": size * 0.12},
			])
		"triangle":
			return _sprite_combo(size * 0.5, [
				{"shape": "triangle", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "circle", "offset": Vector2.ZERO, "color": white, "size": size * 0.45},
				{"shape": "circle", "offset": Vector2.ZERO, "color": black, "size": size * 0.2},
			])
		"diamond":
			return _sprite_combo(size * 0.5, [
				{"shape": "diamond", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "rect", "offset": Vector2(-size * 0.15, -size * 0.08), "color": white, "size": size * 0.3},
				{"shape": "rect", "offset": Vector2(size * 0.15, -size * 0.08), "color": white, "size": size * 0.3},
				{"shape": "rect", "offset": Vector2(-size * 0.15, -size * 0.06), "color": black, "size": size * 0.12},
				{"shape": "rect", "offset": Vector2(size * 0.15, -size * 0.06), "color": black, "size": size * 0.12},
			])
		"hexagon":
			return _sprite_combo(size * 0.55, [
				{"shape": "hexagon", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "hexagon", "offset": Vector2.ZERO, "color": dark, "size": size * 0.75},
				{"shape": "circle", "offset": Vector2.ZERO, "color": white, "size": size * 0.5},
				{"shape": "circle", "offset": Vector2.ZERO, "color": black, "size": size * 0.22},
				{"shape": "triangle", "offset": Vector2(-size * 0.35, -size * 0.2), "color": bright, "size": size * 0.35, "rotation": -PI / 2.0},
				{"shape": "triangle", "offset": Vector2(size * 0.35, -size * 0.2), "color": bright, "size": size * 0.35, "rotation": PI / 2.0},
			])
		_:
			return _sprite_combo(size * 0.55, [
				{"shape": "circle", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "circle", "offset": Vector2(-size * 0.18, -size * 0.15), "color": white, "size": size * 0.3},
				{"shape": "circle", "offset": Vector2(size * 0.18, -size * 0.15), "color": white, "size": size * 0.3},
				{"shape": "circle", "offset": Vector2(-size * 0.18, -size * 0.13), "color": black, "size": size * 0.14},
				{"shape": "circle", "offset": Vector2(size * 0.18, -size * 0.13), "color": black, "size": size * 0.14},
			])

func _sprite_combo(outline_r: float, subs: Array) -> Dictionary:
	return {
		"shape": "composite",
		"color": Color.WHITE,
		"size": 1.0,
		"rotation": 0.0,
		"outline_radius": outline_r,
		"sub_sprites": subs
	}
