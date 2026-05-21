class_name ECSWorld
extends RefCounted

var _next_id := 0
var _alive_entities := {}
var _systems: Array = []

var transforms := {}
var healths := {}
var movements := {}
var weapons := {}
var collisions := {}
var sprites := {}
var lifetimes := {}

var players := {}
var enemies := {}
var projectiles := {}
var weapon_entities := {}

var player_position := Vector2.ZERO

func create_entity() -> int:
	var id = _next_id
	_next_id += 1
	_alive_entities[id] = true
	return id

func destroy_entity(id: int) -> void:
	_alive_entities.erase(id)
	transforms.erase(id)
	healths.erase(id)
	movements.erase(id)
	weapons.erase(id)
	collisions.erase(id)
	sprites.erase(id)
	lifetimes.erase(id)
	players.erase(id)
	enemies.erase(id)
	projectiles.erase(id)
	weapon_entities.erase(id)

func is_alive(id: int) -> bool:
	return _alive_entities.has(id)

func add_system(system) -> void:
	_systems.append(system)

func update(delta: float) -> void:
	for sys in _systems:
		sys.update(self, delta)

	if players.size() > 0:
		var pid = players.keys()[0]
		if transforms.has(pid):
			player_position = transforms[pid]["position"]
