extends CanvasLayer

func _ready() -> void:
	hide()
	EventBus.on("game_over", _on_game_over)

func _on_game_over(data: Dictionary) -> void:
	var won = data.get("won", false)
	$Panel/VBoxContainer/TitleLabel.text = "胜利！" if won else "阵亡"
	$Panel/VBoxContainer/WaveLabel.text = "到达波次: %d" % data.get("wave", 0)
	$Panel/VBoxContainer/CoinLabel.text = "金币: %d" % data.get("coins", 0)
	$Panel/VBoxContainer/LevelLabel.text = "等级: %d" % data.get("level", 1)
	$Panel/VBoxContainer/KillLabel.text = "击杀: %d" % data.get("kills", 0)
	show()

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://maps/main_menu.tscn")
