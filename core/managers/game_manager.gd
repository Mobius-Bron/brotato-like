extends Node

enum State { MENU, PLAYING, SHOP, WIN, LOSE }

var current_state: State = State.MENU
var coins: int = 0
var current_wave: int = 1
var player_level: int = 1
var player_exp: int = 0
var exp_to_next: int = 30
var owned_items: Array = []
var owned_weapons: Array = ["pistol"]

var stat_bonuses := {
	"max_hp": 0,
	"speed": 0,
	"damage": 0,
	"armor": 0,
	"cooldown_mult": 1.0,
	"range": 0
}

func reset() -> void:
	current_state = State.PLAYING
	coins = 0
	current_wave = 1
	player_level = 1
	player_exp = 0
	exp_to_next = 30
	owned_items = []
	owned_weapons = ["pistol"]
	stat_bonuses = {
		"max_hp": 0,
		"speed": 0,
		"damage": 0,
		"armor": 0,
		"cooldown_mult": 1.0,
		"range": 0
	}

func add_coins(amount: int) -> void:
	coins += amount
	EventBus.emit("coins_changed", coins)

func add_exp(amount: int) -> void:
	player_exp += amount
	while player_exp >= exp_to_next:
		player_exp -= exp_to_next
		player_level += 1
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
		stat_bonuses[key] += item.get("stat_value", 0)

func add_weapon(weapon_id: String) -> void:
	if owned_weapons.size() >= 6:
		return
	owned_weapons.append(weapon_id)

func remove_weapon(weapon_id: String) -> void:
	var idx = owned_weapons.find(weapon_id)
	if idx != -1:
		owned_weapons.remove_at(idx)

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
