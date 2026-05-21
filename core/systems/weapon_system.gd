class_name WeaponSystem
extends RefCounted

var _projectile_factory: ProjectileFactory
var _health_system: HealthSystem

func _init(projectile_factory: ProjectileFactory, health_system: HealthSystem) -> void:
	_projectile_factory = projectile_factory
	_health_system = health_system

func update(world: ECSWorld, delta: float) -> void:
	_process_entity_weapons(world, delta)
	_process_enemy_weapons(world, delta)

func _process_entity_weapons(world: ECSWorld, delta: float) -> void:
	for weid in world.weapon_entities:
		if not world.is_alive(weid) or not world.weapons.has(weid):
			continue
		var weapon = world.weapons[weid]
		weapon["cooldown_remaining"] -= delta

		if weapon["cooldown_remaining"] <= 0:
			weapon["cooldown_remaining"] = weapon["base_cooldown"]
			var target_id = _find_nearest_enemy(world, weid, weapon)
			if target_id == -1:
				continue
			if weapon.get("melee", false):
				_melee_strike(world, weid, weapon, target_id)
			else:
				_shoot(world, weid, weapon, target_id, world.weapon_entities[weid].get("owner_id", weid))

func _process_enemy_weapons(world: ECSWorld, delta: float) -> void:
	for eid in world.enemies:
		if not world.weapons.has(eid):
			continue
		var weapon = world.weapons[eid]
		if weapon.get("melee", false):
			continue
		weapon["cooldown_remaining"] -= delta

		if weapon["cooldown_remaining"] <= 0:
			weapon["cooldown_remaining"] = weapon["base_cooldown"]
			for pid in world.players:
				if world.transforms.has(pid):
					_shoot(world, eid, weapon, pid, eid)
					break

func _find_nearest_enemy(world: ECSWorld, weid: int, weapon: Dictionary) -> int:
	var weapon_pos: Vector2 = world.transforms[weid]["position"]
	var range_sq = weapon["range"] * weapon["range"]
	var closest_id = -1
	var closest_dist = range_sq

	for eid in world.enemies:
		if not world.transforms.has(eid):
			continue
		var dist_sq = weapon_pos.distance_squared_to(world.transforms[eid]["position"])
		if dist_sq < closest_dist:
			closest_dist = dist_sq
			closest_id = eid
	return closest_id

func _melee_strike(world: ECSWorld, source_id: int, weapon: Dictionary, target_id: int) -> void:
	if not world.transforms.has(source_id) or not world.transforms.has(target_id):
		return

	var src_pos = world.transforms[source_id]["position"]
	var target_pos = world.transforms[target_id]["position"]
	var dist_sq = src_pos.distance_squared_to(target_pos)
	var range_sq = weapon["range"] * weapon["range"]

	if dist_sq > range_sq:
		return

	var bonus_damage = GameManager.stat_bonuses.get("damage", 0)
	var damage = weapon["damage"] + bonus_damage
	_health_system.deal_damage(target_id, damage)

	EventBus.emit("grass_effect", {
		"pos": target_pos,
		"radius": weapon["range"] * 0.8,
		"duration": 0.3
	})

func _shoot(world: ECSWorld, source_id: int, weapon: Dictionary, target_id: int, owner_id: int) -> void:
	if not world.transforms.has(source_id) or not world.transforms.has(target_id):
		return

	var src_pos = world.transforms[source_id]["position"]
	var target_pos = world.transforms[target_id]["position"]
	var base_dir = (target_pos - src_pos).normalized()
	var count = weapon["bullet_count"]
	var spread_deg = weapon["spread"]
	var half_spread = deg_to_rad(spread_deg) * (count - 1) / 2.0

	for i in range(count):
		var angle_offset = 0.0
		if count > 1:
			angle_offset = -half_spread + deg_to_rad(spread_deg) * i
		var dir = base_dir.rotated(angle_offset)

		var bonus_damage = 0
		if world.players.has(owner_id):
			bonus_damage = GameManager.stat_bonuses.get("damage", 0)

		_projectile_factory.create_projectile(
			src_pos,
			dir,
			weapon["damage"] + bonus_damage,
			weapon["bullet_speed"],
			weapon["bullet_size"],
			weapon["bullet_shape"],
			weapon["bullet_color"],
			owner_id,
			3.0
		)
