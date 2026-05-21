extends Control

var _pending_selection: String = ""
var _start_btn: Button

func _ready() -> void:
	_create_ui()

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

	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(30, 668)
	back_btn.size = Vector2(140, 36)
	back_btn.pressed.connect(_on_leave)
	add_child(back_btn)

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

	var slots = char.get("weapon_slots", 6)
	var dmg_mult = char.get("weapon_damage_mult", 1.0)
	var rng_mult = char.get("weapon_range_mult", 1.0)
	var slot_text = "槽位: %d个" % slots
	if dmg_mult != 1.0:
		slot_text += "  伤害x%.1f" % dmg_mult
	if rng_mult != 1.0:
		slot_text += "  射程x%.1f" % rng_mult
	var slot_lbl = Label.new()
	slot_lbl.text = slot_text
	slot_lbl.add_theme_font_size_override("font_size", 11)
	if dmg_mult > 1.0 or rng_mult > 1.0:
		slot_lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.3, 1))
	elif dmg_mult < 1.0:
		slot_lbl.add_theme_color_override("font_color", Color(0.9, 0.55, 0.55, 1))
	else:
		slot_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	info_vbox.add_child(slot_lbl)

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
		"cannoneer":
			return {"body": Color(0.55, 0.20, 0.08, 1), "inner": Color(0.30, 0.08, 0.02, 1), "eyes": Color(1, 0.6, 0, 0.95), "size": 27.0}
		"generalist":
			return {"body": Color(0.40, 0.50, 0.60, 1), "inner": Color(0.20, 0.28, 0.35, 1), "eyes": Color(0.8, 0.9, 1, 0.95), "size": 24.0}
		"swordsman":
			return {"body": Color(0.30, 0.50, 0.70, 1), "inner": Color(0.12, 0.28, 0.45, 1), "eyes": Color(1, 1, 1, 0.95), "size": 25.0}
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
		"cannoneer": return "炮手"
		"generalist": return "多面手"
		"swordsman": return "剑圣"
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
	GameManager.apply_character(char_id)
	_start_btn.disabled = false
	_start_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _on_start_game() -> void:
	GameManager.start_game()
	get_tree().change_scene_to_file("res://maps/game_world.tscn")

func _on_leave() -> void:
	get_tree().change_scene_to_file("res://maps/main_menu.tscn")
