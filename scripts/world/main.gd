extends Node2D
## 主场景：搭建小镇、处理点击、昼夜变化。

const World = preload("res://scripts/world/world.gd")
const Pond = preload("res://scripts/world/pond.gd")
const Prop = preload("res://scripts/world/prop.gd")
const Plot = preload("res://scripts/world/plot.gd")
const PlayerScript = preload("res://scripts/entities/player.gd")
const NPC = preload("res://scripts/entities/npc.gd")
const Lahm = preload("res://scripts/entities/lahm.gd")
const UI = preload("res://scripts/ui/ui.gd")
const RemoteMole = preload("res://scripts/entities/remote_mole.gd")
const Rain = preload("res://scripts/world/rain.gd")
const Furniture = preload("res://scripts/world/furniture.gd")
const Gate = preload("res://scripts/world/gate.gd")
const Board = preload("res://scripts/world/board.gd")
const FestivalDeco = preload("res://scripts/world/festival_deco.gd")
const Stove = preload("res://scripts/world/stove.gd")
const Interior = preload("res://scripts/world/interior.gd")
const Spot = preload("res://scripts/world/spot.gd")
const TutorialArrow = preload("res://scripts/world/tutorial_arrow.gd")
const Sprinkler = preload("res://scripts/world/sprinkler.gd")
const Events = preload("res://scripts/events/events.gd")
const MainNet = preload("res://scripts/world/main_net.gd")
const COTTAGE_POS := Vector2(1010, 1175)
const INTERIOR_WALK := Rect2(3030, 320, 420, 185)
const WORLD_WALK := Rect2(40, 150, 2320, 1210)
const CastleHall = preload("res://scripts/world/castle_hall.gd")
## 室内房间：镜头范围、可走动范围、出门后站的位置、小地图上显示的位置
const ROOMS := {
	"cottage": {"view": Rect2(2600, 0, 1280, 720), "walk": Rect2(3030, 320, 420, 185), "exit": Vector2(1010, 1215), "map": Vector2(1010, 1175)},
	"castle": {"view": Rect2(2680, 840, 1280, 720), "walk": Rect2(3030, 1160, 580, 230), "exit": Vector2(1200, 390), "map": Vector2(1200, 330)},
}

const FARM_RECT := Rect2(1570, 850, 780, 360)  # 农场 + 温室
const HELP_REWARDS_PER_DAY := 20
## NPC 晚上睡觉的地方（乐乐家门口、百货旁、城堡门口）
const SLEEP_SPOTS := {
	"乐乐": Vector2(650, 530), "小黄": Vector2(585, 545), "嘟嘟": Vector2(715, 545),
	"米米": Vector2(1830, 560), "阿呆": Vector2(1250, 365),
}

