class_name LifetimeSystem
extends RefCounted

func update(world: ECSWorld, delta: float) -> void:
	var to_destroy := []

	for eid in world.lifetimes:
		var lt = world.lifetimes[eid]
		lt["remaining_time"] -= delta
		if lt["remaining_time"] <= 0:
			to_destroy.append(eid)

	for eid in to_destroy:
		world.destroy_entity(eid)
