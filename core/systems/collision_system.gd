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

	for pid in world.projectiles:
		if not world.transforms.has(pid) or not world.collisions.has(pid):
			continue

		var owner_id = world.projectiles[pid]["owner_id"]
		var is_player_bullet = world.players.has(owner_id)
		var targets = world.enemies if is_player_bullet else world.players

		for tid in targets:
			if not world.transforms.has(tid) or not world.collisions.has(tid):
				continue

			var bullet_pos = world.transforms[pid]["position"]
			var target_pos = world.transforms[tid]["position"]
			var dist = bullet_pos.distance_to(target_pos)
			var combined_radius = world.collisions[pid]["radius"] + world.collisions[tid]["radius"]

			if dist < combined_radius:
				var damage = world.projectiles[pid]["damage"]
				_health_system.deal_damage(tid, damage)

				var pierce = world.projectiles[pid].get("pierce", 0)
				if pierce > 0:
					world.projectiles[pid]["pierce"] = pierce - 1
				else:
					destroyed_projectiles.append(pid)
				break

	for pid in destroyed_projectiles:
		world.destroy_entity(pid)

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
