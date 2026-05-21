@tool
extends Node2D

var _map_size: Vector2
var _effects: Array = []
var _last_push_key := ""
var _max_effects := 60

func _ready() -> void:
	_map_size = MapConfig.get_size()
	setup_shader()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_effects(delta)
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

func add_effect(pos: Vector2, strength: float = 1.0, duration: float = 2.0) -> void:
	for ef in _effects:
		var d = ef["pos"].distance_to(pos)
		if d < 28.0:
			ef["strength"] = maxf(ef["strength"], strength)
			ef["remaining"] = maxf(ef["remaining"], duration)
			return

	_effects.append({"pos": pos, "strength": strength, "remaining": duration})
	if _effects.size() > _max_effects:
		_effects.sort_custom(func(a, b): return a["remaining"] < b["remaining"])
		_effects.resize(_max_effects)

func update_flatten_positions(world: ECSWorld) -> void:
	if world.players.size() > 0:
		for pid in world.players:
			if world.transforms.has(pid):
				add_effect(world.transforms[pid]["position"], 1.0, 999.0)

	for eid in world.enemies:
		if world.transforms.has(eid):
			add_effect(world.transforms[eid]["position"], 0.7, 999.0)

	for pid in world.projectiles:
		if world.transforms.has(pid):
			add_effect(world.transforms[pid]["position"], 0.4, 0.6)

	_push_to_shader()

func _update_effects(delta: float) -> void:
	var changed = false
	var i = _effects.size() - 1
	while i >= 0:
		var ef = _effects[i]
		if ef["remaining"] > 100.0:
			i -= 1
			continue
		ef["remaining"] -= delta
		if ef["remaining"] <= 0:
			_effects.remove_at(i)
			changed = true
		i -= 1
	if changed:
		_push_to_shader()

func _push_to_shader() -> void:
	var mat = material as ShaderMaterial
	if not mat:
		return

	var player_uv := Vector2(-999, -999)
	var candidates: Array = []

	for ef in _effects:
		var fade = clampf(ef["remaining"] / 1.5, 0.0, 1.0) * ef["strength"]
		if fade < 0.02:
			continue
		var uv = Vector2(ef["pos"].x / _map_size.x, ef["pos"].y / _map_size.y)
		if ef["strength"] > 0.95:
			player_uv = uv
		elif fade > 0.07:
			candidates.append({"uv": uv, "fade": fade})

	candidates.sort_custom(func(a, b): return a["fade"] > b["fade"])

	var uv_list: Array = []
	if player_uv.x > -500:
		uv_list.append(player_uv)

	for c in candidates:
		if uv_list.size() >= 20:
			break
		uv_list.append(c["uv"])

	var actual_count = uv_list.size()
	while uv_list.size() < 20:
		uv_list.append(Vector2(-999, -999))

	var key = str(uv_list[0]) + str(uv_list.size())
	if key == _last_push_key:
		return
	_last_push_key = key

	mat.set_shader_parameter("flatten_positions", uv_list)
	mat.set_shader_parameter("flatten_count", float(actual_count))
