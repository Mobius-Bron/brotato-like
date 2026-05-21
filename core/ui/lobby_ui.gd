extends Control

@onready var _setup_panel: Panel = $SetupPanel
@onready var _ip_input: LineEdit = $SetupPanel/VBoxContainer/IPInput
@onready var _port_input: LineEdit = $SetupPanel/VBoxContainer/PortInput
@onready var _host_btn: Button = $SetupPanel/VBoxContainer/HostButton
@onready var _join_btn: Button = $SetupPanel/VBoxContainer/JoinButton
@onready var _back_btn: Button = $SetupPanel/VBoxContainer/BackButton

@onready var _waiting_panel: Panel = $WaitingPanel
@onready var _room_label: Label = $WaitingPanel/VBoxContainer/RoomLabel
@onready var _player_list: VBoxContainer = $WaitingPanel/VBoxContainer/PlayerList
@onready var _start_btn: Button = $WaitingPanel/VBoxContainer/StartButton
@onready var _wait_status: Label = $WaitingPanel/VBoxContainer/WaitStatus
@onready var _leave_btn: Button = $WaitingPanel/VBoxContainer/LeaveButton

var _current_port: int = 8844

func _ready() -> void:
	_host_btn.pressed.connect(_on_host_pressed)
	_join_btn.pressed.connect(_on_join_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_start_btn.pressed.connect(_on_start_game)
	_leave_btn.pressed.connect(_on_leave_room)
	MultiplayerManager.player_joined.connect(_on_player_joined)
	MultiplayerManager.player_left.connect(_on_player_left)
	MultiplayerManager.connection_done.connect(_on_connection_done)

	_setup_panel.show()
	_waiting_panel.hide()
	_start_btn.hide()

func _get_port() -> int:
	var txt = _port_input.text.strip_edges()
	if txt.is_valid_int():
		var p = txt.to_int()
		if p > 0 and p < 65536:
			return p
	return 8844

func _on_host_pressed() -> void:
	_current_port = _get_port()
	_host_btn.disabled = true
	_join_btn.disabled = true
	MultiplayerManager.host_game(_current_port)

func _on_join_pressed() -> void:
	var ip = _ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	_current_port = _get_port()
	_host_btn.disabled = true
	_join_btn.disabled = true
	MultiplayerManager.join_game(ip, _current_port)

func _on_connection_done(success: bool) -> void:
	if success:
		_show_waiting_room()
	else:
		_host_btn.disabled = false
		_join_btn.disabled = false

func _show_waiting_room() -> void:
	_setup_panel.hide()
	_waiting_panel.show()

	if MultiplayerManager.is_host:
		_room_label.text = "房间: 端口 %d" % _current_port
		_wait_status.text = "等待玩家加入... (当前 %d/%d 人)" % [MultiplayerManager.get_player_count(), MultiplayerManager.MAX_PLAYERS]
		_start_btn.show()
		_refresh_player_list()
	else:
		_room_label.text = "已连接到主机"
		_wait_status.text = "等待主机开始游戏..."
		_start_btn.hide()

func _on_player_joined(id: int) -> void:
	if MultiplayerManager.is_host:
		_wait_status.text = "等待玩家加入... (当前 %d/%d 人)" % [MultiplayerManager.get_player_count(), MultiplayerManager.MAX_PLAYERS]
	_refresh_player_list()

func _on_player_left(id: int) -> void:
	if MultiplayerManager.is_host:
		_wait_status.text = "等待玩家加入... (当前 %d/%d 人)" % [MultiplayerManager.get_player_count(), MultiplayerManager.MAX_PLAYERS]
	_refresh_player_list()

func _refresh_player_list() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	for pid in MultiplayerManager.connected_players:
		var info = MultiplayerManager.connected_players[pid]
		var label = Label.new()
		label.text = "  %s (ID: %d)" % [info.get("name", "玩家"), pid]
		label.add_theme_font_size_override("font_size", 15)
		_player_list.add_child(label)

func _on_start_game() -> void:
	_start_btn.disabled = true
	_wait_status.text = "正在开始游戏..."
	rpc("_rpc_all_to_char_select")
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://maps/character_select.tscn")

@rpc("authority", "call_remote", "reliable")
func _rpc_all_to_char_select() -> void:
	get_tree().change_scene_to_file("res://maps/character_select.tscn")

func _on_leave_room() -> void:
	MultiplayerManager.disconnect_game()
	_setup_panel.show()
	_waiting_panel.hide()
	_host_btn.disabled = false
	_join_btn.disabled = false

func _on_back_pressed() -> void:
	MultiplayerManager.disconnect_game()
	get_tree().change_scene_to_file("res://maps/main_menu.tscn")
