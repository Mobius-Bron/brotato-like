extends CanvasLayer

var _shop_items: Array = []
var _shop_weapons: Array = []

func _ready() -> void:
	hide()
	EventBus.on("show_shop", _on_show_shop)

func _on_show_shop(_data = null) -> void:
	await get_tree().create_timer(1.0).timeout
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
	all_weapons = all_weapons.filter(func(w): return w.get("price", 0) > 0)
	all_weapons.shuffle()
	for i in range(min(3, all_weapons.size())):
		_shop_weapons.append(all_weapons[i])

	$ShopPanel/VBoxContainer/CoinLabel.text = "金币: %d" % GameManager.coins
	_update_shop_display()

func _update_shop_display() -> void:
	var item_container = $ShopPanel/VBoxContainer/ItemContainer
	var weapon_container = $ShopPanel/VBoxContainer/WeaponContainer

	for child in item_container.get_children():
		child.queue_free()
	for child in weapon_container.get_children():
		child.queue_free()

	for i in range(_shop_items.size()):
		var item = _shop_items[i]
		var btn = Button.new()
		btn.text = "%s (%dG)" % [item["name"], item["price"]]
		btn.custom_minimum_size = Vector2(180, 50)
		btn.disabled = GameManager.coins < item["price"]
		btn.pressed.connect(_on_buy_item.bind(i))
		item_container.add_child(btn)

	for i in range(_shop_weapons.size()):
		var wpn = _shop_weapons[i]
		var btn = Button.new()
		var owned = GameManager.owned_weapons.has(wpn["id"])
		btn.text = "%s (%dG)%s" % [wpn["name"], wpn["price"], " [已拥有]" if owned else ""]
		btn.custom_minimum_size = Vector2(180, 50)
		btn.disabled = owned or GameManager.coins < wpn["price"]
		btn.pressed.connect(_on_buy_weapon.bind(i))
		weapon_container.add_child(btn)

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
	$ShopPanel/VBoxContainer/CoinLabel.text = "金币: %d" % GameManager.coins
	_update_shop_display()

func _on_buy_weapon(index: int) -> void:
	if index >= _shop_weapons.size():
		return
	var wpn = _shop_weapons[index]
	if GameManager.coins < wpn["price"]:
		return
	GameManager.coins -= wpn["price"]
	GameManager.add_weapon(wpn["id"])
	_shop_weapons.remove_at(index)
	EventBus.emit("coins_changed", GameManager.coins)
	$ShopPanel/VBoxContainer/CoinLabel.text = "金币: %d" % GameManager.coins
	_update_shop_display()

func _on_next_wave_pressed() -> void:
	hide()
	GameManager.set_state(GameManager.State.PLAYING)
	var world = get_tree().get_first_node_in_group("game_world")
	if world:
		world.start_next_wave()
