extends Node
## 联机同步（main.gd 的一部分）：在线名单 → 远程玩家和他们的拉姆、移动 / 聊天 / 送礼、串门时的农田同步、一起跳舞。

var main  # main.gd


func setup() -> void:
	# 联机
	Net.roster_changed.connect(_on_roster_changed)
	Net.peer_moved.connect(_on_peer_moved)
	Net.peer_chat.connect(_on_peer_chat)
	Net.gift_received.connect(_on_gift)
	Net.item_received.connect(_on_item_gift)
	Net.peer_emote.connect(_on_peer_emote)
	if not GameState.hat_changed.is_connected(Net.send_info):
		GameState.hat_changed.connect(Net.send_info)
	var sync := Timer.new()
	sync.wait_time = 0.1
	sync.autostart = true
	sync.timeout.connect(func():
		Net.send_move(main.player.position, main.player.target if main.player.moving else main.player.position, main.player.fishing, my_farm()))
	add_child(sync)
	_on_roster_changed()

	# 串门
	Net.visit_changed.connect(_on_visit_changed)
	Net.farm_visitor_joined.connect(_on_farm_visitor)
	Net.farm_received.connect(_on_farm_received)
	Net.farm_action_requested.connect(_on_farm_action_requested)
	Net.farm_action_result.connect(_on_farm_action_result)
	var farm_sync := Timer.new()
	farm_sync.wait_time = 1.0
	farm_sync.autostart = true
	farm_sync.timeout.connect(func():
		if not Net.visitors.is_empty():
			Net.push_farm(farm_states()))
	add_child(farm_sync)


## 我现在所在的是谁家的农场（串门时是主人的 id，否则是自己的 id）
func my_farm() -> int:
	return Net.visiting if Net.visiting != 0 else Net.my_id()


func farm_states() -> Dictionary:
	var out := []
	for p in main.plots:
		out.append(p.get_state())
	return {"plots": out, "home": GameState.home}


func _on_visit_changed() -> void:
	if Net.visiting == 0:
		for p in main.plots:
			p.clear_remote()
		main.farm_sign.text = "开心农场"
		main.home_sign.text = "我的小院"
		main._build_home(GameState.home, false)
	else:
		for p in main.plots:
			p.set_remote({})  # 收到主人数据前先显示空地
		main.farm_sign.text = "%s的农场" % Net.player_name(Net.visiting)
		main.home_sign.text = "%s的小院" % Net.player_name(Net.visiting)
		main.cancel_placing()
		main._build_home([], true)
		if main.inside:
			main.exit_home()
		main.player.position = Vector2(1845, 1240)
		main.player.target = main.player.position
		main.player.moving = false
		main.player.pending = null
	main.farm_sign.queue_redraw()
	main.home_sign.queue_redraw()


func _on_farm_visitor(id: int) -> void:
	GameState.toast.emit("%s 来你的农场串门啦！" % Net.player_name(id))
	Net.push_farm(farm_states())


