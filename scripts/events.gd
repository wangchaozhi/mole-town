extends CanvasLayer
## 随机事件：
##   夜晚流星雨 —— 22 点时一定概率出现，流星划过屏幕，点击流星许愿得奖励（每场最多 5 个愿望）
##   迷路的小拉姆 —— 每天早上 8 点一定概率出现在小镇某个角落（见 lost_lahm.gd）

const LostLahm = preload("res://scripts/lost_lahm.gd")
const Firefly = preload("res://scripts/firefly.gd")
const LeafPile = preload("res://scripts/leaf_pile.gd")
const Clover = preload("res://scripts/clover.gd")
const LEAF_SPOTS := [Vector2(480, 580), Vector2(860, 420), Vector2(1560, 660), Vector2(2050, 560), Vector2(300, 1000),
	Vector2(1530, 990), Vector2(2200, 1180), Vector2(760, 900), Vector2(2010, 400), Vector2(200, 480)]
const FIREFLY_SPOTS := [Vector2(240, 860), Vector2(700, 1150), Vector2(330, 1240), Vector2(150, 600), Vector2(420, 380),
	Vector2(2250, 900), Vector2(2200, 450), Vector2(900, 330), Vector2(1980, 1300), Vector2(560, 700)]
const MAX_FIREFLIES := 8
const SHOWER_TIME := 25.0
const MAX_WISHES := 5
const LOST_SPOTS := [Vector2(150, 420), Vector2(2280, 640), Vector2(980, 1320), Vector2(1520, 240), Vector2(340, 1250), Vector2(2250, 1300)]

var main = null
var canvas: Node2D
var meteors: Array = []  # [位置, 剩余寿命]
var sparkles: Array = []  # [位置, 剩余寿命]
var shower := 0.0
var spawn := 0.0
var wishes := 0
var last_hour := -1
var firefly_timer := 2.0


func _ready() -> void:
	layer = 2
	last_hour = int(GameState.minutes / 60.0)  # 进游戏的那一刻不算“整点到了”，避免一开局就触发事件
	if last_hour >= 6 and last_hour < 18:
		spawn_leaf_piles.call_deferred()  # 秋天白天进游戏也能看到落叶堆
	canvas = Node2D.new()
	canvas.draw.connect(_draw_sky)
	add_child(canvas)


func _process(delta: float) -> void:
	var h := int(GameState.minutes / 60.0)
	if h != last_hour:
		last_hour = h
		_hourly(h)
	if shower > 0.0 and not GameState.is_night():
		shower = 0.0  # 天亮了，流星雨结束
	if shower > 0.0:
		shower -= delta
		spawn -= delta
		if spawn <= 0.0:
			spawn = randf_range(0.4, 0.9)
			var vs := get_viewport().get_visible_rect().size
			meteors.append([Vector2(randf_range(vs.x * 0.2, vs.x * 1.1), randf_range(-20, vs.y * 0.3)), 1.3])
	for m in meteors:
		m[0] += Vector2(-520, 300) * delta
		m[1] -= delta
	meteors = meteors.filter(func(m): return m[1] > 0.0)
	for s in sparkles:
		s[1] -= delta
	sparkles = sparkles.filter(func(s): return s[1] > 0.0)
	var indoors: bool = main != null and main.inside
	canvas.visible = not indoors
	canvas.queue_redraw()
	_fireflies(delta)


## 夏天 19 点到凌晨 3 点之间，萤火虫陆续出现在湖边和树林里；时间过了就飞走
func _fireflies(delta: float) -> void:
	firefly_timer -= delta
	if firefly_timer > 0.0 or main == null:
		return
	firefly_timer = 3.0
	var h := GameState.minutes / 60.0
	var active := GameState.season() == 1 and (h >= 19.0 or h < 3.0) and Net.visiting == 0
	var flies := get_tree().get_nodes_in_group("fireflies")
	if not active:
		for f in flies:
			if not f.leaving:
				f.fly_away()
		return
	if flies.size() < MAX_FIREFLIES:
		var ff = Firefly.new()
		ff.position = FIREFLY_SPOTS.pick_random() + Vector2(randf_range(-60, 60), randf_range(-40, 40))
		main.ysort.add_child(ff)

