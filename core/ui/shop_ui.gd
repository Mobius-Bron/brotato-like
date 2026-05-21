extends CanvasLayer

var _shop_items: Array = []
var _shop_weapons: Array = []
@onready var _inventory_container: VBoxContainer = $ShopPanel/VBoxContainer/InventoryContainer
@onready var _item_container: VBoxContainer = $ShopPanel/VBoxContainer/ItemContainer
@onready var _weapon_container: VBoxContainer = $ShopPanel/VBoxContainer/WeaponContainer
@onready var _coin_label: Label = $ShopPanel/VBoxContainer/ButtonRow/CoinLabel

func _ready() -> void:
	hide()
	EventBus.on("show_shop", _on_show_shop)

func _on_show_shop(_data = null) -> void:
	await get_tree().create_timer(0.5).timeout
	generate_shop()
	show()

func generate_shop() -> void:
	_shop_items.clear()
	_shop_weapons.clear()

	var all_items = ConfigLoader.items.duplicate()
	all_items.shuffle()
	for i in range(min(4, all_items.size())):
		_shop_items.append(all_items[i])

	var all_weapons = ConfigLoader.weapons.duplicate()
	all_weapons = all_weapons.filter(func(w):
		return w.get("price", 0) > 0 and w.get("tier", 1) == 1
	)
	all_weapons.shuffle()
	for i in range(min(3, all_weapons.size())):
		_shop_weapons.append(all_weapons[i])

	_coin_label.text = "金币: %d" % GameManager.coins
	_update_display()

func refresh_shop() -> void:
	if GameManager.coins < 5:
		return
	GameManager.coins -= 5
	EventBus.emit("coins_changed", GameManager.coins)
	generate_shop()

func _update_display() -> void:
	for child in _inventory_container.get_children():
		child.queue_free()
	for child in _item_container.get_children():
		child.queue_free()
	for child in _weapon_container.get_children():
		child.queue_free()

	_update_inventory()
	_update_shop_items()
	_update_shop_weapons()

func _update_inventory() -> void:
	var weapons = GameManager.owned_weapons.duplicate()
	if weapons.size() == 0:
		var label = Label.new()
		label.text = "  (空)"
		_inventory_container.add_child(label)
		return

	var counted = {}
	for w in weapons:
		counted[w] = counted.get(w, 0) + 1

	for weapon_id in counted:
		var cfg = ConfigLoader.get_weapon(weapon_id)
		if cfg.is_empty():
			continue
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 36)

		var name_lbl = Label.new()
		name_lbl.text = "%s x%d" % [cfg["name"], counted[weapon_id]]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)

		var sell_btn = Button.new()
		sell_btn.text = "卖%dG" % int(cfg.get("price", 0) * 0.5)
		sell_btn.custom_minimum_size = Vector2(60, 30)
		sell_btn.pressed.connect(_on_sell_weapon.bind(weapon_id))
		hbox.add_child(sell_btn)

		if counted[weapon_id] >= 2:
			var upgrade_id = GameManager.get_weapon_tier_upgrade(weapon_id)
			if upgrade_id != "":
				var merge_btn = Button.new()
				var up_cfg = ConfigLoader.get_weapon(upgrade_id)
				merge_btn.text = "合成%s" % up_cfg.get("name", "?")
				merge_btn.custom_minimum_size = Vector2(80, 30)
				merge_btn.pressed.connect(_on_merge_weapons.bind(weapon_id))
				hbox.add_child(merge_btn)

		_inventory_container.add_child(hbox)

func _update_shop_items() -> void:
	for i in range(_shop_items.size()):
		var item = _shop_items[i]
		var btn = Button.new()
		btn.text = "%s (%dG)" % [item["name"], item["price"]]
		btn.custom_minimum_size = Vector2(200, 44)
		btn.disabled = GameManager.coins < item["price"]
		btn.pressed.connect(_on_buy_item.bind(i))
		_item_container.add_child(btn)

func _update_shop_weapons() -> void:
	for i in range(_shop_weapons.size()):
		var wpn = _shop_weapons[i]
		var btn = Button.new()
		var full = GameManager.owned_weapons.size() >= 6
		btn.text = "%s (%dG)%s" % [wpn["name"], wpn["price"], " [已满]" if full else ""]
		btn.custom_minimum_size = Vector2(200, 44)
		btn.disabled = full or GameManager.coins < wpn["price"]
		btn.pressed.connect(_on_buy_weapon.bind(i))
		_weapon_container.add_child(btn)

func _on_buy_item(index: int) -> void:
	if index >= _shop_items.size():
		return
	var item = _shop_items[index]
	if GameManager.coins < item["price"]:
		return
	GameManager.coins -= item["price"]
	GameManager.apply_item(item["id"])
	_shop_items.remove_at(index)
	EventBus.emit("coins_changed", GameManager.coins)
	_coin_label.text = "金币: %d" % GameManager.coins
	_update_display()

func _on_buy_weapon(index: int) -> void:
	if index >= _shop_weapons.size():
		return
	var wpn = _shop_weapons[index]
	if GameManager.coins < wpn["price"]:
		return
	if GameManager.owned_weapons.size() >= 6:
		return
	GameManager.coins -= wpn["price"]
	GameManager.add_weapon(wpn["id"])
	_shop_weapons.remove_at(index)
	EventBus.emit("coins_changed", GameManager.coins)
	_coin_label.text = "金币: %d" % GameManager.coins
	_update_display()

func _on_sell_weapon(weapon_id: String) -> void:
	var refund = GameManager.sell_weapon(weapon_id)
	if refund > 0:
		_coin_label.text = "金币: %d" % GameManager.coins
		_update_display()

func _on_merge_weapons(weapon_id: String) -> void:
	var result = GameManager.try_merge_weapons(weapon_id)
	if result != "":
		var cfg = ConfigLoader.get_weapon(result)
		print("合成成功: %s" % cfg.get("name", result))
		_update_display()

func _on_refresh_pressed() -> void:
	refresh_shop()

func _on_next_wave_pressed() -> void:
	hide()
	GameManager.set_state(GameManager.State.PLAYING)
	var world = get_tree().get_first_node_in_group("game_world")
	if world:
		world.start_next_wave()
