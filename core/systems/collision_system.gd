class_name CollisionSystem
extends RefCounted

var _health_system: HealthSystem

func _init(health_system: HealthSystem) -> void:
	_health_system = health_system

func update(world: ECSWorld, delta: float) -> void:
	_check_projectile_hit(world)
	_check_melee_collision(world)

func _check_projectile_hit(world: ECSWorld) -> void:
	var destroyed_projectiles := []
	var checked_count := 0
	var max_checks := 300

	for pid in world.projectiles:
		if checked_count >= max_checks:
			break
		if not world.transforms.has(pid) or not world.collisions.has(pid):
			continue

		var proj_data = world.projectiles[pid]
		var owner_id = proj_data["owner_id"]
		var is_player_bullet = world.players.has(owner_id)
		var targets = world.enemies if is_player_bullet else world.players

		var bullet_pos = world.transforms[pid]["position"]
		var bullet_radius = world.collisions[pid]["radius"]

		for tid in targets:
			if not world.transforms.has(tid) or not world.collisions.has(tid):
				continue

			var target_pos = world.transforms[tid]["position"]
			var dist_sq = bullet_pos.distance_squared_to(target_pos)
			var combined_radius = bullet_radius + world.collisions[tid]["radius"]

			if dist_sq < combined_radius * combined_radius:
				var damage = proj_data["damage"]
				_health_system.deal_damage(tid, damage)
				if is_player_bullet:
					_health_system.apply_lifesteal(owner_id, damage, world)

				var explosion_r = proj_data.get("explosion_radius", 0.0)
				if explosion_r > 0.0:
					var effective_radius = explosion_r * 50.0
					var aoe_dmg = proj_data.get("explosion_damage", 0)
					if aoe_dmg <= 0:
						aoe_dmg = int(damage * 0.5)
					_deal_aoe_damage(world, target_pos, effective_radius, aoe_dmg, targets)
					_spawn_explosion_anim(world, target_pos, effective_radius, 0.15, Color(1.0, 0.5, 0.0, 0.9))

				var pierce = proj_data.get("pierce", 0)
				if pierce > 0:
					world.projectiles[pid]["pierce"] = pierce - 1
				else:
					destroyed_projectiles.append(pid)
				break

		checked_count += 1

	for pid in destroyed_projectiles:
		world.destroy_entity(pid)

func _deal_aoe_damage(world: ECSWorld, center: Vector2, radius: float, damage: int, targets) -> void:
	var radius_sq = radius * radius
	for tid in targets:
		if not world.transforms.has(tid):
			continue
		var dist_sq = center.distance_squared_to(world.transforms[tid]["position"])
		if dist_sq < radius_sq:
			_health_system.deal_damage(tid, damage)

func _spawn_explosion_anim(world: ECSWorld, pos: Vector2, radius: float, duration: float, color: Color) -> void:
	var frames := 8
	for i in range(frames):
		var t = i / float(frames - 1)
		var eid = world.create_entity()
		world.transforms[eid] = {"position": pos}
		world.sprites[eid] = {
			"shape": "circle",
			"color": Color(color.r, color.g, color.b, color.a * (1.0 - t)),
			"size": radius * (0.3 + t * 1.4),
			"rotation": 0.0,
			"height": 0.8
		}
		world.lifetimes[eid] = {"remaining_time": t * duration}
	for i in range(6):
		var eid = world.create_entity()
		var angle = i * TAU / 6.0 + randf() * 0.5
		var dist = radius * 0.2
		world.transforms[eid] = {"position": pos + Vector2(cos(angle) * dist, sin(angle) * dist)}
		world.sprites[eid] = {
			"shape": "circle",
			"color": Color(1.0, 0.8, 0.2, 0.8),
			"size": radius * (0.15 + randf() * 0.25),
			"rotation": 0.0,
			"height": 0.85
		}
		world.lifetimes[eid] = {"remaining_time": duration * (0.3 + randf() * 0.5)}

func _check_melee_collision(world: ECSWorld) -> void:
	for eid in world.enemies:
		if not world.transforms.has(eid) or not world.collisions.has(eid):
			continue
		var enemy_data = world.enemies[eid]
		if enemy_data.get("weapon_id", "") != "":
			continue

		for pid in world.players:
			if not world.transforms.has(pid) or not world.collisions.has(pid):
				continue

			var enemy_pos = world.transforms[eid]["position"]
			var player_pos = world.transforms[pid]["position"]
			var dist = enemy_pos.distance_to(player_pos)
			var combined_radius = world.collisions[eid]["radius"] + world.collisions[pid]["radius"]

			if dist < combined_radius:
				_health_system.deal_damage(pid, enemy_data["damage"])
