class_name HealthSystem
extends RefCounted

var _world: ECSWorld

func _init(world: ECSWorld) -> void:
	_world = world

func update(world: ECSWorld, delta: float) -> void:
	_update_invincible(world, delta)
	_process_dead(world)

func deal_damage(target_id: int, damage: int) -> void:
	if not _world.healths.has(target_id):
		return

	var hp = _world.healths[target_id]
	if hp["invincible_timer"] > 0:
		return

	var actual_damage = damage
	if _world.players.has(target_id):
		actual_damage = max(1, damage - GameManager.stat_bonuses.get("armor", 0))

	hp["current_hp"] -= actual_damage
	hp["invincible_timer"] = hp["invincible_time"]

	if _world.players.has(target_id):
		EventBus.emit("player_damaged", hp["current_hp"])

func _update_invincible(world: ECSWorld, delta: float) -> void:
	for eid in world.healths:
		var hp = world.healths[eid]
		if hp["invincible_timer"] > 0:
			hp["invincible_timer"] -= delta

func _process_dead(world: ECSWorld) -> void:
	var to_destroy := []
	for eid in world.healths:
		if world.healths[eid]["current_hp"] <= 0:
			to_destroy.append(eid)

	for eid in to_destroy:
		if world.enemies.has(eid):
			var data = world.enemies[eid]
			GameManager.add_coins(data["coin_drop"])
			GameManager.add_exp(data["xp_drop"])
			EventBus.emit("enemy_killed", {
				"enemy_id": data["enemy_id"],
				"is_boss": data.get("is_boss", false)
			})
		if world.players.has(eid):
			EventBus.emit("player_died")
		world.destroy_entity(eid)