var remotes := {}  # peer_id -> 远程玩家节点
var mp  # main_net.gd：联机同步
var plots := []
var cam: Camera2D
var zoom_level := 1.0
var inside := false  # 是否在自己的小屋里
var events  # 随机事件（流星雨、迷路的小拉姆）
var room := "cottage"  # 当前所在的室内房间
var rain_dim := 0.0
var farm_sign
var home_sign
var home_nodes: Array = []
var ghost = null  # 摆放家具时跟随鼠标的预览
var placing := ""
var moving_index := -1  # 正在移动的已摆放家具下标
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
	_build_home(GameState.home, false)

	player = PlayerScript.new()
	player.position = Vector2(1200, 880)
	ysort.add_child(player)
	pond.player = player
	cam = Camera2D.new()
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

	_spawn_npc("乐乐", "lele", Vector2(1095, 805), "flower", Color(0.66, 0.46, 0.33),
		["有空来找我领任务哦~", "今天天气真好呀！", "小摩尔们都好勤劳~"])
	_spawn_npc("店长豆豆", "shop", Vector2(1750, 545), "straw", Color(0.52, 0.36, 0.24),
		["欢迎光临摩尔百货！", "新到的小王冠，要看看吗？", "种子大减价啦~"])
	_spawn_npc("小黄", "wander", Vector2(1300, 650), "red_cap", Color(0.72, 0.55, 0.3),
		["喷泉好漂亮！", "有人一起玩吗？", "我想要一顶小王冠……"])
	_spawn_npc("嘟嘟", "wander", Vector2(850, 1150), "none", Color(0.5, 0.36, 0.28),
		["今天钓到了一条大鱼！", "嘘……鱼要上钩了", "湖边好凉快~"])
	_spawn_npc("米米", "wander", Vector2(1500, 1100), "flower", Color(0.62, 0.42, 0.36),
		["草莓快熟了吧？", "向日葵好高啊！", "农场的害虫真讨厌"])
	_spawn_npc("旅行商人阿布", "merchant", Vector2(985, 965), "straw", Color(0.45, 0.33, 0.25),
		["走过路过不要错过~", "这些可都是远方的好东西！", "周末才来一次哦"])
	_spawn_npc("阿呆", "wander", Vector2(1000, 420), "crown", Color(0.55, 0.4, 0.3),
		["城堡里好像有宝藏？", "我是摩尔城堡的守卫！", "嘿嘿嘿~"])

	sky = CanvasModulate.new()
	add_child(sky)
	add_child(Rain.new())
	events = Events.new()
	events.main = self
	add_child(events)
	ui = UI.new()
	ui.player = player
	add_child(ui)

	if GameState.offline_seconds > 60.0:
		GameState.toast.emit("欢迎回来！你不在的时候，农场的作物也在生长哦~")
	GameState.offline_seconds = 0.0

	mp = MainNet.new()
	mp.main = self
	add_child(mp)
	mp.setup()

func _prop(kind: String, pos: Vector2, text: String = "", size: Vector2 = Vector2.ZERO) -> Node2D:
	var p = Prop.new()
	p.kind = kind
	p.position = pos
	p.text = text
	p.size = size
	ysort.add_child(p)
	return p


func _spawn_npc(n: String, role: String, pos: Vector2, hat: String, col: Color, lines: Array):
	var npc = NPC.new()
	npc.display_name = n
	npc.role = role
	npc.position = pos
	npc.hat = hat
	npc.body_color = col
	npc.lines = lines
	npc.sleep_spot = SLEEP_SPOTS.get(n, Vector2.ZERO)
	ysort.add_child(npc)
	return npc


func _build_props() -> void:
	_prop("castle", Vector2(1200, 330))
	add_child(FestivalDeco.new())
	_build_cottage()
	_build_castle_hall()
	var arrow = TutorialArrow.new()
	arrow.main = self
	add_child(arrow)
	var gacha = preload("res://scripts/world/gacha.gd").new()
	gacha.position = Vector2(1650, 660)
	ysort.add_child(gacha)
	var stove = Stove.new()
	stove.position = Vector2(870, 800)
	ysort.add_child(stove)
	var board = Board.new()
	board.position = Vector2(1455, 700)
	ysort.add_child(board)
	var gate = Gate.new()
	gate.position = Vector2(1200, 330)
	ysort.add_child(gate)
	_prop("fountain", Vector2(1200, 730))
	_prop("house", Vector2(650, 480), "乐乐的家")
	_prop("shop", Vector2(1750, 480), "摩尔百货")
	for p in [Vector2(1030, 560), Vector2(1370, 560), Vector2(1030, 890), Vector2(1370, 890)]:
		_prop("lamp", p)
	farm_sign = _prop("sign", Vector2(1700, 1265), "开心农场")
	home_sign = _prop("sign", Vector2(1150, 1050), "我的小院")
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
		# 随机数按原来的顺序取，保证其它树的位置不变；只是小院正下方不种树（会挡住小院）
		var bk := "pine" if rng.randf() < 0.4 else "tree"
		var bp := Vector2(x + rng.randf_range(-20, 20), 1390 + rng.randf_range(-10, 10))
		if bp.x < 1080.0 or bp.x > 1500.0:
			_prop(bk, bp)
		x += 140.0
	var y := 260.0
	while y < 1350.0:
		_prop("tree" if rng.randf() < 0.6 else "pine", Vector2(40 + rng.randf_range(-10, 10), y))
		_prop("tree" if rng.randf() < 0.6 else "pine", Vector2(2360 + rng.randf_range(-10, 10), y))
		y += 130.0
	for p in [Vector2(320, 330), Vector2(250, 720),
			Vector2(2230, 760), Vector2(2200, 330), Vector2(1500, 260), Vector2(880, 260), Vector2(420, 1300)]:
		_prop("tree", p)
	for p in [Vector2(450, 620), Vector2(900, 380), Vector2(1550, 380), Vector2(2000, 620),
			Vector2(1500, 800), Vector2(300, 950)]:
		_prop("bush", p)


