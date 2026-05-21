extends Control

var _is_multiplayer: bool = false
var _player_selections: Dictionary = {}
var _pending_selection: String = ""
var _players: Array = []
var _start_btn: Button
var _player_selection_labels: VBoxContainer

func _ready() -> void:
	_is_multiplayer = MultiplayerManager.is_online
	if _is_multiplayer:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_refresh_player_list()

	_create_ui()

	if _is_multiplayer:
		_update_player_selections_display()

func _create_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title = Label.new()
	title.text = "选择角色"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.position = Vector2(0, 12)
	title.size = Vector2(1280, 50)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 1))
	add_child(title)

	if _is_multiplayer:
		var panel = Panel.new()
		panel.position = Vector2(890, 10)
		panel.size = Vector2(370, 200)
		panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.12, 0.18, 0.95)))
		add_child(panel)

		var pl_title = Label.new()
		pl_title.text = "已连接的玩家"
		pl_title.position = Vector2(900, 16)
		pl_title.size = Vector2(350, 24)
		pl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl_title.add_theme_font_size_override("font_size", 16)
		pl_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
		add_child(pl_title)

		_player_selection_labels = VBoxContainer.new()
		_player_selection_labels.position = Vector2(900, 44)
		_player_selection_labels.size = Vector2(350, 140)
		_player_selection_labels.add_theme_constant_override("separation", 4)
		add_child(_player_selection_labels)

		var back_btn = Button.new()
		back_btn.text = "离开"
		back_btn.position = Vector2(900, 185)
		back_btn.size = Vector2(170, 28)
		back_btn.pressed.connect(_on_leave)
		add_child(back_btn)

		_start_btn = Button.new()
		_start_btn.text = "开始游戏 (仅房主)"
		_start_btn.position = Vector2(1080, 185)
		_start_btn.size = Vector2(170, 28)
		_start_btn.pressed.connect(_on_start_game)
		_start_btn.disabled = true
		_start_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		add_child(_start_btn)
	else:
		_start_btn = Button.new()
		_start_btn.text = "开始游戏"
		_start_btn.position = Vector2(490, 655)
		_start_btn.size = Vector2(300, 44)
		_start_btn.add_theme_font_size_override("font_size", 22)
		_start_btn.pressed.connect(_on_start_game)
		_start_btn.disabled = true
		_start_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		add_child(_start_btn)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(30, 70)
	scroll.size = Vector2(840, 590)
	scroll.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.08, 0.11, 0.9)))
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	for char in ConfigLoader.characters:
		var card = _make_character_card(char)
		vbox.add_child(card)

	var single_back = Button.new()
	single_back.text = "返回"
	single_back.position = Vector2(30, 668)
	single_back.size = Vector2(140, 36)
	single_back.pressed.connect(_on_leave)
	add_child(single_back)

