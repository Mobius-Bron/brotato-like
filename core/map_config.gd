class_name MapConfig
extends RefCounted

const MAP_SIZE: float = 3000.0
const WALL_THICKNESS: float = 50.0
const SPAWN_MARGIN: float = 80.0

static func get_size() -> Vector2:
	return Vector2(MAP_SIZE, MAP_SIZE)

static func play_area_min() -> float:
	return WALL_THICKNESS + 20.0

static func play_area_max() -> float:
	return MAP_SIZE - WALL_THICKNESS - 20.0
