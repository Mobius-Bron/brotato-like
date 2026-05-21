class_name WeaponFactory
extends RefCounted

static func create_weapon_component(weapon_id: String) -> Dictionary:
	var cfg = ConfigLoader.get_weapon(weapon_id)
	if cfg.is_empty():
		return {}
	return {
		"weapon_id": weapon_id,
		"cooldown_remaining": 0.0,
		"base_cooldown": cfg["cooldown"],
		"damage": cfg["damage"],
		"range": cfg["range"],
		"bullet_speed": cfg["bullet_speed"],
		"bullet_size": cfg["bullet_size"],
		"bullet_count": cfg["bullet_count"],
		"spread": cfg["spread"],
		"targeting": cfg["targeting"],
		"bullet_shape": cfg["bullet_shape"],
		"bullet_color": cfg["bullet_color"],
		"melee": cfg.get("melee", false)
	}

static func apply_stat_bonuses(weapon_data: Dictionary, bonuses: Dictionary) -> Dictionary:
	var modified = weapon_data.duplicate()
	modified["damage"] = int(modified["damage"] + bonuses.get("damage", 0))
	modified["range"] = int(modified["range"] + bonuses.get("range", 0))
	modified["base_cooldown"] = modified["base_cooldown"] * bonuses.get("cooldown_mult", 1.0)
	return modified
