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
		"melee": cfg.get("melee", false),
		"melee_type": cfg.get("melee_type", "slash"),
		"ecosystem": cfg.get("ecosystem", ""),
		"element": cfg.get("element", ""),
		"explosion": cfg.get("explosion", 0),
		"explosion_damage": cfg.get("explosion_damage", 0),
	}

static func apply_stat_bonuses(weapon_data: Dictionary, bonuses: Dictionary) -> Dictionary:
	var modified = weapon_data.duplicate()
	var flat_dmg = bonuses.get("damage", 0)
	var pct_dmg = bonuses.get("damage_percent", 0.0)
	modified["damage"] = int(modified["damage"] * (1.0 + pct_dmg)) + flat_dmg
	modified["range"] = int(modified["range"] + bonuses.get("range", 0))
	var atk_spd = maxf(bonuses.get("attack_speed", 0.0), -0.75)
	modified["base_cooldown"] = modified["base_cooldown"] / (1.0 + atk_spd)
	return modified
