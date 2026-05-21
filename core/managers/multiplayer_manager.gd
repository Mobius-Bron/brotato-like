extends Node

signal player_joined(id: int)
signal player_left(id: int)
signal connection_done(success: bool)

var is_host: bool = false
var is_online: bool = false
var connected_players: Dictionary = {}

const MAX_PLAYERS := 4

func host_game(port: int = 8844) -> int:
	_disconnect_internal()

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("创建服务器失败 端口%d: %d" % [port, err])
		connection_done.emit(false)
		return err

	multiplayer.multiplayer_peer = peer
	is_host = true
	is_online = true

	_disconnect_signals()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	connected_players[1] = {"id": 1, "name": "房主"}
	print("Hosting game on port %d" % port)
	connection_done.emit(true)
	return OK

func join_game(host_ip: String, port: int = 8844) -> int:
	_disconnect_internal()

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(host_ip, port)
	if err != OK:
		push_error("连接失败 %s:%d - %d" % [host_ip, port, err])
		connection_done.emit(false)
		return err

	multiplayer.multiplayer_peer = peer
	is_host = false

	_disconnect_signals()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	print("正在连接 %s:%d..." % [host_ip, port])
	return OK

func disconnect_game() -> void:
	_disconnect_internal()
	_disconnect_signals()

func _disconnect_internal() -> void:
	if multiplayer.multiplayer_peer:
		var p = multiplayer.multiplayer_peer
		if p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			p.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	is_online = false
	connected_players.clear()

func _disconnect_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)

func _on_peer_connected(id: int) -> void:
	connected_players[id] = {"id": id, "name": "玩家%d" % id}
	player_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	connected_players.erase(id)
	player_left.emit(id)

func _on_connected_to_server() -> void:
	is_online = true
	connection_done.emit(true)

func _on_connection_failed() -> void:
	is_online = false
	_disconnect_internal()
	connection_done.emit(false)

func get_player_count() -> int:
	return connected_players.size()
