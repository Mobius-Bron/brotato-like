class_name MapConfig
extends RefCounted

const MAP_SIZE: float = 2000.0
const MAP_MULTI_SIZE: float = 4000.0
const WALL_THICKNESS: float = 40.0
const SPAWN_MARGIN: float = 60.0

static func get_size(multiplayer: bool = false) -> Vector2:
	var s = MAP_MULTI_SIZE if multiplayer else MAP_SIZE
	return Vector2(s, s)

static func play_area_min() -> float:
	return WALL_THICKNESS + 20.0

static func play_area_max(multiplayer: bool = false) -> float:
	return get_size(multiplayer).x - WALL_THICKNESS - 20.0
