extends Node2D
## 主场景：搭建小镇、处理点击、昼夜变化。

const World = preload("res://scripts/world.gd")
const Pond = preload("res://scripts/pond.gd")
const Prop = preload("res://scripts/prop.gd")
const Plot = preload("res://scripts/plot.gd")
const PlayerScript = preload("res://scripts/player.gd")
const NPC = preload("res://scripts/npc.gd")
const Lahm = preload("res://scripts/lahm.gd")
const UI = preload("res://scripts/ui.gd")
const RemoteMole = preload("res://scripts/remote_mole.gd")
const Rain = preload("res://scripts/rain.gd")

const FARM_RECT := Rect2(1570, 850, 560, 360)
const HELP_REWARDS_PER_DAY := 20

var remotes := {}  # peer_id -> 远程玩家节点
var plots := []
var rain_dim := 0.0
var farm_sign
var ysort: Node2D
var player
var pond
var ui
var sky: CanvasModulate
var fx: ClickFx


class ClickFx extends Node2D:
	var life := 0.0

	func pop(p: Vector2) -> void:
		position = p
		life = 0.6

	func _process(delta: float) -> void:
		if life > 0.0:
			life -= delta
			queue_redraw()

	func _draw() -> void:
		if life > 0.0:
			var k := life / 0.6
			draw_arc(Vector2.ZERO, 20.0 * (1.6 - k), 0.0, TAU, 32, Color(1, 1, 1, k), 3.0)


func _ready() -> void:
	randomize()
	add_child(World.new())
	pond = Pond.new()
	pond.position = Vector2(520, 1030)
	add_child(pond)
	fx = ClickFx.new()
	fx.z_index = -4
	add_child(fx)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)

	_build_props()
	_build_farm()

	player = PlayerScript.new()
	player.position = Vector2(1200, 880)
	ysort.add_child(player)
	pond.player = player
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 2400
	cam.limit_bottom = 1400
	cam.offset = Vector2(0, -30)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	player.add_child(cam)

	var lahm = Lahm.new()
	lahm.player = player
	lahm.position = player.position + Vector2(-60, 0)
	ysort.add_child(lahm)

	_spawn_npc("乐乐", "lele", Vector2(1040, 790), "flower", Color(0.66, 0.46, 0.33),
		["有空来找我领任务哦~", "今天天气真好呀！", "小摩尔们都好勤劳~"])
	_spawn_npc("店长豆豆", "shop", Vector2(1750, 545), "straw", Color(0.52, 0.36, 0.24),
		["欢迎光临摩尔百货！", "新到的小王冠，要看看吗？", "种子大减价啦~"])
	_spawn_npc("小黄", "wander", Vector2(1300, 650), "red_cap", Color(0.72, 0.55, 0.3),
		["喷泉好漂亮！", "有人一起玩吗？", "我想要一顶小王冠……"])
	_spawn_npc("嘟嘟", "wander", Vector2(850, 1150), "none", Color(0.5, 0.36, 0.28),
		["今天钓到了一条大鱼！", "嘘……鱼要上钩了", "湖边好凉快~"])
	_spawn_npc("米米", "wander", Vector2(1500, 1100), "flower", Color(0.62, 0.42, 0.36),
		["草莓快熟了吧？", "向日葵好高啊！", "农场的害虫真讨厌"])
	_spawn_npc("阿呆", "wander", Vector2(1000, 420), "crown", Color(0.55, 0.4, 0.3),
		["城堡里好像有宝藏？", "我是摩尔城堡的守卫！", "嘿嘿嘿~"])

	sky = CanvasModulate.new()
	add_child(sky)
	add_child(Rain.new())
	ui = UI.new()
	ui.player = player
	add_child(ui)

	if GameState.offline_seconds > 60.0:
		GameState.toast.emit("欢迎回来！你不在的时候，农场的作物也在生长哦~")
	GameState.offline_seconds = 0.0

	# 联机
	Net.roster_changed.connect(_on_roster_changed)
	Net.peer_moved.connect(_on_peer_moved)
	Net.peer_chat.connect(_on_peer_chat)
	Net.gift_received.connect(_on_gift)
	Net.peer_emote.connect(func(id, kind):
		if remotes.has(id):
			remotes[id].play_emote(kind))
	if not GameState.hat_changed.is_connected(Net.send_info):
		GameState.hat_changed.connect(Net.send_info)
	var sync := Timer.new()
	sync.wait_time = 0.1
	sync.autostart = true
	sync.timeout.connect(func():
		Net.send_move(player.position, player.target if player.moving else player.position, player.fishing, my_farm()))
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
			Net.push_farm(_farm_states()))
	add_child(farm_sync)


