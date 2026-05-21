extends Node2D

var world: ECSWorld
var render_system: RenderSystem

func _draw() -> void:
	if render_system and world:
		render_system.draw(world)