func _make_character_card(char: Dictionary) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(810, 130)
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.14, 0.14, 0.19, 0.95)))

	var hbox = HBoxContainer.new()
	hbox.position = Vector2(8, 6)
	hbox.size = Vector2(794, 118)
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var preview = _make_character_preview(char["id"])
	hbox.add_child(preview)

	var info_vbox = VBoxContainer.new()
	info_vbox.custom_minimum_size = Vector2(480, 0)
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = char["name"] + "  (" + _char_id_display(char["id"]) + ")"
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	info_vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = char["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(470, 0)
	info_vbox.add_child(desc_lbl)

	var mods = char.get("stat_modifiers", {})
	if not mods.is_empty():
		var mod_texts: Array = []
		for key in mods:
			var val = mods[key]
			var sign = "+" if val >= 0 else ""
			var label_name = _stat_label(key)
			if typeof(val) == TYPE_FLOAT:
				mod_texts.append("%s %s%.0f%%" % [label_name, sign, val * 100])
			else:
				mod_texts.append("%s %s%d" % [label_name, sign, int(val)])
		var mod_lbl = Label.new()
		mod_lbl.text = "修正: " + ", ".join(mod_texts)
		mod_lbl.add_theme_font_size_override("font_size", 11)
		mod_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1))
		info_vbox.add_child(mod_lbl)

	var weapons = char.get("starting_weapons", [])
	var w_names: Array = []
	for w in weapons:
		var wc = ConfigLoader.get_weapon(w)
		if not wc.is_empty():
			w_names.append(wc["name"])
	var wpn_lbl = Label.new()
	wpn_lbl.text = "初始武器: " + ", ".join(w_names)
	wpn_lbl.add_theme_font_size_override("font_size", 11)
	wpn_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1))
	info_vbox.add_child(wpn_lbl)

	var btn_panel = Panel.new()
	btn_panel.custom_minimum_size = Vector2(100, 110)
	btn_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.10, 0.14, 0.95)))
	hbox.add_child(btn_panel)

	var btn_vbox = VBoxContainer.new()
	btn_vbox.position = Vector2(8, 6)
	btn_vbox.size = Vector2(84, 98)
	btn_vbox.add_theme_constant_override("separation", 6)
	btn_panel.add_child(btn_vbox)

	var sel_btn = Button.new()
	sel_btn.text = "选择"
	sel_btn.custom_minimum_size = Vector2(0, 44)
	sel_btn.add_theme_font_size_override("font_size", 16)
	sel_btn.pressed.connect(_on_character_selected.bind(char["id"]))
	btn_vbox.add_child(sel_btn)

	var selected_lbl = Label.new()
	selected_lbl.text = ""
	selected_lbl.name = "SelectedLabel"
	selected_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_lbl.add_theme_font_size_override("font_size", 10)
	selected_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))
	btn_vbox.add_child(selected_lbl)

	return card

func _make_character_preview(char_id: String) -> Control:
	var ctrl = Control.new()
	ctrl.custom_minimum_size = Vector2(100, 100)

	var skin = _get_visual_skin(char_id)
	var body_color = skin["body"]
	var dark_color = skin["inner"]
	var eye_color = skin["eyes"]
	var sz = skin["size"]
	var black = Color(0.05, 0.05, 0.05, 0.9)

	var body = ColorRect.new()
	body.color = body_color
	body.size = Vector2(sz * 1.8, sz * 1.8)
	body.position = Vector2(50 - sz * 0.9, 50 - sz * 0.9)
	_add_circle_mask(body)
	ctrl.add_child(body)

	var inner = ColorRect.new()
	inner.color = dark_color
	inner.size = Vector2(sz * 1.0, sz * 1.0)
	inner.position = Vector2(50 - sz * 0.5, 50 - sz * 0.5)
	_add_circle_mask(inner)
	ctrl.add_child(inner)

	var eye_l = ColorRect.new()
	eye_l.color = eye_color
	eye_l.size = Vector2(sz * 0.45, sz * 0.45)
	eye_l.position = Vector2(50 - sz * 0.4, 50 - sz * 0.5)
	_add_circle_mask(eye_l)
	ctrl.add_child(eye_l)

	var eye_r = ColorRect.new()
	eye_r.color = eye_color
	eye_r.size = Vector2(sz * 0.45, sz * 0.45)
	eye_r.position = Vector2(50 + sz * 0.05, 50 - sz * 0.5)
	_add_circle_mask(eye_r)
	ctrl.add_child(eye_r)

	var pupil_l = ColorRect.new()
	pupil_l.color = black
	pupil_l.size = Vector2(sz * 0.2, sz * 0.2)
	pupil_l.position = Vector2(50 - sz * 0.23, 50 - sz * 0.34)
	_add_circle_mask(pupil_l)
	ctrl.add_child(pupil_l)

	var pupil_r = ColorRect.new()
	pupil_r.color = black
	pupil_r.size = Vector2(sz * 0.2, sz * 0.2)
	pupil_r.position = Vector2(50 + sz * 0.22, 50 - sz * 0.34)
	_add_circle_mask(pupil_r)
	ctrl.add_child(pupil_r)

	var outline = ColorRect.new()
	outline.color = Color(0.25, 0.25, 0.25, 0.5)
	outline.size = Vector2(sz * 1.85, sz * 1.85)
	outline.position = Vector2(50 - sz * 0.925, 50 - sz * 0.925)
	_add_circle_mask(outline)
	ctrl.add_child(outline)

	return ctrl

