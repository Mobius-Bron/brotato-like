@tool
extends Node2D

var _map_size: Vector2
var _last_positions:= ""
var _effect_positions: Array = []
const FLATTEN_RADIUS: float = 0.06

func _ready() -> void:
	_map_size = MapConfig.get_size()
	setup_shader()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var effects_changed = _update_effects(delta)
	if effects_changed:
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(MapConfig.MAP_SIZE, MapConfig.MAP_SIZE)), Color(0.2, 0.35, 0.12))
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
				_add_point(points, world.transforms[pid]["position"])
	for eid in world.enemies:
		if world.transforms.has(eid) and points.size() < 19:
			_add_point(points, world.transforms[eid]["position"])
	for ef in _effect_positions:
		_add_point(points, ef["pos"])

	_push_flatten(points)

func add_effect(pos: Vector2, radius: float, duration: float) -> void:
	_effect_positions.append({
		"pos": pos,
		"radius": radius,
		"remaining": duration
	})

func _update_effects(delta: float) -> bool:
	var changed = false
	var i = _effect_positions.size() - 1
	while i >= 0:
		_effect_positions[i]["remaining"] -= delta
		if _effect_positions[i]["remaining"] <= 0:
			_effect_positions.remove_at(i)
			changed = true
		i -= 1
	return changed or _effect_positions.size() > 0

func _add_point(arr: Array, pos: Vector2) -> void:
	arr.append(pos)

func _push_flatten(points: Array) -> void:
	var mat = material as ShaderMaterial
	if not mat:
		return

	var uv_list: Array = []
	for pos in points:
		uv_list.append(Vector2(pos.x / _map_size.x, pos.y / _map_size.y))
	while uv_list.size() < 20:
		uv_list.append(Vector2(-999, -999))

	var new_key = str(uv_list)
	if new_key == _last_positions and _effect_positions.size() == 0:
		return
	_last_positions = new_key

	mat.set_shader_parameter("flatten_positions", uv_list)
	mat.set_shader_parameter("flatten_count", float(min(points.size(), 20)))
	queue_redraw()
