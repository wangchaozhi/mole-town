extends Node2D
## 拉姆：跟着你飞的小宠物。饿了会跟不上，点击它喂食；吃饱了点击是摸摸它。
## 喂食和抚摸会增加亲密度，升级后拉姆会帮忙：
##   Lv2 饿得更慢  Lv3 帮你抓农场害虫  Lv4 偶尔找到宝物  Lv5 帮你给缺水的作物浇水（还会戴上小王冠）

const D = preload("res://scripts/draw_util.gd")

var player = null
var t := 0.0
var facing := 1.0
var hearts: Array = []  # [位置, 剩余时间]
var name_label: Label
var is_remote := false  # 其他玩家的拉姆：只跟随、不能喂
var level := 1  # 远程拉姆的等级由网络同步；自己的拉姆读 GameState
var pet_cooldown := 0.0
var task_plot = null  # 正在去帮忙的农田
var task_kind := ""
var scan_timer := 1.0
var treasure_timer := 90.0


func _ready() -> void:
	if not is_remote:
		add_to_group("interactable")
		add_to_group("my_lahm")
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-50, 4)
	name_label.size = Vector2(100, 20)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.9))
	name_label.add_theme_color_override("font_outline_color", Color(0.4, 0.1, 0.2))
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.z_index = 5
	add_child(name_label)
	_update_label()


func cur_level() -> int:
	return level if is_remote else GameState.lahm_level


func _update_label() -> void:
	name_label.text = "拉姆 Lv%d" % cur_level()


func is_hungry() -> bool:
	return not is_remote and GameState.lahm_hunger < 25.0


func _process(delta: float) -> void:
	t += delta
	pet_cooldown = maxf(0.0, pet_cooldown - delta)
	if not is_remote and not is_hungry():
		_helper_tasks(delta)
	if player != null:
		var goal: Vector2 = player.position + Vector2(-55.0 * player.facing, 10.0)
		if task_plot != null and is_instance_valid(task_plot):
			goal = task_plot.position + Vector2(0, -6)
		var d := goal - position
		var spd := 50.0 if is_hungry() else 240.0 * clampf(d.length() / 80.0, 0.4, 2.0)
		if d.length() > 8.0:
			position += d.normalized() * minf(d.length(), spd * delta)
			if absf(d.x) > 3.0:
				facing = signf(d.x)
		elif task_plot != null:
			_finish_task()
	for h in hearts:
		h[0] += Vector2(0, -40) * delta
		h[1] -= delta
	hearts = hearts.filter(func(h): return h[1] > 0.0)
	if Engine.get_process_frames() % 30 == 0:
		_update_label()
	queue_redraw()


# ---------- 升级后的帮忙 ----------

func _helper_tasks(delta: float) -> void:
	var lv := GameState.lahm_level
	if lv >= 4:
		treasure_timer -= delta
		if treasure_timer <= 0.0:
			treasure_timer = randf_range(80.0, 140.0)
			_find_treasure()
	if task_plot != null:
		return
	scan_timer -= delta
	if scan_timer > 0.0 or lv < 3 or player == null:
		return
	scan_timer = 1.0
	for p in get_tree().get_nodes_in_group("plots"):
		if p.remote != null or p.position.distance_to(player.position) > 380.0:
			continue
		if p.bug:
			task_plot = p
			task_kind = "bug"
			return
		if lv >= 5 and p.crop != "" and p.growth < 1.0 and p.water_time <= 0.0:
			task_plot = p
			task_kind = "water"
			return


func _finish_task() -> void:
	var p = task_plot
	task_plot = null
	if not is_instance_valid(p):
		return
	if task_kind == "bug" and p.bug:
		p.bug = false
		GameState.add_beans(3)
		GameState.toast.emit("拉姆帮你抓走了一只害虫！+3 摩尔豆")
		Sfx.play("bug")
		_burst()
	elif task_kind == "water" and p.crop != "" and p.water_time <= 0.0:
		p.water_time = 20.0
		GameState.toast.emit("拉姆帮你给%s浇了水" % GameState.item_name(p.crop))
		Sfx.play("water")
		_burst()


func _find_treasure() -> void:
	var r := randf()
	if r < 0.4:
		GameState.add_item("lahm_fruit")
		GameState.toast.emit("拉姆找到了一个拉姆果！")
	elif r < 0.7:
		var seed: String = GameState.CROPS.keys().filter(func(c): return GameState.is_unlocked(c)).pick_random()
		GameState.add_item("seed_" + seed, 2)
		GameState.toast.emit("拉姆找到了 2 颗%s！" % GameState.item_name("seed_" + seed))
	else:
		var n := randi_range(10, 30)
		GameState.add_beans(n)
		GameState.toast.emit("拉姆找到了 %d 摩尔豆！" % n)
	Sfx.play("happy")
	_burst()


# ---------- 互动 ----------

