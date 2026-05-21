extends Node2D

var _world: ECSWorld
var _render_system: RenderSystem
var _movement_system: MovementSystem
var _orbit_system: WeaponOrbitSystem
var _weapon_system: WeaponSystem
var _collision_system: CollisionSystem
var _health_system: HealthSystem
var _spawn_system: SpawnSystem
var _lifetime_system: LifetimeSystem
var _enemy_factory: EnemyFactory
var _projectile_factory: ProjectileFactory
var _player_id: int = -1
var _between_waves: bool = false
var _paused: bool = false
var _map_size: Vector2
var _player_camera: Camera2D
var _player_dead: bool = false

@onready var _mud_layer: Node2D = $MudLayer
@onready var _render_layer: Node2D = $RenderLayer
@onready var _hud: CanvasLayer = $HUD

func _ready() -> void:
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
	_lifetime_system = LifetimeSystem.new()
	_render_system = RenderSystem.new(_render_layer)
	_render_layer.world = _world
	_render_layer.render_system = _render_system

	_world.add_system(_movement_system)
	_world.add_system(_orbit_system)
	_world.add_system(_weapon_system)
	_world.add_system(_collision_system)
	_world.add_system(_health_system)
	_world.add_system(_spawn_system)
	_world.add_system(_lifetime_system)
	_world.add_system(_render_system)

	_setup_connections()

	var char_skin = _get_character_skin(GameManager.selected_character)
	_create_player(char_skin)
	_spawn_weapon_entities()
	_spawn_system.start_wave(GameManager.current_wave)

