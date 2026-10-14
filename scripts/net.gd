extends Node
## 联机（自动加载）：一人创建房间（服务器+玩家），其他人输入 IP 加入。
## 同步内容：玩家名单（名字/帽子/颜色）、位置与走路目标、钓鱼姿势、聊天、送礼。
## 农场、背包、摩尔豆仍然各自保存在本地。

signal status_changed(text: String)
signal roster_changed
signal peer_moved(id: int, pos: Vector2, target: Vector2, fishing: bool)
signal peer_chat(id: int, text: String)
signal gift_received(id: int, beans: int)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 16

var players: Dictionary = {}  # peer_id -> {"name", "hat", "color"}
var status := "单机模式"


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer is ENetMultiplayerPeer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func my_id() -> int:
	return multiplayer.get_unique_id()


func my_info() -> Dictionary:
	return {"name": GameState.player_name, "hat": GameState.hat, "color": GameState.body_color}


func player_name(id: int) -> String:
	if players.has(id):
		return str(players[id]["name"])
	return "某只摩尔"


func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)


# ---------- 创建 / 加入 / 离开 ----------

func host(port: int) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_PLAYERS) != OK:
		return "创建房间失败，端口 %d 可能已被占用" % port
	multiplayer.multiplayer_peer = peer
	players = {1: my_info()}
	_set_status("房间已创建（端口 %d），等待小伙伴加入" % port)
	roster_changed.emit()
	return ""


func join(ip: String, port: int) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, port) != OK:
		return "无法连接 %s:%d" % [ip, port]
	multiplayer.multiplayer_peer = peer
	_set_status("正在连接 %s:%d……" % [ip, port])
	return ""


func leave() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	roster_changed.emit()
	_set_status("单机模式")


func _on_connected() -> void:
	_set_status("已连接到房间")
	register.rpc_id(1, my_info())


func _on_failed() -> void:
	leave()
	_set_status("连接失败，请检查 IP、端口和防火墙")
	GameState.toast.emit("连接失败")


func _on_server_gone() -> void:
	leave()
	GameState.toast.emit("房主关闭了房间，已回到单机模式")


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.has(id):
		players.erase(id)
		_broadcast_roster()


# ---------- 名单 ----------

func _clean(info) -> Dictionary:
	if typeof(info) != TYPE_DICTIONARY:
		info = {}
	var n := str(info.get("name", "摩尔")).strip_edges().left(10)
	var h := str(info.get("hat", "none"))
	var c := str(info.get("color", "946644"))
	return {
		"name": n if n != "" else "摩尔",
		"hat": h if GameState.HATS.has(h) else "none",
		"color": c if Color.html_is_valid(c) else "946644",
	}


func _broadcast_roster() -> void:
	sync_roster.rpc(players)
	roster_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func register(info) -> void:
	if not multiplayer.is_server():
		return
	players[multiplayer.get_remote_sender_id()] = _clean(info)
	_broadcast_roster()


@rpc("authority", "call_remote", "reliable")
func sync_roster(p: Dictionary) -> void:
	players = {}
	for id in p:
		players[int(id)] = _clean(p[id])
	roster_changed.emit()


func send_info() -> void:
	if not is_online():
		return
	players[my_id()] = my_info()
	update_info.rpc(my_info())
	roster_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func update_info(info) -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) or multiplayer.is_server():
		players[id] = _clean(info)
		roster_changed.emit()


# ---------- 移动 / 聊天 / 送礼 ----------

func send_move(pos: Vector2, target: Vector2, fishing: bool) -> void:
	if is_online():
		move.rpc(pos, target, fishing)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func move(pos: Vector2, target: Vector2, fishing: bool) -> void:
	peer_moved.emit(multiplayer.get_remote_sender_id(), pos, target, fishing)


func send_chat(text: String) -> void:
	if is_online():
		chat.rpc(text)


@rpc("any_peer", "call_remote", "reliable")
func chat(text: String) -> void:
	peer_chat.emit(multiplayer.get_remote_sender_id(), str(text).left(40))


func send_gift(id: int, beans: int) -> void:
	if is_online():
		gift.rpc_id(id, beans)


@rpc("any_peer", "call_remote", "reliable")
func gift(beans: int) -> void:
	gift_received.emit(multiplayer.get_remote_sender_id(), clampi(beans, 0, 1000))