func _hourly(h: int) -> void:
	if h == 22 and randf() < 0.4:
		start_shower()
	if h == 8 and randf() < 0.4 and Net.visiting == 0:
		spawn_lost_lahm()
	if h >= 6 and h < 18:
		spawn_leaf_piles()
	if h == 18:
		for l in get_tree().get_nodes_in_group("lost_lahm"):
			if not l.following:
				l.queue_free()  # 天黑前小拉姆自己找到家了


## 秋天每天早上（或者白天第一次进游戏时）在小镇里撒 4 堆落叶，冬天是 4 堆雪；季节过了就清掉
func spawn_leaf_piles() -> void:
	if main == null:
		return
	var winter := GameState.season() == 3
	for cl in get_tree().get_nodes_in_group("clovers"):
		if GameState.season() != 0:
			cl.queue_free()
	if GameState.season() == 0 and GameState.leaf_day != GameState.day and Net.visiting == 0:
		# 春天：藏一棵四叶草
		GameState.leaf_day = GameState.day
		var cl = Clover.new()
		cl.position = LEAF_SPOTS.pick_random() + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		main.ysort.add_child(cl)
	for lp in get_tree().get_nodes_in_group("leaf_piles"):
		if GameState.season() < 2 or lp.snow != winter:
			lp.queue_free()
	if GameState.season() < 2:
		return
	if GameState.leaf_day == GameState.day or Net.visiting != 0:
		return
	GameState.leaf_day = GameState.day
	var spots := LEAF_SPOTS.duplicate()
	spots.shuffle()
	for i in 4:
		var lp = LeafPile.new()
		lp.snow = winter
		lp.position = spots[i]
		main.ysort.add_child(lp)


func start_shower() -> void:
	shower = SHOWER_TIME
	wishes = 0
	GameState.toast.emit("流星雨来了！快点击划过的流星许愿~")


func spawn_lost_lahm() -> void:
	if main == null or not get_tree().get_nodes_in_group("lost_lahm").is_empty():
		return
	var l = LostLahm.new()
	l.main = main
	l.position = LOST_SPOTS.pick_random()
	l.add_to_group("lost_lahm")
	main.ysort.add_child(l)
	GameState.toast.emit("听说有一只小拉姆迷路了，在小镇的某个角落……（看看小地图上的问号）")


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or meteors.is_empty() or (main != null and main.inside):
		return
	for m in meteors:
		if (mb.position - m[0]).length() < 34.0:
			meteors.erase(m)
			_wish(mb.position)
			get_viewport().set_input_as_handled()
			return


func _wish(at: Vector2) -> void:
	if wishes >= MAX_WISHES:
		GameState.toast.emit("今晚已经许了好多愿望啦~")
		return
	wishes += 1
	for i in 8:
		sparkles.append([at + Vector2(randf_range(-30, 30), randf_range(-30, 30)), randf_range(0.5, 1.0)])
	Sfx.play("happy")
	var r := randf()
	if r < 0.5:
		var n := randi_range(30, 80)
		GameState.add_beans(n)
		GameState.toast.emit("许愿成功！获得 %d 摩尔豆" % n)
	elif r < 0.8:
		GameState.add_exp(20)
		GameState.toast.emit("许愿成功！经验 +20")
	else:
		GameState.add_item("lahm_fruit")
		GameState.toast.emit("许愿成功！获得一个拉姆果")
	GameState.stats["wishes"] = int(GameState.stats.get("wishes", 0)) + 1
	GameState.check_achievements()


func _draw_sky() -> void:
	for m in meteors:
		var p: Vector2 = m[0]
		var a := clampf(float(m[1]) / 0.4, 0.0, 1.0)
		canvas.draw_line(p, p + Vector2(110, -64), Color(1, 1, 0.85, 0.35 * a), 4.0)
		canvas.draw_line(p, p + Vector2(60, -35), Color(1, 1, 0.9, 0.8 * a), 2.5)
		canvas.draw_circle(p, 5.0, Color(1, 1, 0.85, a))
	for s in sparkles:
		var p: Vector2 = s[0]
		var k: float = s[1]
		canvas.draw_line(p + Vector2(-6 * k, 0), p + Vector2(6 * k, 0), Color(1, 0.95, 0.6, k), 2.0)
		canvas.draw_line(p + Vector2(0, -6 * k), p + Vector2(0, 6 * k), Color(1, 0.95, 0.6, k), 2.0)