func _create_player(skin: Dictionary = {}) -> void:
	_player_id = _world.create_entity()
	var center = _map_size * 0.5

	var base_hp = 50 + GameManager.stat_bonuses.get("max_hp", 0)
	_world.transforms[_player_id] = {"position": center}
	_world.healths[_player_id] = {"current_hp": base_hp, "max_hp": base_hp, "invincible_time": 0.8, "invincible_timer": 0.0}
	_world.movements[_player_id] = {"speed": 180 + GameManager.stat_bonuses.get("speed", 0), "direction": Vector2.ZERO, "is_player": true}
	_world.collisions[_player_id] = {"radius": 14.0}

	var body_color = skin.get("body", Color(0.0, 0.74, 0.83, 1.0))
	var dark = skin.get("inner", Color(0.0, 0.45, 0.55, 1.0))
	var white = skin.get("eyes", Color(1.0, 1.0, 1.0, 0.95))
	var black = Color(0.0, 0.0, 0.0, 0.85)
	var ps = skin.get("size", 28.0)

	_world.sprites[_player_id] = {
		"shape": "composite",
		"color": Color.WHITE,
		"size": ps,
		"rotation": 0.0,
		"outline_radius": ps * 0.5,
		"height": 1.3,
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
	_player_dead = false

func _setup_connections() -> void:
	EventBus.on("enemy_killed", _on_enemy_killed)
	EventBus.on("player_died", _on_player_died)
	EventBus.on("wave_cleared", _on_wave_cleared)
	EventBus.on("player_heal", _on_player_heal)
	EventBus.on("perks_done", _on_perks_done)

func _exit_tree() -> void:
	EventBus.off("enemy_killed", _on_enemy_killed)
	EventBus.off("player_died", _on_player_died)
	EventBus.off("wave_cleared", _on_wave_cleared)
	EventBus.off("player_heal", _on_player_heal)
	EventBus.off("perks_done", _on_perks_done)

func _get_character_skin(char_id: String) -> Dictionary:
	match char_id:
		"berserker":
			return {"body": Color(0.85, 0.22, 0.15, 1.0), "inner": Color(0.55, 0.08, 0.05, 1.0), "eyes": Color(1.0, 0.9, 0.2, 0.95), "size": 30.0}
		"ranger":
			return {"body": Color(0.12, 0.45, 0.22, 1.0), "inner": Color(0.05, 0.30, 0.10, 1.0), "eyes": Color(1.0, 1.0, 1.0, 0.95), "size": 26.0}
		"shotgunner":
			return {"body": Color(0.70, 0.45, 0.12, 1.0), "inner": Color(0.40, 0.22, 0.05, 1.0), "eyes": Color(1.0, 0.8, 0.0, 0.95), "size": 28.0}
		"juggernaut":
			return {"body": Color(0.25, 0.28, 0.35, 1.0), "inner": Color(0.10, 0.12, 0.18, 1.0), "eyes": Color(1.0, 0.4, 0.2, 0.95), "size": 34.0}
		"shadow":
			return {"body": Color(0.18, 0.08, 0.28, 1.0), "inner": Color(0.08, 0.02, 0.12, 1.0), "eyes": Color(0.9, 0.1, 0.8, 0.95), "size": 24.0}
		"engineer":
			return {"body": Color(0.90, 0.60, 0.12, 1.0), "inner": Color(0.60, 0.35, 0.05, 1.0), "eyes": Color(0.0, 0.6, 1.0, 0.95), "size": 28.0}
		"plague_doctor":
			return {"body": Color(0.15, 0.42, 0.20, 1.0), "inner": Color(0.05, 0.25, 0.10, 1.0), "eyes": Color(0.9, 0.9, 0.0, 0.95), "size": 27.0}
		"merchant":
			return {"body": Color(0.65, 0.45, 0.15, 1.0), "inner": Color(0.40, 0.25, 0.05, 1.0), "eyes": Color(1.0, 0.85, 0.0, 0.95), "size": 25.0}
		"gladiator":
			return {"body": Color(0.75, 0.30, 0.08, 1.0), "inner": Color(0.45, 0.12, 0.04, 1.0), "eyes": Color(1.0, 1.0, 1.0, 0.95), "size": 30.0}
		"elementalist":
			return {"body": Color(0.20, 0.30, 0.70, 1.0), "inner": Color(0.08, 0.12, 0.40, 1.0), "eyes": Color(0.3, 1.0, 1.0, 0.95), "size": 26.0}
		"survivor":
			return {"body": Color(0.30, 0.35, 0.25, 1.0), "inner": Color(0.12, 0.15, 0.08, 1.0), "eyes": Color(0.8, 0.8, 0.8, 0.95), "size": 27.0}
		"lucky":
			return {"body": Color(0.90, 0.75, 0.15, 1.0), "inner": Color(0.60, 0.50, 0.05, 1.0), "eyes": Color(0.0, 0.9, 0.0, 0.95), "size": 26.0}
		"cannoneer":
			return {"body": Color(0.55, 0.20, 0.08, 1.0), "inner": Color(0.30, 0.08, 0.02, 1.0), "eyes": Color(1.0, 0.6, 0.0, 0.95), "size": 32.0}
		"generalist":
			return {"body": Color(0.40, 0.50, 0.60, 1.0), "inner": Color(0.20, 0.28, 0.35, 1.0), "eyes": Color(0.8, 0.9, 1.0, 0.95), "size": 26.0}
		"swordsman":
			return {"body": Color(0.30, 0.50, 0.70, 1.0), "inner": Color(0.12, 0.28, 0.45, 1.0), "eyes": Color(1.0, 1.0, 1.0, 0.95), "size": 28.0}
		_:
			return {"body": Color(0.0, 0.74, 0.83, 1.0), "inner": Color(0.0, 0.45, 0.55, 1.0), "eyes": Color(1.0, 1.0, 1.0, 0.95), "size": 28.0}

func _spawn_weapon_entities() -> void:
	_destroy_all_weapon_entities()

	var weapon_ids = GameManager.owned_weapons
	var total = weapon_ids.size()
	var max_slots = GameManager.get_weapon_slots()
	var effective_count = min(total, max_slots)

	for i in range(effective_count):
		var weid = _world.create_entity()
		var weapon_data = WeaponFactory.create_weapon_component(weapon_ids[i])
		if weapon_data.is_empty():
			_world.destroy_entity(weid)
			continue
		weapon_data = WeaponFactory.apply_stat_bonuses(weapon_data, GameManager.stat_bonuses)
		var slot_mult = GameManager.weapon_slot_damage_mult()
		weapon_data["damage"] = int(weapon_data["damage"] * slot_mult)

		var cfg = ConfigLoader.get_weapon(weapon_ids[i])
		var color = Color.WHITE
		if not cfg.is_empty():
			color = _hex_to_color(cfg.get("bullet_color", "FFFFFF"))

		var size: float = 14.0
		var subs = _make_weapon_subs(cfg, color, size)

		_world.transforms[weid] = {"position": _world.player_position}
		_world.sprites[weid] = {
			"shape": "composite",
			"color": Color.WHITE,
			"size": size,
			"rotation": 0.0,
			"outline_radius": size * 0.6,
			"height": 0.9,
			"sub_sprites": subs
		}
		_world.weapons[weid] = weapon_data
		_world.weapon_entities[weid] = {"index": i, "total": effective_count, "owner_id": _player_id}

func _make_weapon_subs(cfg: Dictionary, color: Color, size: float) -> Array:
	var bright = Color(min(color.r * 1.3, 1.0), min(color.g * 1.3, 1.0), min(color.b * 1.3, 1.0), 1.0)
	var dark = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1.0)
	var is_melee = cfg.get("melee", false)
	var melee_type = cfg.get("melee_type", "slash")
	var ecosys = cfg.get("ecosystem", "")

	if is_melee:
		match melee_type:
			"thrust":
				return [
					{"shape": "rect", "offset": Vector2.ZERO, "color": dark, "size": size + 3.0},
					{"shape": "rect", "offset": Vector2.ZERO, "color": color, "size": size},
					{"shape": "triangle", "offset": Vector2(size * 0.35, 0), "color": bright, "size": size * 0.5, "rotation": 0},
				]
			"blunt":
				return [
					{"shape": "circle", "offset": Vector2.ZERO, "color": dark, "size": size + 3.0},
					{"shape": "circle", "offset": Vector2.ZERO, "color": color, "size": size},
					{"shape": "hexagon", "offset": Vector2.ZERO, "color": Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.8), "size": size * 0.65},
					{"shape": "rect", "offset": Vector2(-size * 0.45, 0), "color": bright, "size": size * 0.18},
				]
			_:
				return [
					{"shape": "rect", "offset": Vector2.ZERO, "color": dark, "size": size + 3.0},
					{"shape": "rect", "offset": Vector2.ZERO, "color": color, "size": size},
					{"shape": "rect", "offset": Vector2.ZERO, "color": bright, "size": size * 0.22},
				]

	match ecosys:
		"shotgun":
			return [
				{"shape": "circle", "offset": Vector2.ZERO, "color": dark, "size": size + 2.0},
				{"shape": "circle", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "circle", "offset": Vector2.ZERO, "color": bright, "size": size * 0.35},
			]
		"sniper":
			return [
				{"shape": "rect", "offset": Vector2.ZERO, "color": dark, "size": size + 3.0},
				{"shape": "rect", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "circle", "offset": Vector2(size * 0.35, 0), "color": bright, "size": size * 0.28},
			]
		"explosive":
			return [
				{"shape": "circle", "offset": Vector2.ZERO, "color": dark, "size": size + 4.0},
				{"shape": "circle", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "triangle", "offset": Vector2(0, -size * 0.1), "color": Color(1, 0.8, 0.2, 0.7), "size": size * 0.3},
			]
		"magic":
			return [
				{"shape": "diamond", "offset": Vector2.ZERO, "color": dark, "size": size + 3.0},
				{"shape": "diamond", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "diamond", "offset": Vector2.ZERO, "color": bright, "size": size * 0.3},
			]
		_:
			return [
				{"shape": "barrel", "offset": Vector2.ZERO, "color": dark, "size": size + 2.0},
				{"shape": "barrel", "offset": Vector2.ZERO, "color": color, "size": size},
				{"shape": "rect", "offset": Vector2(-size * 0.05, size * 0.05), "color": bright, "size": size * 0.35},
			]

