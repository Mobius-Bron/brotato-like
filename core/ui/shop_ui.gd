extends CanvasLayer

var _shop_items: Array = []
var _shop_weapons: Array = []
var _refresh_cost: int = 0
var _refresh_count: int = 0
@onready var _stats_container: VBoxContainer = $ShopPanel/MarginContainer/HBoxContainer/StatsColumn/StatsScroll/StatsContainer
@onready var _item_container: VBoxContainer = $ShopPanel/MarginContainer/HBoxContainer/CenterColumn/ItemScroll/ItemContainer
@onready var _weapon_container: VBoxContainer = $ShopPanel/MarginContainer/HBoxContainer/CenterColumn/WeaponScroll/WeaponContainer
@onready var _inventory_container: VBoxContainer = $ShopPanel/MarginContainer/HBoxContainer/RightColumn/InventoryScroll/InventoryContainer
@onready var _coin_label: Label = $ShopPanel/MarginContainer/HBoxContainer/RightColumn/BottomRow/CoinLabel
@onready var _refresh_btn: Button = $ShopPanel/MarginContainer/HBoxContainer/CenterColumn/RefreshButton

func _ready() -> void:
	hide()
	EventBus.on("show_shop", _on_show_shop)

func _exit_tree() -> void:
	EventBus.off("show_shop", _on_show_shop)

func _on_show_shop(_data = null) -> void:
	await get_tree().create_timer(0.5).timeout
	if _refresh_cost == 0:
		_refresh_cost = 5
	_refresh_count = 0
	generate_shop()
	show()

func _get_wave_price_mult() -> float:
	return 1.0 + (GameManager.current_wave - 1) * 0.08

func generate_shop() -> void:
	_shop_items.clear()
	_shop_weapons.clear()

	var wave_mult = _get_wave_price_mult()
	var inflate = _refresh_count * 5

	var all_items = ConfigLoader.items.duplicate()
	all_items.shuffle()
	for i in range(min(5, all_items.size())):
		var item = all_items[i].duplicate()
		item["price"] = max(1, int(item["price"] * wave_mult) + inflate)
		_shop_items.append(item)

	var all_weapons = ConfigLoader.weapons.duplicate()
	all_weapons = all_weapons.filter(func(w):
		var eco = w.get("ecosystem", "")
		return eco != "enemy" and w.get("price", 0) > 0 and w.get("tier", 1) == 1
	)
	all_weapons.shuffle()
	for i in range(min(4, all_weapons.size())):
		var wpn = all_weapons[i].duplicate()
		wpn["price"] = max(1, int(wpn["price"] * wave_mult) + inflate)
		_shop_weapons.append(wpn)

	_coin_label.text = "金币: %d" % GameManager.coins
	_update_display()

func refresh_shop() -> void:
	if GameManager.coins < _refresh_cost:
		return
	GameManager.coins -= _refresh_cost
	_refresh_cost += 5
	_refresh_count += 1
	EventBus.emit("coins_changed", GameManager.coins)
	generate_shop()

func _update_display() -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	for child in _item_container.get_children():
		child.queue_free()
	for child in _weapon_container.get_children():
		child.queue_free()
	for child in _inventory_container.get_children():
		child.queue_free()

	_refresh_btn.text = "刷新商品 (%dG)" % _refresh_cost
	_refresh_btn.disabled = GameManager.coins < _refresh_cost

	_update_stats()
	_update_inventory()
	_update_shop_items()
	_update_shop_weapons()

