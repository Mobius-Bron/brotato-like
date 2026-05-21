extends Control

func _ready() -> void:
	GameManager.set_state(GameManager.State.MENU)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://maps/game_world.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