func _destroy_all_weapon_entities() -> void:
	for weid in _world.weapon_entities.keys().duplicate():
		_world.destroy_entity(weid)

func _clear_all_enemies() -> void:
	if not _world:
		return
	for eid in _world.enemies.keys().duplicate():
		_world.destroy_entity(eid)
	for pid in _world.projectiles.keys().duplicate():
		_world.destroy_entity(pid)

func _process(delta: float) -> void:
	if not _world:
		return
	if _between_waves or _paused:
		return
	if GameManager.current_state == GameManager.State.PERK_SELECT:
		return

	_world.update(delta)
	_collect_xp_orbs(delta)
	_update_hud()
	_update_camera()

func _collect_xp_orbs(_delta: float) -> void:
	if _player_dead or not _world.transforms.has(_player_id):
		return
	var player_pos = _world.transforms[_player_id]["position"]
	var pickup_radius = 40.0 + GameManager.stat_bonuses.get("pickup_radius", 0)

	for xid in _world.xp_orbs.keys().duplicate():
		if not _world.transforms.has(xid):
			continue
		var orb_pos = _world.transforms[xid]["position"]
		var dist = player_pos.distance_to(orb_pos)
		if dist < pickup_radius:
			var xp_val = _world.xp_orbs[xid]["xp_value"]
			GameManager.add_exp(xp_val)
			_world.destroy_entity(xid)