## 我现在所在的是谁家的农场（串门时是主人的 id，否则是自己的 id）
func my_farm() -> int:
	return Net.visiting if Net.visiting != 0 else Net.my_id()


func _farm_states() -> Array:
	var out := []
	for p in plots:
		out.append(p.get_state())
	return out


func _on_visit_changed() -> void:
	if Net.visiting == 0:
		for p in plots:
			p.clear_remote()
		farm_sign.text = "开心农场"
	else:
		for p in plots:
			p.set_remote({})  # 收到主人数据前先显示空地
		farm_sign.text = "%s的农场" % Net.player_name(Net.visiting)
		player.position = Vector2(1845, 1240)
		player.target = player.position
		player.moving = false
		player.pending = null
	farm_sign.queue_redraw()


func _on_farm_visitor(id: int) -> void:
	GameState.toast.emit("%s 来你的农场串门啦！" % Net.player_name(id))
	Net.push_farm(_farm_states())


func _on_farm_received(states: Array) -> void:
	for i in mini(states.size(), plots.size()):
		plots[i].set_remote(states[i])


func _on_farm_action_requested(id: int, plot_id: int, action: String) -> void:
	if plot_id < 0 or plot_id >= plots.size():
		return
	var r: Array = plots[plot_id].remote_action(action, Net.player_name(id))
	Net.reply_farm_action(id, r[0], r[1], r[2])
	Net.push_farm(_farm_states())


func _on_farm_action_result(msg: String, item: String, beans: int) -> void:
	if item != "":
		GameState.add_item(item)
		GameState.record("harvest", item)
	if beans > 0:
		if GameState.help_today >= HELP_REWARDS_PER_DAY:
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
		if not remotes.has(id):
			var r = RemoteMole.new()
			r.peer_id = id
			r.position = Vector2(1200, 880) + Vector2(randf_range(-60, 60), randf_range(-30, 30))
			ysort.add_child(r)
			remotes[id] = r
			var lh = Lahm.new()
			lh.is_remote = true
			lh.player = r
			lh.position = r.position + Vector2(-50, 0)
			ysort.add_child(lh)
			r.lahm = lh
			Sfx.play("door")
			ui.add_chat_line("", "【系统】%s 来到了小镇" % info["name"], Color(1, 0.9, 0.4))
		remotes[id].apply_info(info)
		if is_instance_valid(remotes[id].lahm):
			remotes[id].lahm.level = int(info["lahm"])
	for id in remotes.keys():
		if not Net.players.has(id) or id == me:
			if Net.players.size() > 0:
				ui.add_chat_line("", "【系统】%s 离开了小镇" % remotes[id].display_name, Color(1, 0.9, 0.4))
			if is_instance_valid(remotes[id].lahm):
				remotes[id].lahm.queue_free()
			remotes[id].queue_free()
			remotes.erase(id)


func _on_peer_moved(id: int, pos: Vector2, to: Vector2, is_fishing: bool, farm: int) -> void:
	if remotes.has(id):
		remotes[id].net_move(pos, to, is_fishing)
		remotes[id].farm = farm


## 每个人的农场画在地图同一块地方：别人在“另一家”的农场里时，不在我的农场区域显示
func _update_remote_visibility() -> void:
	var mine := my_farm()
	for r in remotes.values():
		r.visible = r.farm == mine or not FARM_RECT.has_point(r.position)
		if is_instance_valid(r.lahm):
			r.lahm.visible = r.visible and (r.farm == mine or not FARM_RECT.has_point(r.lahm.position))


func _on_peer_chat(id: int, text: String) -> void:
	Sfx.play("pop")
	if remotes.has(id):
		remotes[id].say(text)
	ui.add_chat_line(Net.player_name(id), text)


func _on_gift(id: int, beans: int) -> void:
	Sfx.play("gift")
	GameState.add_beans(beans)
	GameState.toast.emit("%s 送给你 %d 摩尔豆！" % [Net.player_name(id), beans])


func _prop(kind: String, pos: Vector2, text: String = "", size: Vector2 = Vector2.ZERO) -> Node2D:
	var p = Prop.new()
	p.kind = kind
	p.position = pos
	p.text = text
	p.size = size
	ysort.add_child(p)
	return p