func _get_visual_skin(char_id: String) -> Dictionary:
	match char_id:
		"berserker":
			return {"body": Color(0.85, 0.22, 0.15, 1), "inner": Color(0.55, 0.08, 0.05, 1), "eyes": Color(1, 0.9, 0.2, 0.95), "size": 26.0}
		"ranger":
			return {"body": Color(0.12, 0.45, 0.22, 1), "inner": Color(0.05, 0.30, 0.10, 1), "eyes": Color(1, 1, 1, 0.95), "size": 24.0}
		"shotgunner":
			return {"body": Color(0.70, 0.45, 0.12, 1), "inner": Color(0.40, 0.22, 0.05, 1), "eyes": Color(1, 0.8, 0, 0.95), "size": 25.0}
		"juggernaut":
			return {"body": Color(0.25, 0.28, 0.35, 1), "inner": Color(0.10, 0.12, 0.18, 1), "eyes": Color(1, 0.4, 0.2, 0.95), "size": 28.0}
		"shadow":
			return {"body": Color(0.18, 0.08, 0.28, 1), "inner": Color(0.08, 0.02, 0.12, 1), "eyes": Color(0.9, 0.1, 0.8, 0.95), "size": 23.0}
		"engineer":
			return {"body": Color(0.90, 0.60, 0.12, 1), "inner": Color(0.60, 0.35, 0.05, 1), "eyes": Color(0, 0.6, 1, 0.95), "size": 25.0}
		"plague_doctor":
			return {"body": Color(0.15, 0.42, 0.20, 1), "inner": Color(0.05, 0.25, 0.10, 1), "eyes": Color(0.9, 0.9, 0, 0.95), "size": 24.0}
		"merchant":
			return {"body": Color(0.65, 0.45, 0.15, 1), "inner": Color(0.40, 0.25, 0.05, 1), "eyes": Color(1, 0.85, 0, 0.95), "size": 23.0}
		"gladiator":
			return {"body": Color(0.75, 0.30, 0.08, 1), "inner": Color(0.45, 0.12, 0.04, 1), "eyes": Color(1, 1, 1, 0.95), "size": 27.0}
		"elementalist":
			return {"body": Color(0.20, 0.30, 0.70, 1), "inner": Color(0.08, 0.12, 0.40, 1), "eyes": Color(0.3, 1, 1, 0.95), "size": 24.0}
		"survivor":
			return {"body": Color(0.30, 0.35, 0.25, 1), "inner": Color(0.12, 0.15, 0.08, 1), "eyes": Color(0.8, 0.8, 0.8, 0.95), "size": 24.0}
		"lucky":
			return {"body": Color(0.90, 0.75, 0.15, 1), "inner": Color(0.60, 0.50, 0.05, 1), "eyes": Color(0, 0.9, 0, 0.95), "size": 24.0}
		_:
			return {"body": Color(0, 0.74, 0.83, 1), "inner": Color(0, 0.45, 0.55, 1), "eyes": Color(1, 1, 1, 0.95), "size": 25.0}

func _add_circle_mask(rect: ColorRect) -> void:
	rect.pivot_offset = rect.size * 0.5

func _char_id_display(char_id: String) -> String:
	match char_id:
		"berserker": return "狂战士"
		"ranger": return "游侠"
		"shotgunner": return "爆破手"
		"juggernaut": return "重装兵"
		"shadow": return "暗影刺客"
		"engineer": return "工程师"
		"plague_doctor": return "瘟疫医生"
		"merchant": return "商人"
		"gladiator": return "角斗士"
		"elementalist": return "元素师"
		"survivor": return "生存专家"
		"lucky": return "幸运星"
		_: return "士兵"

func _stat_label(key: String) -> String:
	match key:
		"max_hp": return "生命"
		"hp_regen": return "回复"
		"speed": return "速度"
		"damage": return "攻击"
		"damage_percent": return "伤害%"
		"attack_speed": return "攻速"
		"crit_chance": return "暴击"
		"crit_damage": return "暴伤"
		"armor": return "护甲"
		"dodge_chance": return "闪避"
		"range": return "射程"
		"luck": return "幸运"
		"xp_gain": return "经验"
		"coin_gain": return "金币"
		"pickup_radius": return "拾取"
		"knockback": return "击退"
		"pierce": return "穿透"
		"life_steal": return "吸血"
		_: return key