func _build_farm() -> void:
	var sp = Sprinkler.new()
	sp.main = self
	sp.position = Vector2(1857, 1003)
	ysort.add_child(sp)
	for r in 3:
		for c in 4:
			var plot = Plot.new()
			plot.plot_id = r * 4 + c
			plot.position = Vector2(1700 + c * 105, 960 + r * 82)
			ysort.add_child(plot)
			plots.append(plot)
	var Greenhouse = preload("res://scripts/world/greenhouse.gd")
	add_child(Greenhouse.new())
	for r in 2:
		for c in 2:
			var gp = Plot.new()
			gp.plot_id = 12 + r * 2 + c
			gp.greenhouse = true
			gp.position = Vector2(2185 + c * 92, 975 + r * 120)
			ysort.add_child(gp)
			plots.append(gp)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_zoom(event):
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and placing != "":
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_try_place(get_global_mouse_position())
		else:
			cancel_placing()
		get_viewport().set_input_as_handled()
		return
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if GameState.input_locked:
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
	if ghost != null:
		ghost.position = get_global_mouse_position()
		ghost.set_valid(_can_place(ghost.position))
	mp.update_remote_visibility()


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


# ---------- 小院家具 ----------

## 农场和小院属于“各家私有”的区域
func _is_private(p: Vector2) -> bool:
	return FARM_RECT.has_point(p) or GameState.HOME_RECT.has_point(p) or Interior.ROOM.has_point(p) or CastleHall.ROOM.has_point(p)


func _build_home(list: Array, remote: bool) -> void:
	for n in home_nodes:
		n.queue_free()
	home_nodes.clear()
	for i in list.size():
		var f: Dictionary = list[i]
		var n = Furniture.new()
		n.kind = f["id"]
		n.index = -1 if remote else i
		n.position = Vector2(f["x"], f["y"])
		n.visible = not (not remote and i == moving_index)
		ysort.add_child(n)
		home_nodes.append(n)


func start_placing(kind: String, from_index: int = -1) -> void:
	cancel_placing()
	if Net.visiting != 0:
		GameState.toast.emit("在好友家不能摆家具哦，先回家吧")
		return
	placing = kind
	moving_index = from_index
	ghost = Furniture.new()
	ghost.kind = kind
	ghost.ghost = true
	ghost.position = get_global_mouse_position()
	ysort.add_child(ghost)
	if from_index >= 0 and from_index < home_nodes.size():
		home_nodes[from_index].visible = false
	GameState.toast.emit("点击小院里的空地摆放%s，右键或 Esc 取消" % GameState.FURNITURE[kind]["name"])


func cancel_placing() -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if moving_index >= 0 and moving_index < home_nodes.size():
		home_nodes[moving_index].visible = true
	placing = ""
	moving_index = -1


func _can_place(p: Vector2) -> bool:
	if not GameState.HOME_RECT.grow(-22).has_point(p):
		return false
	for i in GameState.home.size():
		if i == moving_index:
			continue
		var f: Dictionary = GameState.home[i]
		if p.distance_to(Vector2(f["x"], f["y"])) < 46.0:
			return false
	return true


func _try_place(p: Vector2) -> void:
	if not _can_place(p):
		GameState.toast.emit("这里放不下，要放在小院里的空地上")
		return
	if moving_index >= 0:
		GameState.home[moving_index]["x"] = p.x
		GameState.home[moving_index]["y"] = p.y
	else:
		if not GameState.remove_item("furn_" + placing):
			cancel_placing()
			return
		GameState.home.append({"id": placing, "x": p.x, "y": p.y})
	Sfx.play("plant")
	fx.pop(p)
	cancel_placing()
	_build_home(GameState.home, false)
	if not Net.visitors.is_empty():
		Net.push_farm(mp.farm_states())


