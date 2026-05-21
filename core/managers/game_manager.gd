extends Node

enum State { MENU, CHAR_SELECT, PLAYING, PERK_SELECT, SHOP, WIN, LOSE }

var current_state: State = State.MENU
var coins: int = 0
var current_wave: int = 1
var player_level: int = 1
var player_exp: int = 0
var exp_to_next: int = 30
var kills: int = 0
var owned_items: Array = []
var owned_weapons: Array = ["pistol"]
var selected_character: String = ""
var perk_choices: Array = []
var pending_levels: int = 0

var stat_bonuses := {
	"max_hp": 0,
	"hp_regen": 0,
	"speed": 0,
	"damage": 0,
	"damage_percent": 0.0,
	"attack_speed": 0.0,
	"crit_chance": 0.0,
	"crit_damage": 0.0,
	"armor": 0,
	"dodge_chance": 0.0,
	"range": 0,
	"luck": 0,
	"xp_gain": 0.0,
	"coin_gain": 0.0,
	"pickup_radius": 0,
	"knockback": 0.0,
	"pierce": 0,
	"life_steal": 0.0,
	"explosion_chance": 0.0,
	"explosion_size": 0,
}

func reset() -> void:
	current_state = State.CHAR_SELECT
	coins = 0
	current_wave = 1
	player_level = 1
	player_exp = 0
	exp_to_next = 30
	owned_items = []
	owned_weapons = ["pistol"]
	kills = 0
	selected_character = ""
	pending_levels = 0
	stat_bonuses = {
		"max_hp": 0,
		"hp_regen": 0,
		"speed": 0,
		"damage": 0,
		"damage_percent": 0.0,
		"attack_speed": 0.0,
		"crit_chance": 0.0,
		"crit_damage": 0.0,
		"armor": 0,
		"dodge_chance": 0.0,
		"range": 0,
		"luck": 0,
		"xp_gain": 0.0,
		"coin_gain": 0.0,
		"pickup_radius": 0,
		"knockback": 0.0,
		"pierce": 0,
		"life_steal": 0.0,
		"explosion_chance": 0.0,
		"explosion_size": 0,
	}

func apply_character(character_id: String) -> void:
	selected_character = character_id
	var cfg = ConfigLoader.get_character(character_id)
	if cfg.is_empty():
		owned_weapons = ["pistol"]
		return
	owned_weapons = cfg.get("starting_weapons", ["pistol"])
	var mods = cfg.get("stat_modifiers", {})
	for key in mods:
		if stat_bonuses.has(key):
			stat_bonuses[key] = mods[key]

func start_game() -> void:
	current_state = State.PLAYING

func add_coins(amount: int) -> void:
	var bonus = amount * (1.0 + stat_bonuses.get("coin_gain", 0.0))
	coins += int(bonus)
	EventBus.emit("coins_changed", coins)

func add_exp(amount: int) -> void:
	var bonus = amount * (1.0 + stat_bonuses.get("xp_gain", 0.0))
	player_exp += int(bonus)
	while player_exp >= exp_to_next:
		player_exp -= exp_to_next
		player_level += 1
		pending_levels += 1
		exp_to_next = int(exp_to_next * 1.2)
	EventBus.emit("exp_changed", {"exp": player_exp, "level": player_level, "to_next": exp_to_next})

func apply_item(item_id: String) -> void:
	var item = ConfigLoader.get_item(item_id)
	if item.is_empty():
		return
	owned_items.append(item_id)
	var key = item.get("stat_key", "")
	if key == "heal":
		EventBus.emit("player_heal", item.get("stat_value", 0))
		return
	if stat_bonuses.has(key):
		var val = item.get("stat_value", 0)
		if typeof(stat_bonuses[key]) == TYPE_INT:
			stat_bonuses[key] += int(val)
		else:
			stat_bonuses[key] += val
	var key2 = item.get("stat_key2", "")
	if key2 != "" and stat_bonuses.has(key2):
		var val2 = item.get("stat_value2", 0)
		if typeof(stat_bonuses[key2]) == TYPE_INT:
			stat_bonuses[key2] += int(val2)
		else:
			stat_bonuses[key2] += val2

func apply_perk(perk_id: String) -> void:
	var perk = ConfigLoader.get_perk(perk_id)
	if perk.is_empty():
		return
	for mod in perk.get("modifiers", []):
		var key = mod.get("stat_key", "")
		var val = mod.get("stat_value", 0)
		if key == "heal":
			EventBus.emit("player_heal", int(val))
			continue
		if stat_bonuses.has(key):
			if typeof(stat_bonuses[key]) == TYPE_INT:
				stat_bonuses[key] += int(val)
			else:
				stat_bonuses[key] += val
	pending_levels -= 1

func add_weapon(weapon_id: String) -> void:
	if owned_weapons.size() >= 6:
		return
	owned_weapons.append(weapon_id)

func remove_weapon(weapon_id: String) -> void:
	var idx = owned_weapons.find(weapon_id)
	if idx != -1:
		owned_weapons.remove_at(idx)

func swap_weapons(idx_a: int, idx_b: int) -> void:
	if idx_a < 0 or idx_a >= owned_weapons.size():
		return
	if idx_b < 0 or idx_b >= owned_weapons.size():
		return
	var tmp = owned_weapons[idx_a]
	owned_weapons[idx_a] = owned_weapons[idx_b]
	owned_weapons[idx_b] = tmp

func sell_weapon(weapon_id: String) -> int:
	var idx = owned_weapons.find(weapon_id)
	if idx == -1:
		return 0
	var cfg = ConfigLoader.get_weapon(weapon_id)
	var refund = int(cfg.get("price", 0) * 0.5)
	owned_weapons.remove_at(idx)
	coins += refund
	EventBus.emit("coins_changed", coins)
	return refund

func get_weapon_tier_upgrade(weapon_id: String) -> String:
	var cfg = ConfigLoader.get_weapon(weapon_id)
	if cfg.is_empty():
		return ""
	var tier = cfg.get("tier", 1)
	var base_id = _get_base_id(weapon_id)
	if base_id == "":
		return ""
	var next_id = base_id + "_t" + str(tier + 1)
	var next_cfg = ConfigLoader.get_weapon(next_id)
	if next_cfg.is_empty():
		return ""
	return next_id

func try_merge_weapons(weapon_id: String) -> String:
	var count = 0
	for w in owned_weapons:
		if w == weapon_id:
			count += 1
	if count < 2:
		return ""

	var upgrade = get_weapon_tier_upgrade(weapon_id)
	if upgrade == "":
		return ""

	remove_weapon(weapon_id)
	remove_weapon(weapon_id)
	add_weapon(upgrade)
	return upgrade

func _get_base_id(weapon_id: String) -> String:
	var rgx = RegEx.new()
	rgx.compile("_t\\d+$")
	var result = rgx.search(weapon_id)
	if result:
		return weapon_id.substr(0, result.get_start())
	return weapon_id

func set_state(new_state: State) -> void:
	current_state = new_state
