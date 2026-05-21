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
	if not owned_weapons.has(weapon_id):
		owned_weapons.append(weapon_id)

func set_state(new_state: State) -> void:
	current_state = new_state