func store_furniture(i: int) -> void:
	if i < 0 or i >= GameState.home.size():
		return
	var f: Dictionary = GameState.home[i]
	GameState.home.remove_at(i)
	GameState.add_item("furn_" + str(f["id"]))
	GameState.toast.emit("%s 收进背包了" % GameState.FURNITURE[f["id"]]["name"])
	_build_home(GameState.home, false)


# ---------- 传送 ----------

func teleport(p: Vector2) -> void:
	if ui.fishing:
		return
	if inside:
		exit_home()
	cancel_placing()
	p.x = clampf(p.x, player.world_rect.position.x, player.world_rect.end.x)
	p.y = clampf(p.y, player.world_rect.position.y, player.world_rect.end.y)
	if pond.contains(p):
		p = pond.edge_point(p)
	player.position = p
	player.target = p
	player.moving = false
	player.pending = null
	for c in player.get_children():
		if c is Camera2D:
			c.reset_smoothing()
	var lahm = get_tree().get_first_node_in_group("my_lahm")
	if lahm != null:
		lahm.end_hide(false, true)
		lahm.position = p + Vector2(-50, 6)
	fx.pop(p)
	Sfx.play("door")
	player.play_emote("happy")


# ---------- 镜头缩放：滚轮、+/- 键、触屏双指捏合 ----------

const ZOOM_MIN := 0.7
const ZOOM_MAX := 1.6


func set_zoom(z: float) -> void:
	# 室内镜头范围只有一屏大，不能缩小，否则会看到房间外面
	zoom_level = clampf(z, 1.0 if inside else ZOOM_MIN, ZOOM_MAX)
	cam.zoom = Vector2(zoom_level, zoom_level)


func _handle_zoom(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and placing == "":
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom_level * 1.1)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom_level / 1.1)
			return true
	var mg := event as InputEventMagnifyGesture
	if mg != null:
		set_zoom(zoom_level * mg.factor)
		return true
	var k := event as InputEventKey
	if k != null and k.pressed and not (get_viewport().gui_get_focus_owner() is LineEdit):
		if k.keycode == KEY_EQUAL or k.keycode == KEY_KP_ADD:
			set_zoom(zoom_level * 1.15)
			return true
		if k.keycode == KEY_MINUS or k.keycode == KEY_KP_SUBTRACT:
			set_zoom(zoom_level / 1.15)
			return true
	return false


# ---------- 我的小屋 ----------

func _build_cottage() -> void:
	_prop("cottage", COTTAGE_POS, "我的小屋")
	_spot("home_door", COTTAGE_POS)
	_spot("mailbox", COTTAGE_POS + Vector2(-100, 30))
	add_child(Interior.new())
	var room := Interior.ROOM
	_spot("exit_door", Vector2(room.get_center().x, room.end.y - 4))
	_spot("bed", Vector2(room.position.x + 75, room.position.y + 170))
	_spot("wardrobe", Vector2(room.end.x - 40, room.position.y + 135))
	_spot("shelf", Vector2(room.end.x - 120, room.position.y + 100))


func _spot(kind: String, pos: Vector2) -> void:
	var s = Spot.new()
	s.kind = kind
	s.position = pos
	s.add_to_group("home_spots")
	ysort.add_child(s)


func map_position() -> Vector2:
	return ROOMS[room]["map"] if inside else player.position


func enter_home() -> void:
	enter_room("cottage")


func exit_home() -> void:
	exit_room()


## 进入室内（小屋 / 城堡大厅）：换走动范围和镜头范围
func enter_room(id: String) -> void:
	if inside:
		return
	cancel_placing()
	ui.close_popups()
	inside = true
	room = id
	var r: Dictionary = ROOMS[id]
	var walk: Rect2 = r["walk"]
	player.world_rect = walk
	_move_player(Vector2(walk.get_center().x, walk.end.y - 6))
	set_zoom(zoom_level)
	_set_cam(r["view"])
	get_tree().call_group("home_spots", "queue_redraw")
	Sfx.play("door")


func exit_room() -> void:
	if not inside:
		return
	inside = false
	player.world_rect = WORLD_WALK
	_move_player(ROOMS[room]["exit"])
	_set_cam(Rect2(0, 0, 2400, 1400))
	Sfx.play("door")


