extends Node2D

var _world: ECSWorld
var _render_system: RenderSystem
var _movement_system: MovementSystem
var _orbit_system: WeaponOrbitSystem
var _weapon_system: WeaponSystem
var _collision_system: CollisionSystem
var _health_system: HealthSystem
var _spawn_system: SpawnSystem
var _enemy_factory: EnemyFactory
var _projectile_factory: ProjectileFactory
var _player_id: int = -1
var _between_waves: bool = false
var _map_size: Vector2
var _player_camera: Camera2D

@onready var _mud_layer: Node2D = $MudLayer
@onready var _grass_layer: Node2D = $GrassLayer
@onready var _render_layer: Node2D = $RenderLayer
@onready var _hud: CanvasLayer = $HUD

func _ready() -> void:
	GameManager.reset()
	_map_size = MapConfig.get_size()

	_setup_map_layers()
	_setup_walls()
	_setup_player_camera()

	_world = ECSWorld.new()
	_enemy_factory = EnemyFactory.new(_world, _map_size)
	_projectile_factory = ProjectileFactory.new(_world)

	_movement_system = MovementSystem.new(_map_size)
	_orbit_system = WeaponOrbitSystem.new()
	_health_system = HealthSystem.new(_world)
	_weapon_system = WeaponSystem.new(_projectile_factory, _health_system)
	_collision_system = CollisionSystem.new(_health_system)
	_spawn_system = SpawnSystem.new(_enemy_factory)
	_render_system = RenderSystem.new(_render_layer)
	_render_layer.world = _world
	_render_layer.render_system = _render_system

	_world.add_system(_movement_system)
	_world.add_system(_orbit_system)
	_world.add_system(_weapon_system)
	_world.add_system(_collision_system)
	_world.add_system(_health_system)
	_world.add_system(_spawn_system)
	_world.add_system(_render_system)

	_setup_connections()
	_create_player()
	_spawn_weapon_entities()

	if _grass_layer.has_method("setup_shader"):
		_grass_layer.setup_shader()

	_spawn_system.start_wave(GameManager.current_wave)

func _setup_connections() -> void:
	EventBus.on("enemy_killed", _on_enemy_killed)
	EventBus.on("player_died", _on_player_died)
	EventBus.on("wave_cleared", _on_wave_cleared)
	EventBus.on("player_heal", _on_player_heal)

func _create_player() -> void:
	_player_id = _world.create_entity()
	var center = _map_size * 0.5

	var base_hp = 50 + GameManager.stat_bonuses.get("max_hp", 0)
	_world.transforms[_player_id] = {"position": center}
	_world.healths[_player_id] = {"current_hp": base_hp, "max_hp": base_hp, "invincible_time": 1.0, "invincible_timer": 0.0}
	_world.movements[_player_id] = {"speed": 180 + GameManager.stat_bonuses.get("speed", 0), "direction": Vector2.ZERO, "is_player": true}
	_world.collisions[_player_id] = {"radius": 14.0}

	var body_color = Color(0.0, 0.74, 0.83, 1.0)
	var dark = Color(0.0, 0.45, 0.55, 1.0)
	var white = Color(1.0, 1.0, 1.0, 0.95)
	var black = Color(0.0, 0.0, 0.0, 0.85)
	var ps = 28.0

	_world.sprites[_player_id] = {
		"shape": "composite",
		"color": Color.WHITE,
		"size": ps,
		"rotation": 0.0,
		"outline_radius": ps * 0.5,
		"sub_sprites": [
			{"shape": "circle", "offset": Vector2.ZERO, "color": body_color, "size": ps},
			{"shape": "circle", "offset": Vector2.ZERO, "color": dark, "size": ps * 0.55},
			{"shape": "circle", "offset": Vector2(-ps * 0.18, -ps * 0.16), "color": white, "size": ps * 0.28},
			{"shape": "circle", "offset": Vector2(ps * 0.18, -ps * 0.16), "color": white, "size": ps * 0.28},
			{"shape": "circle", "offset": Vector2(-ps * 0.18, -ps * 0.14), "color": black, "size": ps * 0.13},
			{"shape": "circle", "offset": Vector2(ps * 0.18, -ps * 0.14), "color": black, "size": ps * 0.13},
		]
	}
	_world.players[_player_id] = {}