func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _on_character_selected(char_id: String) -> void:
	var my_id = 1
	if _is_multiplayer:
		my_id = multiplayer.get_unique_id()
		rpc("_rpc_player_selected", my_id, char_id)

	_player_selections[my_id] = char_id
	GameManager.apply_character(char_id)

	_update_all_selected_labels()
	_check_all_ready()

	if not _is_multiplayer:
		_start_btn.disabled = false
		_start_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_player_selected(peer_id: int, char_id: String) -> void:
	_player_selections[peer_id] = char_id
	_update_player_selections_display()
	_update_all_selected_labels()
	_check_all_ready()

func _update_all_selected_labels() -> void:
	var all_cards = _find_character_cards()
	for card_node in all_cards:
		card_node = card_node as Control

func _find_character_cards() -> Array:
	var cards: Array = []
	var scroll: ScrollContainer = null
	for child in get_children():
		if child is ScrollContainer:
			scroll = child
			break
	if scroll:
		var vbox = scroll.get_child(0)
		for card in vbox.get_children():
			cards.append(card)
	return cards

func _update_player_selections_display() -> void:
	if not _player_selection_labels:
		return
	for child in _player_selection_labels.get_children():
		child.queue_free()

	var my_id = multiplayer.get_unique_id()

	for pid in MultiplayerManager.connected_players:
		var info = MultiplayerManager.connected_players[pid]
		var name = info.get("name", "玩家%d" % pid)
		var sel = _player_selections.get(pid, "")
		var sel_text = ""
		if sel != "":
			var cfg = ConfigLoader.get_character(sel)
			if not cfg.is_empty():
				sel_text = " → " + cfg["name"]
		var label = Label.new()
		label.text = "  %s%s" % [name, sel_text]
		label.add_theme_font_size_override("font_size", 14)
		if sel != "":
			label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))
		else:
			label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		_player_selection_labels.add_child(label)

	if MultiplayerManager.is_host:
		_start_btn.text = "开始游戏 (%d/%d)" % [_ready_count(), MultiplayerManager.connected_players.size()]

func _check_all_ready() -> void:
	if not _is_multiplayer:
		return
	if not MultiplayerManager.is_host:
		return
	if _ready_count() >= MultiplayerManager.connected_players.size():
		_start_btn.disabled = false
		_start_btn.text = "开始游戏"
		_start_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1))
	else:
		_start_btn.disabled = true

func _ready_count() -> int:
	var cnt = 0
	for pid in MultiplayerManager.connected_players:
		if _player_selections.has(pid) and _player_selections[pid] != "":
			cnt += 1
	return cnt

func _on_start_game() -> void:
	if _is_multiplayer:
		if not MultiplayerManager.is_host:
			return
		if _ready_count() < MultiplayerManager.connected_players.size():
			return
		rpc("_rpc_start_game")
		await get_tree().process_frame

	_start_game_internal()

@rpc("authority", "call_remote", "reliable")
func _rpc_start_game() -> void:
	_start_game_internal()

func _start_game_internal() -> void:
	if _is_multiplayer:
		var my_id = multiplayer.get_unique_id()
		var my_char = _player_selections.get(my_id, "")
		if my_char == "":
			my_char = "soldier"
		GameManager.apply_character(my_char)

	GameManager.start_game()
	get_tree().change_scene_to_file("res://maps/game_world.tscn")

func _on_peer_connected(id: int) -> void:
	_refresh_player_list()
	_update_player_selections_display()

func _on_peer_disconnected(id: int) -> void:
	_player_selections.erase(id)
	_refresh_player_list()
	_update_player_selections_display()
	_check_all_ready()

func _refresh_player_list() -> void:
	_update_player_selections_display()

func _on_leave() -> void:
	if _is_multiplayer:
		MultiplayerManager.disconnect_game()
	get_tree().change_scene_to_file("res://maps/main_menu.tscn")
