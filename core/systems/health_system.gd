class_name HealthSystem
extends RefCounted

var _world: ECSWorld

func _init(world: ECSWorld) -> void:
	_world = world

func update(world: ECSWorld, delta: float) -> void:
	_update_invincible(world, delta)
	_update_regen(world, delta)
	_process_dead(world)

func deal_damage(target_id: int, damage: int) -> void:
	if not _world.healths.has(target_id):
		return

	var hp = _world.healths[target_id]
	if hp["invincible_timer"] > 0:
		return

	if _world.players.has(target_id):
		var dodge_chance = GameManager.stat_bonuses.get("dodge_chance", 0.0)
		if dodge_chance > 0 and randf() < dodge_chance:
			return

	var actual_damage = damage
	if _world.players.has(target_id):
		actual_damage = max(1, damage - GameManager.stat_bonuses.get("armor", 0))

	hp["current_hp"] -= actual_damage
	hp["invincible_timer"] = hp["invincible_time"]

	if _world.players.has(target_id):
		EventBus.emit("player_damaged", hp["current_hp"])

func _update_regen(world: ECSWorld, delta: float) -> void:
	for pid in world.players:
		if not world.healths.has(pid):
			continue
		var hp = world.healths[pid]
		var regen = GameManager.stat_bonuses.get("hp_regen", 0)
		if regen > 0:
			var accum = hp.get("regen_accum", 0.0) + regen * delta
			var heal_ticks = int(accum)
			if heal_ticks > 0:
				hp["current_hp"] = min(hp["current_hp"] + heal_ticks, hp["max_hp"])
				hp["regen_accum"] = accum - heal_ticks
			else:
				hp["regen_accum"] = accum

func _update_invincible(world: ECSWorld, delta: float) -> void:
	for eid in world.healths:
		var hp = world.healths[eid]
		if hp["invincible_timer"] > 0:
			hp["invincible_timer"] -= delta

func apply_lifesteal(owner_id: int, damage: int, world: ECSWorld) -> void:
	var ls = GameManager.stat_bonuses.get("life_steal", 0.0)
	if ls <= 0.0:
		return
	if not world.healths.has(owner_id):
		return
	var hp = world.healths[owner_id]
	var accum = hp.get("lifesteal_accum", 0.0) + damage * ls
	var heal_ticks = int(accum)
	if heal_ticks > 0:
		hp["current_hp"] = min(hp["current_hp"] + heal_ticks, hp["max_hp"])
		hp["lifesteal_accum"] = accum - heal_ticks
	else:
		hp["lifesteal_accum"] = accum

func _process_dead(world: ECSWorld) -> void:
	var to_destroy := []
	for eid in world.healths:
		if world.healths[eid]["current_hp"] <= 0:
			to_destroy.append(eid)

	for eid in to_destroy:
		if world.enemies.has(eid):
			var data = world.enemies[eid]
			GameManager.add_coins(data["coin_drop"])
			var death_pos = world.transforms.get(eid, {}).get("position", world.player_position)
			EventBus.emit("enemy_killed", {
				"enemy_id": data["enemy_id"],
				"is_boss": data.get("is_boss", false),
				"pos": death_pos,
				"xp_drop": data["xp_drop"]
			})
		if world.players.has(eid):
			EventBus.emit("player_died")
		world.destroy_entity(eid)