func _spawn_weapon_entities() -> void:
	_destroy_all_weapon_entities()

	var weapon_ids = GameManager.owned_weapons
	var total = weapon_ids.size()

	for i in range(total):
		var weid = _world.create_entity()
		var weapon_data = WeaponFactory.create_weapon_component(weapon_ids[i])
		if weapon_data.is_empty():
			_world.destroy_entity(weid)
			continue
		weapon_data = WeaponFactory.apply_stat_bonuses(weapon_data, GameManager.stat_bonuses)

		var cfg = ConfigLoader.get_weapon(weapon_ids[i])
		var is_melee = cfg.get("melee", false)
		var color = Color.WHITE
		if not cfg.is_empty():
			color = _hex_to_color(cfg.get("bullet_color", "FFFFFF"))

		var size: float = 12.0
		if is_melee:
			size = 18.0
		var bright = Color(min(color.r * 1.3, 1.0), min(color.g * 1.3, 1.0), min(color.b * 1.3, 1.0), 1.0)
		var dark = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1.0)

		_world.transforms[weid] = {"position": _world.player_position}
		_world.sprites[weid] = {
			"shape": "composite",
			"color": Color.WHITE,
			"size": size,
			"rotation": 0.0,
			"outline_radius": size * 0.6,
			"sub_sprites": [
				{"shape": "barrel", "offset": Vector2.ZERO, "color": dark, "size": size + 2.0},
				{"shape": "barrel", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "rect", "offset": Vector2(-size * 0.05, size * 0.05), "color": bright, "size": size * 0.35},
			]
		}
		_world.weapons[weid] = weapon_data
		_world.weapon_entities[weid] = {"index": i, "total": total, "owner_id": _player_id}

func _destroy_all_weapon_entities() -> void:
	for weid in _world.weapon_entities.keys().duplicate():
		_world.destroy_entity(weid)

func _clear_all_enemies() -> void:
	for eid in _world.enemies.keys().duplicate():
		_world.destroy_entity(eid)
	for pid in _world.projectiles.keys().duplicate():
		_world.destroy_entity(pid)

func _process(delta: float) -> void:
	if _between_waves:
		return

	_world.update(delta)
	_update_hud()
	_update_camera()

	if _grass_layer.has_method("update_flatten_positions"):
		_grass_layer.update_flatten_positions(_world)

func _draw() -> void:
	pass

func _update_camera() -> void:
	if not _player_camera:
		return
	if _player_id != -1 and _world.transforms.has(_player_id):
		var target = _world.transforms[_player_id]["position"]
		_player_camera.global_position = _player_camera.global_position.lerp(target, 0.15)

func _on_enemy_killed(data: Dictionary) -> void:
	pass

func _on_player_died(_data = null) -> void:
	GameManager.set_state(GameManager.State.LOSE)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://maps/main_menu.tscn")

func _on_wave_cleared(_data = null) -> void:
	_clear_all_enemies()
	GameManager.current_wave += 1
	if GameManager.current_wave > 30:
		GameManager.set_state(GameManager.State.WIN)
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://maps/main_menu.tscn")
		return

	_between_waves = true
	EventBus.emit("show_shop")

func start_next_wave() -> void:
	_between_waves = false
	_refresh_player_stats()
	_spawn_weapon_entities()
	_spawn_system.start_wave(GameManager.current_wave)

func _refresh_player_stats() -> void:
	if _player_id == -1 or not _world.players.has(_player_id):
		return
	var base_hp = 50 + GameManager.stat_bonuses.get("max_hp", 0)
	var hp = _world.healths[_player_id]
	hp["max_hp"] = base_hp
	hp["current_hp"] = min(hp["current_hp"], base_hp)
	_world.movements[_player_id]["speed"] = 180 + GameManager.stat_bonuses.get("speed", 0)

