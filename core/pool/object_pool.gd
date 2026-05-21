class_name ObjectPool
extends RefCounted

var _pool: Array = []
var _factory: Callable
var _reset_fn: Callable
var _max_size: int

func _init(factory: Callable, reset_fn: Callable, max_size: int = 200) -> void:
	_factory = factory
	_reset_fn = reset_fn
	_max_size = max_size

func acquire():
	if _pool.size() > 0:
		var obj = _pool.pop_back()
		return obj
	return _factory.call()

func release(obj) -> void:
	_reset_fn.call(obj)
	if _pool.size() < _max_size:
		_pool.append(obj)

func clear() -> void:
	_pool.clear()