func hit_test(p: Vector2) -> bool:
	return (p - (position + Vector2(0, -32))).length() < 26.0


func get_interact_point() -> Vector2:
	return position + Vector2(45, 4)


func interact(_pl) -> void:
	if GameState.lahm_hunger >= 90.0:
		_pet()
		return
	if GameState.remove_item("lahm_fruit"):
		GameState.lahm_hunger = minf(100.0, GameState.lahm_hunger + 40.0)
		GameState.toast.emit("拉姆吃了拉姆果，好开心！亲密度 +10")
		GameState.add_lahm_exp(10)
		_burst()
		Sfx.play("happy")
		return
	for c in GameState.CROPS:
		if GameState.count(c) > 0:
			GameState.remove_item(c)
			GameState.lahm_hunger = minf(100.0, GameState.lahm_hunger + 20.0)
			GameState.toast.emit("拉姆吃了一个%s，亲密度 +5" % GameState.item_name(c))
			GameState.add_lahm_exp(5)
			_burst()
			Sfx.play("happy")
			return
	GameState.toast.emit("背包里没有吃的了，去摩尔百货买拉姆果吧")


func _pet() -> void:
	_burst()
	Sfx.play("happy")
	if pet_cooldown > 0.0:
		GameState.toast.emit("拉姆蹭了蹭你~")
		return
	pet_cooldown = 20.0
	GameState.add_lahm_exp(2)
	GameState.toast.emit("摸摸拉姆，它很开心！亲密度 +2")


func _burst() -> void:
	for i in 5:
		hearts.append([Vector2(randf_range(-20, 20), -50 - randf_range(0, 15)), randf_range(0.8, 1.4)])


# ---------- 绘制 ----------

func _draw() -> void:
	var hungry := is_hungry()
	var lv := cur_level()
	var r := 17.0 + (lv - 1) * 1.5  # 等级越高个头越大
	var hover := -24.0 + (0.0 if hungry else sin(t * 3.0) * 4.0)
	if hungry:
		hover = -16.0
	D.ell(self, Vector2.ZERO, Vector2(15, 5), Color(0, 0, 0, 0.2))
	var c := Vector2(0, hover - 8)
	var pink := Color(1.0, 0.66, 0.78)
	var flap := sin(t * 14.0) * 4.0 if not hungry else 0.0
	D.ell(self, c + Vector2(-r - 2, -6), Vector2(9, 6 + flap), Color(1, 1, 1, 0.9))
	D.ell(self, c + Vector2(r + 2, -6), Vector2(9, 6 + flap), Color(1, 1, 1, 0.9))
	draw_circle(c, r + 1.5, pink.darkened(0.3))
	draw_circle(c, r, pink)
	D.ell(self, c + Vector2(facing * 2.0, 7), Vector2(10, 7), Color(1, 0.88, 0.92))
	var ex := facing * 2.5
	if hungry:
		for sx in [-6.0, 6.0]:
			var e: Vector2 = c + Vector2(sx + ex, -3)
			draw_line(e + Vector2(-3, -1), e + Vector2(3, 1) if sx < 0 else e + Vector2(3, -1), Color(0.1, 0.05, 0.1), 2.0)
	else:
		for sx in [-6.0, 6.0]:
			var e: Vector2 = c + Vector2(sx + ex, -3)
			draw_circle(e, 4.5, Color(0.1, 0.05, 0.15))
			draw_circle(e + Vector2(1.5, -1.5), 1.6, Color.WHITE)
	draw_arc(c + Vector2(ex, 5), 3.0, 0.2, PI - 0.2, 8, Color(0.5, 0.15, 0.25), 1.5)
	D.ell(self, c + Vector2(-11 + ex, 3), Vector2(3.5, 2), Color(1, 0.4, 0.5, 0.6))
	D.ell(self, c + Vector2(11 + ex, 3), Vector2(3.5, 2), Color(1, 0.4, 0.5, 0.6))
	var ant := c + Vector2(-3.0 * facing, -r - 15)
	draw_line(c + Vector2(0, -r + 1), ant, Color(0.5, 0.3, 0.35), 2.0)
	draw_circle(ant, 4.5, Color(1, 0.85, 0.2))
	if lv >= 5:
		var b := c + Vector2(6 * facing, -r + 2)
		draw_colored_polygon(PackedVector2Array([b + Vector2(-8, 1), b + Vector2(8, 1), b + Vector2(9, -9),
			b + Vector2(4, -4), b + Vector2(0, -11), b + Vector2(-4, -4), b + Vector2(-9, -9)]), Color(1, 0.82, 0.15))
	if hungry and fmod(t, 2.0) < 1.3:
		D.text(self, c + Vector2(0, -48), "饿…", 16, Color(0.6, 0.2, 0.3))
	for h in hearts:
		D.heart(self, h[0], 6.0, Color(1, 0.3, 0.45, clampf(h[1], 0.0, 1.0)))