func _on_farm_received(data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var states: Array = data.get("plots", [])
	for i in mini(states.size(), main.plots.size()):
		main.plots[i].set_remote(states[i])
	var list := []
	for f in data.get("home", []):
		if typeof(f) == TYPE_DICTIONARY and GameState.FURNITURE.has(str(f.get("id", ""))):
			var p := Vector2(float(f.get("x", 0)), float(f.get("y", 0)))
			if GameState.HOME_RECT.has_point(p):
				list.append({"id": str(f["id"]), "x": p.x, "y": p.y})
	main._build_home(list.slice(0, 40), true)


func _on_farm_action_requested(id: int, plot_id: int, action: String) -> void:
	if plot_id < 0 or plot_id >= main.plots.size():
		return
	var r: Array = main.plots[plot_id].remote_action(action, Net.player_name(id))
	Net.reply_farm_action(id, r[0], r[1], r[2])
	if str(r[1]) != "" or int(r[2]) > 0:
		GameState.record_guest(Net.player_name(id))  # 记进明天的小镇日报
	Net.push_farm(farm_states())


func _on_farm_action_result(msg: String, item: String, beans: int) -> void:
	if item != "":
		GameState.add_item(item)
		GameState.record("harvest", item)
	if beans > 0:
		if GameState.help_today >= main.HELP_REWARDS_PER_DAY:
			msg = "谢谢你的帮忙！（今天的帮忙奖励已经领满啦）"
		else:
			GameState.help_today += 1
			GameState.add_beans(beans)
			GameState.record("help")
	GameState.toast.emit(msg)


func _on_roster_changed() -> void:
	var me := Net.my_id()
	for id in Net.players:
		if id == me:
			continue
		var info: Dictionary = Net.players[id]
		if not main.remotes.has(id):
			var r = main.RemoteMole.new()
			r.peer_id = id
			r.position = Vector2(1200, 880) + Vector2(randf_range(-60, 60), randf_range(-30, 30))
			main.ysort.add_child(r)
			main.remotes[id] = r
			var lh = main.Lahm.new()
			lh.is_remote = true
			lh.player = r
			lh.position = r.position + Vector2(-50, 0)
			main.ysort.add_child(lh)
			r.lahm = lh
			Sfx.play("door")
			main.ui.add_chat_line("", "【系统】%s 来到了小镇" % info["name"], Color(1, 0.9, 0.4))
		main.remotes[id].apply_info(info)
		if is_instance_valid(main.remotes[id].lahm):
			main.remotes[id].lahm.level = int(info["lahm"])
			main.remotes[id].lahm.acc = str(info["lacc"])
	for id in main.remotes.keys():
		if not Net.players.has(id) or id == me:
			if Net.players.size() > 0:
				main.ui.add_chat_line("", "【系统】%s 离开了小镇" % main.remotes[id].display_name, Color(1, 0.9, 0.4))
			if is_instance_valid(main.remotes[id].lahm):
				main.remotes[id].lahm.queue_free()
			main.remotes[id].queue_free()
			main.remotes.erase(id)


func _on_peer_moved(id: int, pos: Vector2, to: Vector2, is_fishing: bool, farm: int) -> void:
	if main.remotes.has(id):
		main.remotes[id].net_move(pos, to, is_fishing)
		main.remotes[id].farm = farm


## 每个人的农场画在地图同一块地方：别人在“另一家”的农场里时，不在我的农场区域显示
func update_remote_visibility() -> void:
	var mine := my_farm()
	for r in main.remotes.values():
		r.visible = r.farm == mine or not main._is_private(r.position)
		if is_instance_valid(r.lahm):
			r.lahm.visible = r.visible and (r.farm == mine or not main._is_private(r.lahm.position))


func _on_peer_chat(id: int, text: String) -> void:
	Sfx.play("pop")
	if main.remotes.has(id):
		main.remotes[id].say(text)
	main.ui.add_chat_line(Net.player_name(id), text)


func _on_gift(id: int, beans: int) -> void:
	Sfx.play("gift")
	GameState.add_beans(beans)
	GameState.toast.emit("%s 送给你 %d 摩尔豆！" % [Net.player_name(id), beans])


func _on_item_gift(id: int, item: String, n: int) -> void:
	Sfx.play("gift")
	GameState.add_item(item, n)
	var msg := "%s 送给你 %s ×%d！" % [Net.player_name(id), GameState.item_name(item), n]
	GameState.toast.emit(msg)
	main.ui.add_chat_line("", "【礼物】" + msg, Color(1, 0.8, 0.9))
	if main.remotes.has(id):
		main.remotes[id].play_emote("happy")


# ---------- 一起跳舞 ----------
# 附近的好友在 3 秒内做了同一个表情，双方各自判定“合拍”，都会得到奖励（20 秒冷却）

const DANCE_RANGE := 220.0
const DANCE_WINDOW := 3.0

var my_emote := ""
var my_emote_t := -100.0
var dance_cooldown_until := 0.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _on_peer_emote(id: int, kind: String) -> void:
	if not main.remotes.has(id):
		return
	var r = main.remotes[id]
	r.play_emote(kind)
	r.set_meta("emote_kind", kind)
	r.set_meta("emote_t", _now())
	if kind == my_emote and _now() - my_emote_t < DANCE_WINDOW:
		_try_dance(r)


## 自己做了表情（ui.do_emote 调用）
func on_local_emote(kind: String) -> void:
	my_emote = kind
	my_emote_t = _now()
	for r in main.remotes.values():
		if r.get_meta("emote_kind", "") == kind and _now() - float(r.get_meta("emote_t", -100.0)) < DANCE_WINDOW:
			_try_dance(r)
			return


func _try_dance(r) -> void:
	if _now() < dance_cooldown_until or not r.visible or r.position.distance_to(main.player.position) > DANCE_RANGE:
		return
	dance_cooldown_until = _now() + 20.0
	GameState.add_beans(5)
	GameState.stats["dances"] = int(GameState.stats.get("dances", 0)) + 1
	GameState.check_achievements()
	GameState.toast.emit("和 %s 一起跳舞，太合拍啦！+5 摩尔豆" % r.display_name)
	Sfx.play("happy")
	main.player.play_emote("happy")
	var lahm = get_tree().get_first_node_in_group("my_lahm")
	if lahm != null:
		lahm._burst()
