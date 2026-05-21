extends CanvasLayer

var _current_perks: Array = []

func _ready() -> void:
	hide()
	EventBus.on("show_perks", _on_show_perks)
	$Panel/VBoxContainer/PerkButton1.pressed.connect(_on_perk_0)
	$Panel/VBoxContainer/PerkButton2.pressed.connect(_on_perk_1)
	$Panel/VBoxContainer/PerkButton3.pressed.connect(_on_perk_2)

func _exit_tree() -> void:
	EventBus.off("show_perks", _on_show_perks)

func _on_show_perks(_data = null) -> void:
	_current_perks = ConfigLoader.get_random_perks(3)
	if _current_perks.size() == 0:
		GameManager.pending_levels = 0
		EventBus.emit("perks_done")
		return

	for i in range(3):
		var btn = get_node("Panel/VBoxContainer/PerkButton" + str(i + 1))
		if i < _current_perks.size():
			var perk = _current_perks[i]
			btn.text = "%s\n%s" % [perk["name"], perk["desc"]]
			btn.disabled = false
			btn.show()
		else:
			btn.hide()

	GameManager.set_state(GameManager.State.PERK_SELECT)
	show()

func _on_perk_0() -> void: _apply_perk(0)
func _on_perk_1() -> void: _apply_perk(1)
func _on_perk_2() -> void: _apply_perk(2)

func _apply_perk(index: int) -> void:
	if index >= _current_perks.size():
		return
	var perk = _current_perks[index]
	GameManager.apply_perk(perk["id"])
	hide()

	if GameManager.pending_levels > 0:
		await get_tree().create_timer(0.3).timeout
		_on_show_perks({})
	else:
		GameManager.set_state(GameManager.State.PLAYING)
		EventBus.emit("perks_done")
