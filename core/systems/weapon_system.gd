class_name WeaponSystem
extends RefCounted

var _projectile_factory: ProjectileFactory
var _health_system: HealthSystem
var _boss_phases: Dictionary = {}

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
			var is_boss = world.enemies[eid].get("is_boss", false)
			if is_boss:
				_boss_shoot(world, eid, weapon)
			else:
				for pid in world.players:
					if world.transforms.has(pid):
						_shoot(world, eid, weapon, pid, eid)
						break

func _boss_shoot(world: ECSWorld, boss_id: int, weapon: Dictionary) -> void:
	var src_pos = world.transforms[boss_id]["position"]
	var player_pos = world.player_position
	var base_dir = (player_pos - src_pos).normalized()

	var phase = _boss_phases.get(boss_id, 0)
	_boss_phases[boss_id] = (phase + 1) % 4

	var count = weapon["bullet_count"]
	var spread = weapon["spread"]

	match phase:
		0:
			_radial_burst(world, boss_id, weapon, src_pos, count + 5)
		1:
			_aimed_spread(world, boss_id, weapon, src_pos, base_dir, count + 3, spread + 10)
		2:
			var dirs := [
				base_dir, base_dir.rotated(PI * 0.12), base_dir.rotated(-PI * 0.12),
				base_dir.rotated(PI * 0.25), base_dir.rotated(-PI * 0.25),
			]
			for i in range(min(dirs.size(), count + 4)):
				_shoot_at(world, boss_id, weapon, src_pos, dirs[i])
		3:
			var half_count = ceili((count + 6) / 2.0)
			for i in range(half_count):
				var a = TAU * i / half_count
				_shoot_at(world, boss_id, weapon, src_pos, Vector2(cos(a), sin(a)))
			for i in range(half_count):
				var a = TAU * i / half_count + PI / half_count
				_shoot_at(world, boss_id, weapon, src_pos, Vector2(cos(a), sin(a)))

func _radial_burst(world: ECSWorld, owner_id: int, weapon: Dictionary, pos: Vector2, count: int) -> void:
	for i in range(4):
		var a = TAU * i / 4.0 + randf() * 0.3
		var dir = Vector2(cos(a), sin(a))
		_shoot_at(world, owner_id, weapon, pos, dir)

func _aimed_spread(world: ECSWorld, owner_id: int, weapon: Dictionary, pos: Vector2, base_dir: Vector2, count: int, deg: float) -> void:
	var half = deg_to_rad(deg) * (count - 1) / 2.0
	for i in range(count):
		var offset = -half + deg_to_rad(deg) * i
		_shoot_at(world, owner_id, weapon, pos, base_dir.rotated(offset))

func _shoot_at(world: ECSWorld, owner_id: int, weapon: Dictionary, pos: Vector2, dir: Vector2) -> void:
	if world.projectiles.size() >= 120:
		return
	var damage = weapon["damage"]
	_projectile_factory.create_projectile(
		pos, dir, damage, weapon["bullet_speed"],
		weapon["bullet_size"], weapon["bullet_shape"], weapon["bullet_color"],
		owner_id, 3.0, 0, weapon.get("explosion", 0), weapon.get("explosion_damage", 0)
	)

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

	var damage = _apply_crit(weapon["damage"])
	_health_system.deal_damage(target_id, damage)
	_apply_lifesteal(world, source_id, damage)

	var aim_dir = (target_pos - src_pos).angle()
	var melee_type = weapon.get("melee_type", "slash")
	var slash_color = _hex_to_color(weapon.get("bullet_color", "CFD8DC"))

	match melee_type:
		"thrust":
			_spawn_thrust_anim(world, src_pos, aim_dir, weapon)
		"blunt":
			_spawn_blunt_anim(world, src_pos, aim_dir, weapon)
		_:
			_spawn_slash_anim(world, src_pos, aim_dir, weapon)

func _spawn_slash_anim(world: ECSWorld, pos: Vector2, angle: float, weapon: Dictionary) -> void:
	var color = _hex_to_color(weapon.get("bullet_color", "CFD8DC"))
	var size = weapon["range"] * 1.5

	for i in range(5):
		var t = i / 4.0
		var frame_angle = angle - 0.5 + t * 1.0
		var frame_pos = pos + Vector2(cos(frame_angle) * size * 0.3, sin(frame_angle) * size * 0.3)
		var eid = world.create_entity()
		world.transforms[eid] = {"position": frame_pos}
		world.sprites[eid] = {
			"shape": "arc",
			"color": color,
			"size": size,
			"rotation": frame_angle,
			"height": 0.7
		}
		world.lifetimes[eid] = {"remaining_time": 0.03 + t * 0.04}