func _spawn_npc(n: String, role: String, pos: Vector2, hat: String, col: Color, lines: Array) -> void:
	var npc = NPC.new()
	npc.display_name = n
	npc.role = role
	npc.position = pos
	npc.hat = hat
	npc.body_color = col
	npc.lines = lines
	ysort.add_child(npc)


func _build_props() -> void:
	_prop("castle", Vector2(1200, 330))
	_prop("fountain", Vector2(1200, 730))
	_prop("house", Vector2(650, 480), "乐乐的家")
	_prop("shop", Vector2(1750, 480), "摩尔百货")
	for p in [Vector2(1030, 560), Vector2(1370, 560), Vector2(1030, 890), Vector2(1370, 890)]:
		_prop("lamp", p)
	farm_sign = _prop("sign", Vector2(1700, 1265), "开心农场")
	_prop("sign", Vector2(860, 1110), "钓鱼湖")
	_prop("sign", Vector2(960, 700), "城堡广场")
	_prop("flowers", Vector2(500, 520))
	_prop("flowers", Vector2(800, 520))
	_prop("flowers", Vector2(1600, 520))
	_prop("flowers", Vector2(1900, 520))

	# 农场栅栏（底部中间留门）
	_prop("fence", Vector2(1590, 870), "", Vector2(520, 0))
	_prop("fence", Vector2(1590, 1195), "", Vector2(200, 0))
	_prop("fence", Vector2(1910, 1195), "", Vector2(200, 0))
	_prop("vfence", Vector2(1590, 1195), "", Vector2(0, 320))
	_prop("vfence", Vector2(2110, 1195), "", Vector2(0, 320))

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := 60.0
	while x < 2400.0:
		if absf(x - 1200.0) > 360.0:
			_prop("pine" if rng.randf() < 0.4 else "tree", Vector2(x + rng.randf_range(-20, 20), 120 + rng.randf_range(-10, 25)))
		_prop("pine" if rng.randf() < 0.4 else "tree", Vector2(x + rng.randf_range(-20, 20), 1390 + rng.randf_range(-10, 10)))
		x += 140.0
	var y := 260.0
	while y < 1350.0:
		_prop("tree" if rng.randf() < 0.6 else "pine", Vector2(40 + rng.randf_range(-10, 10), y))
		_prop("tree" if rng.randf() < 0.6 else "pine", Vector2(2360 + rng.randf_range(-10, 10), y))
		y += 130.0
	for p in [Vector2(320, 330), Vector2(250, 720), Vector2(1000, 1250), Vector2(1350, 1230),
			Vector2(2230, 760), Vector2(2200, 330), Vector2(1500, 260), Vector2(880, 260), Vector2(420, 1300)]:
		_prop("tree", p)
	for p in [Vector2(450, 620), Vector2(900, 380), Vector2(1550, 380), Vector2(2000, 620),
			Vector2(1500, 800), Vector2(300, 950), Vector2(1100, 1100), Vector2(2200, 1100)]:
		_prop("bush", p)


func _build_farm() -> void:
	for r in 3:
		for c in 4:
			var plot = Plot.new()
			plot.plot_id = r * 4 + c
			plot.position = Vector2(1700 + c * 105, 960 + r * 82)
			ysort.add_child(plot)
			plots.append(plot)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if ui.fishing:
		return
	ui.close_popups()
	var p := get_global_mouse_position()
	var best = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.hit_test(p) and (best == null or n.position.y > best.position.y):
			best = n
	fx.pop(p)
	if best != null:
		player.go_interact(best)
	else:
		player.go_to(p)


func _process(delta: float) -> void:
	rain_dim = move_toward(rain_dim, 1.0 if GameState.raining else 0.0, delta * 0.5)
	sky.color = _sky_color(GameState.minutes / 60.0) * Color(1, 1, 1).lerp(Color(0.72, 0.76, 0.86), rain_dim)
	_update_remote_visibility()


func _sky_color(h: float) -> Color:
	var night := Color(0.45, 0.5, 0.78)
	var dusk := Color(1.0, 0.82, 0.68)
	var day := Color.WHITE
	if h < 5.0:
		return night
	if h < 7.0:
		return night.lerp(day, (h - 5.0) / 2.0)
	if h < 17.0:
		return day
	if h < 19.0:
		return day.lerp(dusk, (h - 17.0) / 2.0)
	if h < 21.0:
		return dusk.lerp(night, (h - 19.0) / 2.0)
	return night
