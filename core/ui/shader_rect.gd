@tool
extends Node2D

var _map_size: Vector2

func _ready() -> void:
	_map_size = MapConfig.get_size()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(MapConfig.MAP_SIZE, MapConfig.MAP_SIZE)), Color(0.25, 0.16, 0.08))
		return
	draw_rect(Rect2(Vector2.ZERO, _map_size), Color.WHITE)