func _set_cam(v: Rect2) -> void:
	cam.limit_left = int(v.position.x)
	cam.limit_top = int(v.position.y)
	cam.limit_right = int(v.end.x)
	cam.limit_bottom = int(v.end.y)
	cam.reset_smoothing()


func _move_player(p: Vector2) -> void:
	player.position = p
	player.target = p
	player.moving = false
	player.pending = null
	var lahm = get_tree().get_first_node_in_group("my_lahm")
	if lahm != null:
		lahm.end_hide(false, true)
		lahm.position = p + Vector2(-50, 4)


func home_action(kind: String) -> void:
	match kind:
		"home_door":
			enter_home()
		"exit_door", "castle_exit":
			exit_room()
		"bed":
			if GameState.can_sleep():
				_sleep()
			else:
				GameState.toast.emit("现在还不困，晚上 8 点以后再来睡吧")
		"wardrobe":
			var opts: Array = []
			for h in GameState.owned_hats:
				opts.append([GameState.HATS[h]["name"], _wear_hat.bind(h)])
			opts.append(["给拉姆换饰品", _lahm_wardrobe])
			opts.append(["关上衣柜", ui._noop])
			ui.show_dialog("衣柜", "今天戴哪顶帽子？（新帽子可以在摩尔百货买）", opts)
		"mailbox":
			ui.open_mail()
		"shelf":
			var st: Dictionary = GameState.stats
			ui.show_dialog("奖杯架", "成就 %d / %d　等级 Lv%d\n累计收获 %d 个作物 · 钓到 %d 条鱼 · 做了 %d 道菜 · 接果子最高 %d 分" % [
				GameState.achievements.size(), GameState.ACHIEVEMENTS.size(), GameState.player_level,
				int(st.get("harvest_total", 0)), int(st.get("fish_total", 0)), int(st.get("cook_total", 0)), GameState.best_catch],
				[["看看图鉴", ui.toggle_collection], ["好的", ui._noop]])


func _wear_hat(h: String) -> void:
	GameState.hat = h
	GameState.hat_changed.emit()
	player.play_emote("happy")
	Sfx.play("pop")


## 上床睡觉：屏幕渐黑，跳到第二天早上 6 点，期间作物继续生长
func _sleep() -> void:
	GameState.input_locked = true
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.root.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		var sec := GameState.sleep_until_morning()
		for p in plots:
			p._advance(sec)
		player.play_emote("sleep"))
	tw.tween_interval(0.5)
	tw.tween_property(fade, "color:a", 0.0, 0.6)
	tw.tween_callback(func():
		fade.queue_free()
		GameState.input_locked = false
		GameState.toast.emit("睡了个好觉！现在是早上 6 点")
		Sfx.play("happy"))


func _lahm_wardrobe() -> void:
	var opts: Array = []
	for a in GameState.owned_lahm_accs:
		opts.append([GameState.LAHM_ACCS[a]["name"], GameState.set_lahm_acc.bind(a)])
	opts.append(["算了", ui._noop])
	ui.show_dialog("拉姆的饰品", "给拉姆戴什么呢？（新饰品在摩尔百货「拉姆用品」里买）", opts)


# ---------- 城堡大厅 ----------

func _build_castle_hall() -> void:
	add_child(CastleHall.new())
	var r := CastleHall.ROOM
	_spot("castle_exit", Vector2(r.get_center().x, r.end.y - 4))
	var king = _spawn_npc("摩尔国王", "king", Vector2(r.get_center().x, r.position.y + 205), "crown", Color(0.62, 0.45, 0.3),
		["欢迎来到摩尔城堡！", "小镇的居民们都很勤劳啊~", "本周的挑战完成了吗？"])
	king.scale = Vector2(1.3, 1.3)
	king.world_rect = r  # 国王只在大厅里活动


func castle_gate() -> void:
	ui.show_dialog("摩尔城堡", "城堡大门开着，里面传来国王的笑声。要做什么呢？",
		[["进入城堡", enter_room.bind("castle")], ["玩接果子小游戏", ui.open_minigame_intro], ["离开", ui._noop]])
