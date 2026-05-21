extends Control

func _ready() -> void:
	GameManager.set_state(GameManager.State.MENU)

func _on_start_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://maps/character_select.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