func _spawn_thrust_anim(world: ECSWorld, pos: Vector2, angle: float, weapon: Dictionary) -> void:
	var color = _hex_to_color(weapon.get("bullet_color", "26A69A"))
	var size = weapon["range"]

	for i in range(4):
		var t = i / 3.0
		var extend = size * (0.3 + t * 0.7)
		var eid = world.create_entity()
		var mid_pos = pos + Vector2(cos(angle) * extend * 0.5, sin(angle) * extend * 0.5)
		world.transforms[eid] = {"position": mid_pos}
		world.sprites[eid] = {
			"shape": "rect",
			"color": color,
			"size": 10.0,
			"rotation": angle,
			"height": 0.7,
			"sub_sprites": [
				{"shape": "triangle", "offset": Vector2(cos(angle) * extend * 0.5, sin(angle) * extend * 0.5), "color": Color(1, 1, 1, 0.8), "size": extend * 0.35, "rotation": angle},
				{"shape": "rect", "offset": Vector2.ZERO, "color": color, "size": extend, "rotation": angle}
			]
		}
		world.lifetimes[eid] = {"remaining_time": 0.03 + t * 0.03}

func _spawn_blunt_anim(world: ECSWorld, pos: Vector2, angle: float, weapon: Dictionary) -> void:
	var color = _hex_to_color(weapon.get("bullet_color", "FFA000"))
	var size = weapon["range"] * 1.2

	for i in range(4):
		var t = i / 3.0
		var swing = angle - 0.4 + t * 0.8
		var eid = world.create_entity()
		var offset = Vector2(cos(swing) * size * 0.35, sin(swing) * size * 0.35)
		world.transforms[eid] = {"position": pos + offset}
		world.sprites[eid] = {
			"shape": "circle",
			"color": color,
			"size": size,
			"rotation": swing,
			"height": 0.7,
			"sub_sprites": [
				{"shape": "circle", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "hexagon", "offset": Vector2.ZERO, "color": Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.9), "size": size * 0.6}
			]
		}
		world.lifetimes[eid] = {"remaining_time": 0.035 + t * 0.035}

func _apply_crit(damage: int) -> int:
	var crit_chance = GameManager.stat_bonuses.get("crit_chance", 0.0)
	crit_chance += GameManager.stat_bonuses.get("luck", 0) * 0.005
	var crit_dmg = GameManager.stat_bonuses.get("crit_damage", 0.0)
	if crit_chance > 0 and randf() < crit_chance:
		return int(damage * (1.5 + crit_dmg))
	return damage

func _apply_lifesteal(world: ECSWorld, source_id: int, damage: int) -> void:
	var wedata = world.weapon_entities.get(source_id, {})
	if wedata.is_empty():
		return
	var owner_id = wedata.get("owner_id", -1)
	if owner_id == -1:
		return
	_health_system.apply_lifesteal(owner_id, damage, world)

func _shoot(world: ECSWorld, source_id: int, weapon: Dictionary, target_id: int, owner_id: int) -> void:
	if not world.transforms.has(source_id) or not world.transforms.has(target_id):
		return

	if world.projectiles.size() >= 120:
		return

	var src_pos = world.transforms[source_id]["position"]
	var target_pos = world.transforms[target_id]["position"]
	var base_dir = (target_pos - src_pos).normalized()
	var count = weapon["bullet_count"]
	var spread_deg = weapon["spread"]
	var half_spread = deg_to_rad(spread_deg) * (count - 1) / 2.0

	for i in range(count):
		if world.projectiles.size() >= 120:
			break
		var angle_offset = 0.0
		if count > 1:
			angle_offset = -half_spread + deg_to_rad(spread_deg) * i
		var dir = base_dir.rotated(angle_offset)

		var bullet_dmg = _apply_crit(weapon["damage"])

		var pierce = 0
		if world.players.has(owner_id):
			pierce = GameManager.stat_bonuses.get("pierce", 0)

		_projectile_factory.create_projectile(
			src_pos,
			dir,
			bullet_dmg,
			weapon["bullet_speed"],
			weapon["bullet_size"],
			weapon["bullet_shape"],
			weapon["bullet_color"],
			owner_id,
			1.5,
			pierce,
			weapon.get("explosion", 0),
			weapon.get("explosion_damage", 0)
		)

func _hex_to_color(hex: String) -> Color:
	if hex.length() < 6:
		return Color.WHITE
	var r = hex.substr(0, 2).hex_to_int() / 255.0
	var g = hex.substr(2, 2).hex_to_int() / 255.0
	var b = hex.substr(4, 2).hex_to_int() / 255.0
	return Color(r, g, b, 1.0)