func _update_stats() -> void:
	var sb = GameManager.stat_bonuses
	var lines := [
		{"label": "生命", "val": sb["max_hp"], "suffix": ""},
		{"label": "回复", "val": sb["hp_regen"], "suffix": "/s"},
		{"label": "速度", "val": sb["speed"], "suffix": ""},
		{"label": "攻击", "val": sb["damage"], "suffix": ""},
		{"label": "伤害%", "val": sb["damage_percent"], "suffix": "%", "is_pct": true},
		{"label": "攻速", "val": sb["attack_speed"], "suffix": "%", "is_pct": true},
		{"label": "暴击", "val": sb["crit_chance"], "suffix": "%", "is_pct": true},
		{"label": "暴伤", "val": sb["crit_damage"], "suffix": "%", "is_pct": true},
		{"label": "护甲", "val": sb["armor"], "suffix": ""},
		{"label": "闪避", "val": sb["dodge_chance"], "suffix": "%", "is_pct": true},
		{"label": "射程", "val": sb["range"], "suffix": ""},
		{"label": "幸运", "val": sb["luck"], "suffix": ""},
		{"label": "经验", "val": sb["xp_gain"], "suffix": "%", "is_pct": true},
		{"label": "金币", "val": sb["coin_gain"], "suffix": "%", "is_pct": true},
		{"label": "拾取", "val": sb["pickup_radius"], "suffix": ""},
		{"label": "击退", "val": sb["knockback"], "suffix": "%", "is_pct": true},
		{"label": "穿透", "val": sb["pierce"], "suffix": ""},
		{"label": "吸血", "val": sb["life_steal"], "suffix": "%", "is_pct": true},
		{"label": "爆炸率", "val": sb["explosion_chance"], "suffix": "%", "is_pct": true},
		{"label": "爆炸范围", "val": sb["explosion_size"], "suffix": ""},
	]

	for line in lines:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var name_lbl = Label.new()
		name_lbl.text = line["label"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		name_lbl.custom_minimum_size = Vector2(70, 0)
		hbox.add_child(name_lbl)

		var val_lbl = Label.new()
		var val = line["val"]
		var is_pct: bool = line.get("is_pct", false)
		if is_pct:
			val_lbl.text = "%+.0f%s" % [val * 100.0, line["suffix"]]
		elif typeof(val) == TYPE_FLOAT:
			val_lbl.text = "%+.1f%s" % [val, line["suffix"]]
		else:
			val_lbl.text = "%+d%s" % [int(val), line["suffix"]]
		val_lbl.add_theme_font_size_override("font_size", 12)
		if (typeof(val) == TYPE_FLOAT and val > 0.001) or (typeof(val) == TYPE_INT and val > 0):
			val_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))
		elif (typeof(val) == TYPE_FLOAT and val < -0.001) or (typeof(val) == TYPE_INT and val < 0):
			val_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1))
		else:
			val_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(val_lbl)

		_stats_container.add_child(hbox)

	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 4)
	_stats_container.add_child(sep)

	var slot_hbox = HBoxContainer.new()
	slot_hbox.add_theme_constant_override("separation", 6)
	var slot_name = Label.new()
	slot_name.text = "槽位"
	slot_name.add_theme_font_size_override("font_size", 12)
	slot_name.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	slot_name.custom_minimum_size = Vector2(70, 0)
	slot_hbox.add_child(slot_name)
	var slot_val = Label.new()
	slot_val.text = "%d" % GameManager.get_weapon_slots()
	slot_val.add_theme_font_size_override("font_size", 12)
	slot_val.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1))
	slot_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slot_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_hbox.add_child(slot_val)
	_stats_container.add_child(slot_hbox)

	var dmg_mult = GameManager.weapon_slot_damage_mult()
	if dmg_mult != 1.0:
		var dm_hbox = HBoxContainer.new()
		dm_hbox.add_theme_constant_override("separation", 6)
		var dm_name = Label.new()
		dm_name.text = "武器倍率"
		dm_name.add_theme_font_size_override("font_size", 12)
		dm_name.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		dm_name.custom_minimum_size = Vector2(70, 0)
		dm_hbox.add_child(dm_name)
		var dm_val = Label.new()
		dm_val.text = "x%.1f" % dmg_mult
		dm_val.add_theme_font_size_override("font_size", 12)
		dm_val.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3, 1))
		dm_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dm_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dm_hbox.add_child(dm_val)
		_stats_container.add_child(dm_hbox)

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

	var idx = 0
	for weapon_id in counted:
		var cfg = ConfigLoader.get_weapon(weapon_id)
		if cfg.is_empty():
			continue
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 34)
		hbox.add_theme_constant_override("separation", 4)

		if weapons.size() > 1:
			if idx > 0:
				var up_btn = Button.new()
				up_btn.text = "▲"
				up_btn.custom_minimum_size = Vector2(24, 24)
				up_btn.pressed.connect(_on_swap_weapons.bind(idx - 1, idx))
				hbox.add_child(up_btn)
			else:
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(24, 0)
				hbox.add_child(spacer)

			if idx < weapons.size() - 1:
				var down_btn = Button.new()
				down_btn.text = "▼"
				down_btn.custom_minimum_size = Vector2(24, 24)
				down_btn.pressed.connect(_on_swap_weapons.bind(idx, idx + 1))
				hbox.add_child(down_btn)
			else:
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(24, 0)
				hbox.add_child(spacer)

		var eco = cfg.get("ecosystem", "weapon")
		var eco_lbl = Label.new()
		eco_lbl.text = "[%s]" % eco
		eco_lbl.add_theme_font_size_override("font_size", 9)
		eco_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		eco_lbl.custom_minimum_size = Vector2(50, 0)
		hbox.add_child(eco_lbl)

		var name_lbl = Label.new()
		name_lbl.text = "%s x%d" % [cfg["name"], counted[weapon_id]]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)

		var sell_btn = Button.new()
		sell_btn.text = "卖%dG" % int(cfg.get("price", 0) * 0.5)
		sell_btn.custom_minimum_size = Vector2(55, 26)
		sell_btn.pressed.connect(_on_sell_weapon.bind(weapon_id))
		hbox.add_child(sell_btn)

		if counted[weapon_id] >= 2:
			var upgrade_id = GameManager.get_weapon_tier_upgrade(weapon_id)
			if upgrade_id != "":
				var merge_btn = Button.new()
				var up_cfg = ConfigLoader.get_weapon(upgrade_id)
				merge_btn.text = "合成%s" % up_cfg.get("name", "?")
				merge_btn.custom_minimum_size = Vector2(72, 26)
				merge_btn.pressed.connect(_on_merge_weapons.bind(weapon_id))
				hbox.add_child(merge_btn)

		_inventory_container.add_child(hbox)
		idx += 1