func _on_player_heal(amount: int) -> void:
	if _player_id != -1 and _world.healths.has(_player_id):
		var hp = _world.healths[_player_id]
		hp["current_hp"] = min(hp["current_hp"] + amount, hp["max_hp"])

func _update_hud() -> void:
	if _player_id != -1 and _world.healths.has(_player_id):
		var hp = _world.healths[_player_id]
		_hud.get_node("HealthBar").max_value = hp["max_hp"]
		_hud.get_node("HealthBar").value = hp["current_hp"]
		_hud.get_node("HealthLabel").text = "HP: %d/%d" % [hp["current_hp"], hp["max_hp"]]

	_hud.get_node("WaveLabel").text = "波次: %d/30" % GameManager.current_wave
	_hud.get_node("CoinLabel").text = "金币: %d" % GameManager.coins
	_hud.get_node("ExpLabel").text = "Lv.%d 经验: %d/%d" % [GameManager.player_level, GameManager.player_exp, GameManager.exp_to_next]

	if GameManager.exp_to_next > 0:
		_hud.get_node("ExpBar").max_value = GameManager.exp_to_next
		_hud.get_node("ExpBar").value = GameManager.player_exp

	var wave_timer = _spawn_system._wave_timer
	_hud.get_node("TimerLabel").text = "剩余: %.0fs" % wave_timer

func _hex_to_color(hex: String) -> Color:
	if hex.length() < 6:
		return Color.WHITE
	var r = hex.substr(0, 2).hex_to_int() / 255.0
	var g = hex.substr(2, 2).hex_to_int() / 255.0
	var b = hex.substr(4, 2).hex_to_int() / 255.0
	return Color(r, g, b, 1.0)

func _setup_map_layers() -> void:
	var mud_shader = load("res://core/shaders/mud_ground.gdshader") as Shader
	if mud_shader:
		var mud_mat = ShaderMaterial.new()
		mud_mat.shader = mud_shader
		_mud_layer.material = mud_mat

	var grass_shader = load("res://core/shaders/grass.gdshader") as Shader
	if grass_shader:
		var grass_mat = ShaderMaterial.new()
		grass_mat.shader = grass_shader
		_grass_layer.material = grass_mat

func _setup_player_camera() -> void:
	_player_camera = Camera2D.new()
	_player_camera.enabled = true
	_player_camera.limit_left = 0
	_player_camera.limit_top = 0
	_player_camera.limit_right = int(_map_size.x)
	_player_camera.limit_bottom = int(_map_size.y)
	_player_camera.position_smoothing_enabled = true
	_player_camera.position_smoothing_speed = 10.0
	_player_camera.zoom = Vector2(1.0, 1.0)
	_player_camera.global_position = _map_size * 0.5
	_player_camera.make_current()
	add_child(_player_camera)

func _setup_walls() -> void:
	var wall_color = Color(0.15, 0.10, 0.04, 0.95)
	var wt = MapConfig.WALL_THICKNESS
	var mw = _map_size.x
	var mh = _map_size.y

	_create_wall_rect(Vector2(mw / 2.0, wt / 2.0), Vector2(mw, wt), wall_color)
	_create_wall_rect(Vector2(mw / 2.0, mh - wt / 2.0), Vector2(mw, wt), wall_color)
	_create_wall_rect(Vector2(wt / 2.0, mh / 2.0), Vector2(wt, mh), wall_color)
	_create_wall_rect(Vector2(mw - wt / 2.0, mh / 2.0), Vector2(wt, mh), wall_color)

func _create_wall_rect(pos: Vector2, size: Vector2, color: Color) -> void:
	var wall = StaticBody2D.new()
	wall.position = pos
	var col_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	col_shape.shape = rect
	wall.add_child(col_shape)
	add_child(wall)
