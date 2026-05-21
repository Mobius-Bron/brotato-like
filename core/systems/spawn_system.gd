class_name SpawnSystem
extends RefCounted

var _enemy_factory: EnemyFactory
var _wave_timer: float = 0.0
var _spawn_timer: float = 0.0
var _spawn_interval: float = 1.5
var _spawn_pool: Array = []
var _total_weight: int = 0
var _wave_active: bool = false
var _current_wave: int = 0

const ELITE_IDS := [["elite_warrior", "elite_charger", "elite_marksman"], ["elite_golem", "elite_warlock"], ["elite_charger", "elite_golem", "elite_warlock"]]

func _init(enemy_factory: EnemyFactory) -> void:
	_enemy_factory = enemy_factory

func start_wave(wave_number: int) -> void:
	var cfg = ConfigLoader.get_wave(wave_number)
	if cfg.is_empty():
		return

	_wave_timer = cfg.get("duration", 30.0)
	_spawn_interval = cfg.get("spawn_interval", 1.5)
	_spawn_timer = 0.0
	_wave_active = true
	_current_wave = wave_number

	_enemy_factory.set_wave(wave_number)
	_parse_enemy_pool(cfg.get("enemy_groups", ""))

	if _current_wave >= 5 and _current_wave % 5 == 0:
		var boss_id = ["boss_tank","boss_assassin","boss_overlord","boss_wurm","boss_dragon","boss_colossus","boss_hydra","boss_phantom","boss_guardian","boss_summoner","boss_lich"][(_current_wave / 5 - 1) % 11]
		_enemy_factory.create_enemy(boss_id)
		EventBus.emit("boss_spawned", boss_id)

func _parse_enemy_pool(groups_str: String) -> void:
	_spawn_pool.clear()
	_total_weight = 0
	if groups_str == "":
		return

	var groups = groups_str.split(",")
	for g in groups:
		var parts = g.split(":")
		if parts.size() != 2:
			continue
		var enemy_id = parts[0].strip_edges()
		var weight = int(parts[1])
		_spawn_pool.append({"enemy_id": enemy_id, "weight": weight})
		_total_weight += weight

func _pick_enemy() -> String:
	if _current_wave >= 6:
		var elite_chance = min(0.08 + (_current_wave - 6) * 0.025, 0.35)
		if randf() < elite_chance:
			return _pick_elite()

	if _spawn_pool.size() == 0:
		return "melee_grunt"
	if _spawn_pool.size() == 1:
		return _spawn_pool[0]["enemy_id"]
	var roll = randi() % _total_weight
	var cumulative = 0
	for entry in _spawn_pool:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry["enemy_id"]
	return _spawn_pool[0]["enemy_id"]

func _pick_elite() -> String:
	var tier = min((_current_wave - 6) / 4, ELITE_IDS.size() - 1)
	var pool = ELITE_IDS[tier]
	return pool[randi() % pool.size()]

func _get_scaled_interval() -> float:
	var base = _spawn_interval
	var wave_factor = 1.0 - (_current_wave - 1) * 0.015
	return maxf(base * wave_factor, 0.35)

func update(world: ECSWorld, delta: float) -> void:
	if not _wave_active:
		return

	_wave_timer -= delta
	if _wave_timer <= 0:
		_wave_active = false
		EventBus.emit("wave_cleared")
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0:
		var enemy_id = _pick_enemy()
		var player_pos = world.player_position
		var spawn_pos = _enemy_factory.random_map_position(player_pos)
		_enemy_factory.create_enemy(enemy_id, spawn_pos)
		_spawn_timer = _get_scaled_interval() * randf_range(0.7, 1.3)

func is_wave_active() -> bool:
	return _wave_active

func is_wave_done() -> bool:
	return not _wave_active
