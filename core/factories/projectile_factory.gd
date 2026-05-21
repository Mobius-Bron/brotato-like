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
	lifetime: float = 3.0,
	pierce: int = 0
) -> int:
	var eid = _world.create_entity()

	_world.transforms[eid] = {"position": position}
	_world.movements[eid] = {"speed": speed, "direction": direction.normalized(), "is_player": false}
	_world.collisions[eid] = {"radius": size * 0.5}
	var col = _hex_to_color(color_hex)
	var bright = Color(min(col.r * 1.5, 1.0), min(col.g * 1.5, 1.0), min(col.b * 1.5, 1.0), 1.0)
	_world.sprites[eid] = {
		"shape": "composite",
		"color": col,
		"size": size,
		"rotation": direction.angle(),
		"outline_radius": size * 0.55,
		"height": 0.7,
		"sub_sprites": [
			{"shape": "circle", "offset": Vector2.ZERO, "color": Color(0.0, 0.0, 0.0, 0.6), "size": size + 2.0},
			{"shape": "circle", "offset": Vector2.ZERO, "color": col, "size": size},
			{"shape": "circle", "offset": Vector2.ZERO, "color": bright, "size": size * 0.4},
		]
	}
	_world.lifetimes[eid] = {"remaining_time": lifetime}
	_world.projectiles[eid] = {"owner_id": owner_id, "damage": damage, "pierce": pierce}

	return eid

func _hex_to_color(hex: String) -> Color:
	if hex.length() < 6:
		return Color.WHITE
	var r = hex.substr(0, 2).hex_to_int() / 255.0
	var g = hex.substr(2, 2).hex_to_int() / 255.0
	var b = hex.substr(4, 2).hex_to_int() / 255.0
	return Color(r, g, b, 1.0)
