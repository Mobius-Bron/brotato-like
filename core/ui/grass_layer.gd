@tool
extends Node2D

var _map_size: Vector2
var _last_positions_key := ""

func _ready() -> void:
	_map_size = MapConfig.get_size()
	setup_shader()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(MapConfig.MAP_SIZE, MapConfig.MAP_SIZE)), Color(0.22, 0.42, 0.14))
		return
	draw_rect(Rect2(Vector2.ZERO, _map_size), Color.WHITE)

func setup_shader() -> void:
	var mat = material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("flatten_count", 0)
	var defaults: Array = []
	for i in range(20):
		defaults.append(Vector2(-999, -999))
	mat.set_shader_parameter("flatten_positions", defaults)

func update_flatten_positions(world: ECSWorld) -> void:
	var points: Array = []

	if world.players.size() > 0:
		for pid in world.players:
			if world.transforms.has(pid):
				points.append(world.transforms[pid]["position"])

	for eid in world.enemies:
		if world.transforms.has(eid) and points.size() < 18:
			points.append(world.transforms[eid]["position"])

	for pid in world.projectiles:
		if world.transforms.has(pid) and points.size() < 18:
			points.append(world.transforms[pid]["position"])

	var uv_list: Array = []
	for pos in points:
		uv_list.append(Vector2(pos.x / _map_size.x, pos.y / _map_size.y))
	while uv_list.size() < 20:
		uv_list.append(Vector2(-999, -999))

	var key = str(uv_list)
	if key == _last_positions_key:
		return
	_last_positions_key = key

	var mat = material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("flatten_positions", uv_list)
	mat.set_shader_parameter("flatten_count", float(min(points.size(), 20)))
	queue_redraw()
