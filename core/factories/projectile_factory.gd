class_name ProjectileFactory
extends RefCounted

var _world: ECSWorld

func _init(world: ECSWorld) -> void:
	_world = world

func create_projectile(
	position: Vector2,
	direction: Vector2,
	damage: int,
	speed: float,
	size: float,
	shape: String,
	color_hex: String,
	owner_id: int,
	lifetime: float = 1.5,
	pierce: int = 0,
	explosion_radius: float = 0.0,
	explosion_damage: int = 0
) -> int:
	var eid = _world.create_entity()

	_world.transforms[eid] = {"position": position}
	_world.movements[eid] = {"speed": speed, "direction": direction.normalized(), "is_player": false}
	_world.collisions[eid] = {"radius": size * 0.5}
	var col = _hex_to_color(color_hex)
	_world.sprites[eid] = {
		"shape": "circle",
		"color": col,
		"size": size,
		"rotation": 0.0,
		"outline_radius": size * 0.55,
		"height": 0.7,
		"sub_sprites": []
	}
	_world.lifetimes[eid] = {"remaining_time": lifetime}
	_world.projectiles[eid] = {
		"owner_id": owner_id,
		"damage": damage,
		"pierce": pierce,
		"explosion_radius": explosion_radius,
		"explosion_damage": explosion_damage
	}

	return eid

func _hex_to_color(hex: String) -> Color:
	if hex.length() < 6:
		return Color.WHITE
	var r = hex.substr(0, 2).hex_to_int() / 255.0
	var g = hex.substr(2, 2).hex_to_int() / 255.0
	var b = hex.substr(4, 2).hex_to_int() / 255.0
	return Color(r, g, b, 1.0)