func _on_perks_done(_data = null) -> void:
	_paused = false
	if _between_waves:
		_advance_wave_or_shop()

func _update_camera() -> void:
	if not _player_camera:
		return
	if _player_id != -1 and _world.transforms.has(_player_id):
		var target = _world.transforms[_player_id]["position"]
		_player_camera.global_position = _player_camera.global_position.lerp(target, 0.15)

func _on_enemy_killed(data: Dictionary) -> void:
	if not _world:
		return
	GameManager.kills += 1
	var pos = data.get("pos", _world.player_position)
	var xp_val = data.get("xp_drop", 5)
	_create_xp_orb(pos, xp_val)

func _create_xp_orb(pos: Vector2, value: int) -> void:
	var eid = _world.create_entity()
	var spread = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	_world.transforms[eid] = {"position": pos + spread}
	_world.sprites[eid] = {
		"shape": "composite",
		"color": Color(0.3, 1.0, 0.3, 1.0),
		"size": 8.0,
		"rotation": 0.0,
		"outline_radius": 5.0,
		"height": 0.6,
		"sub_sprites": [
			{"shape": "diamond", "offset": Vector2.ZERO, "color": Color(0.2, 0.9, 0.2, 0.9), "size": 8.0},
			{"shape": "diamond", "offset": Vector2.ZERO, "color": Color(0.6, 1.0, 0.6, 0.7), "size": 5.0},
		]
	}
	_world.lifetimes[eid] = {"remaining_time": 45.0}
	_world.xp_orbs[eid] = {"xp_value": value}

func _on_player_died(_data = null) -> void:
	_end_game(false)

func _end_game(won: bool) -> void:
	GameManager.set_state(GameManager.State.LOSE if not won else GameManager.State.WIN)
	EventBus.emit("game_over", {
		"won": won,
		"wave": GameManager.current_wave,
		"coins": GameManager.coins,
		"level": GameManager.player_level,
		"kills": GameManager.kills
	})

func _on_wave_cleared(_data = null) -> void:
	_clear_all_enemies()

	if GameManager.pending_levels > 0:
		_between_waves = true
		_paused = true
		EventBus.emit("show_perks")
		return

	_advance_wave_or_shop()

func _advance_wave_or_shop() -> void:
	GameManager.current_wave += 1
	if GameManager.current_wave > 20:
		_end_game(true)
		return

	_between_waves = true
	EventBus.emit("show_shop")

func start_next_wave() -> void:
	if not _world:
		return
	_between_waves = false
	_refresh_player_stats()
	_spawn_weapon_entities()
	_spawn_system.start_wave(GameManager.current_wave)

func _refresh_player_stats() -> void:
	if not _world.players.has(_player_id):
		return
	var base_hp = 50 + GameManager.stat_bonuses.get("max_hp", 0)
	var hp = _world.healths[_player_id]
	hp["max_hp"] = base_hp
	hp["current_hp"] = min(hp["current_hp"], base_hp)
	_world.movements[_player_id]["speed"] = 180 + GameManager.stat_bonuses.get("speed", 0)

func _on_player_heal(amount: int) -> void:
	if not _world or not _world.healths.has(_player_id):
		return
	var hp = _world.healths[_player_id]
	hp["current_hp"] = min(hp["current_hp"] + amount, hp["max_hp"])

func _update_hud() -> void:
	if _player_id != -1 and _world.healths.has(_player_id):
		var hp = _world.healths[_player_id]
		_hud.get_node("HealthBar").max_value = hp["max_hp"]
		_hud.get_node("HealthBar").value = hp["current_hp"]
		_hud.get_node("HealthLabel").text = "HP: %d/%d" % [hp["current_hp"], hp["max_hp"]]

	_hud.get_node("WaveLabel").text = "波次: %d/20" % GameManager.current_wave
	_hud.get_node("CoinLabel").text = "金币: %d" % GameManager.coins
	_hud.get_node("ExpLabel").text = "Lv.%d 经验: %d/%d" % [GameManager.player_level, GameManager.player_exp, GameManager.exp_to_next]

	if GameManager.exp_to_next > 0:
		_hud.get_node("ExpBar").max_value = GameManager.exp_to_next
		_hud.get_node("ExpBar").value = GameManager.player_exp

	if _spawn_system:
		var wt = _spawn_system._wave_timer
		_hud.get_node("TimerLabel").text = "剩余: %.0fs" % wt

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
