class_name SpawnSystem
extends RefCounted

var _enemy_factory: EnemyFactory
var _wave_timer: float = 0.0
var _spawn_timer: float = 0.0
var _pending_enemies: Array = []
var _waves_cleared: int = 0
var _wave_active: bool = false

func _init(enemy_factory: EnemyFactory) -> void:
	_enemy_factory = enemy_factory

func start_wave(wave_number: int) -> void:
	var cfg = ConfigLoader.get_wave(wave_number)
	if cfg.is_empty():
		return

	_wave_timer = cfg.get("duration", 30.0)
	_spawn_timer = 0.0
	_wave_active = true

	_parse_enemy_groups(cfg.get("enemy_groups", ""), cfg.get("spawn_interval", 2.0))

	if cfg.get("is_boss_wave", false):
		var boss_id = cfg.get("boss_id", "boss_tank")
		_enemy_factory.create_enemy(boss_id)
		EventBus.emit("boss_spawned", boss_id)

func _parse_enemy_groups(groups_str: String, interval: float) -> void:
	_pending_enemies.clear()
	if groups_str == "":
		return

	var groups = groups_str.split(",")
	for g in groups:
		var parts = g.split(":")
		if parts.size() != 2:
			continue
		var enemy_id = parts[0].strip_edges()
		var count = int(parts[1])
		for i in range(count):
			var delay = randf_range(0, interval) * i
			_pending_enemies.append({"enemy_id": enemy_id, "delay": delay})

func update(world: ECSWorld, delta: float) -> void:
	if not _wave_active:
		return

	_wave_timer -= delta
	if _wave_timer <= 0:
		_wave_active = false
		_waves_cleared += 1
		EventBus.emit("wave_cleared")
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0:
		if _pending_enemies.size() > 0:
			var info = _pending_enemies.pop_front()
			_enemy_factory.create_enemy(info["enemy_id"])
			_spawn_timer = randf_range(0.5, 1.5)
		else:
			_spawn_timer = 0.5

func is_wave_active() -> bool:
	return _wave_active

func is_wave_done() -> bool:
	return not _wave_active and _pending_enemies.size() == 0