func _update_shop_items() -> void:
	for i in range(_shop_items.size()):
		var item = _shop_items[i]
		var btn = Button.new()
		btn.text = "%s - %s (%dG)" % [item["name"], item["desc"], item["price"]]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.disabled = GameManager.coins < item["price"]
		btn.pressed.connect(_on_buy_item.bind(i))
		_item_container.add_child(btn)

func _update_shop_weapons() -> void:
	for i in range(_shop_weapons.size()):
		var wpn = _shop_weapons[i]
		var btn = Button.new()
		var full = GameManager.owned_weapons.size() >= GameManager.get_weapon_slots()
		var eco = wpn.get("ecosystem", "weapon")
		btn.text = "[%s] %s (%dG)%s" % [eco, wpn["name"], wpn["price"], " [已满]" if full else ""]
		btn.custom_minimum_size = Vector2(0, 40)
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
	if not GameManager.add_weapon(wpn["id"]):
		return
	GameManager.coins -= wpn["price"]
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
		_update_display()

func _on_swap_weapons(idx_a: int, idx_b: int) -> void:
	GameManager.swap_weapons(idx_a, idx_b)
	_update_display()

func _on_refresh_pressed() -> void:
	refresh_shop()

func _on_next_wave_pressed() -> void:
	hide()
	GameManager.set_state(GameManager.State.PLAYING)
	var world = get_tree().get_first_node_in_group("game_world")
	if world:
		world.start_next_wave()
