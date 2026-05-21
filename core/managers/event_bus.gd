extends Node

var _listeners := {}

func on(event_name: String, callback: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	_listeners[event_name].append(callback)

func off(event_name: String, callback: Callable) -> void:
	if _listeners.has(event_name):
		_listeners[event_name].erase(callback)

func emit(event_name: String, data = null) -> void:
	if not _listeners.has(event_name):
		return
	for cb in _listeners[event_name]:
		cb.call(data)
