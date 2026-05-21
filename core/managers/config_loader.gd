extends Node

var enemies: Array = []
var weapons: Array = []
var items: Array = []
var waves: Array = []
var _loaded := false

func _ready() -> void:
	load_all()

func load_all() -> void:
	if _loaded:
		return
	enemies = _load_json("res://data/enemies.json")
	weapons = _load_json("res://data/weapons.json")
	items = _load_json("res://data/items.json")
	waves = _load_json("res://data/waves.json")
	_loaded = true

func _load_json(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("ConfigLoader: file not found: " + path)
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ConfigLoader: cannot open: " + path)
		return []
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("ConfigLoader: JSON parse error in " + path)
		return []
	var data = json.get_data()
	if data is Array:
		return data
	return []

func get_enemy(id: String) -> Dictionary:
	for e in enemies:
		if e.get("id", "") == id:
			return e
	return {}

func get_weapon(id: String) -> Dictionary:
	for w in weapons:
		if w.get("id", "") == id:
			return w
	return {}

func get_item(id: String) -> Dictionary:
	for i in items:
		if i.get("id", "") == id:
			return i
	return {}

func get_wave(num: int) -> Dictionary:
	for w in waves:
		if w.get("wave_number", -1) == num:
			return w
	return {}
