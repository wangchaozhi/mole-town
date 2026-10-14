extends Node2D
## 一块农田：播种 -> 浇水 -> 生长 -> 收获，偶尔会有害虫。
## 串门时显示好友农田的状态（remote），点击会把操作发给好友处理。

const D = preload("res://scripts/draw_util.gd")

var plot_id := 0
var crop := ""
var growth := 0.0
var water_time := 0.0
var bug := false
var picked := false  # 成熟后是否已被来串门的好友摘过
var t := 0.0
var remote = null  # 串门时：好友这块地的状态 Dictionary
var greenhouse := false  # 温室里的地块


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("plots")
	t = randf() * 10.0
	var s = GameState.plots.get(str(plot_id))
	if s is Dictionary:
		crop = str(s.get("crop", ""))
		growth = float(s.get("growth", 0.0))
		water_time = float(s.get("water_time", 0.0))
		bug = bool(s.get("bug", false))
		picked = bool(s.get("picked", false))
		if crop != "" and not GameState.CROPS.has(crop):
			crop = ""
		if crop != "" and not bug:
			_advance(GameState.offline_seconds)


func get_state() -> Dictionary:
	return {"crop": crop, "growth": growth, "water_time": water_time, "bug": bug, "picked": picked}


func store_state() -> void:
	GameState.plots[str(plot_id)] = get_state()


func set_remote(s) -> void:
	if typeof(s) != TYPE_DICTIONARY:
		s = {}
	var c := str(s.get("crop", ""))
	remote = {
		"crop": c if GameState.CROPS.has(c) else "",
		"growth": clampf(float(s.get("growth", 0.0)), 0.0, 1.0),
		"water_time": float(s.get("water_time", 0.0)),
		"bug": bool(s.get("bug", false)),
		"picked": bool(s.get("picked", false)),
	}


func clear_remote() -> void:
	remote = null


func _advance(sec: float) -> void:
	if crop == "" or growth >= 1.0:
		return
	var speed := maxf(GameState.season_growth(crop), 1.0) * 1.2 if greenhouse else GameState.season_growth(crop)
	var gt: float = GameState.CROPS[crop]["grow_time"] / speed
	var wet := minf(sec, water_time)
	growth = minf(1.0, growth + (wet * 2.0 + (sec - wet)) / gt)
	water_time = maxf(0.0, water_time - sec)


func _process(delta: float) -> void:
	t += delta
	if greenhouse:
		visible = GameState.has_greenhouse
	if crop != "" and growth < 1.0 and GameState.raining:
		water_time = maxf(water_time, 3.0)  # 下雨自动浇水
	if crop != "" and growth < 1.0 and not bug:
		_advance(delta)
		if not greenhouse and randf() < delta * 0.004:
			bug = true
	queue_redraw()


func hit_test(p: Vector2) -> bool:
	if not visible:
		return false
	return Rect2(position + Vector2(-40, -62), Vector2(80, 90)).has_point(p)


func get_interact_point() -> Vector2:
	return position + Vector2(0, 42)


func interact(_pl) -> void:
	if remote != null:
		_visit_interact()
		return
	if bug:
		bug = false
		GameState.add_beans(3)
		Sfx.play("bug")
		GameState.toast.emit("抓走了一只害虫！+3 摩尔豆")
		return
	if crop == "":
		var seed := GameState.selected_seed
		if GameState.remove_item("seed_" + seed):
			crop = seed
			growth = 0.0
			water_time = 0.0
			picked = false
			Sfx.play("plant")
			GameState.add_exp(1)
			GameState.tutorial_event("plant")
			GameState.toast.emit("种下了%s，记得浇水哦" % GameState.item_name("seed_" + seed))
		else:
			GameState.toast.emit("没有%s了，去摩尔百货买吧" % GameState.item_name("seed_" + seed))
	elif growth >= 1.0:
		var n := 1 + (1 if randf() < 0.35 else 0) + (1 if GameState.festival() == "harvest" else 0)
		GameState.add_item(crop, n)
		GameState.record("harvest", crop, n)
		for i in n:
			GameState.report("harvest", crop)
		Sfx.play("harvest")
		GameState.toast.emit("收获了 %s ×%d！" % [GameState.item_name(crop), n])
		crop = ""
		growth = 0.0
		water_time = 0.0
		picked = false
	elif water_time <= 0.0:
		water_time = 20.0
		Sfx.play("water")
		GameState.tutorial_event("water")
		GameState.toast.emit("浇水完成，接下来 20 秒生长速度翻倍！")
	else:
		GameState.toast.emit("%s 正在生长中…… %d%%" % [GameState.item_name(crop), int(growth * 100)])


# ---------- 串门 ----------

func _visit_interact() -> void:
	var s: Dictionary = remote
	var c := str(s["crop"])
	if c == "":
		GameState.toast.emit("这块地还空着呢，主人还没种东西")
		return
	var action := ""
	if s["bug"]:
		action = "bug"
	elif float(s["growth"]) >= 1.0:
		if s["picked"]:
			GameState.toast.emit("这块地已经被摘过啦，给主人留着吧")
			return
		action = "pick"
	elif float(s["water_time"]) <= 0.0:
		action = "water"
	else:
		GameState.toast.emit("%s 正在生长中…… %d%%" % [GameState.item_name(c), int(float(s["growth"]) * 100)])
		return
	Sfx.play({"water": "water", "bug": "bug", "pick": "harvest"}[action])
	Net.send_farm_action(plot_id, action)


## 好友来串门时对这块地的操作（在农场主人这边执行）。返回 [提示, 给好友的物品, 给好友的摩尔豆]
func remote_action(action: String, who: String) -> Array:
	match action:
		"water":
			if crop != "" and growth < 1.0 and water_time <= 0.0:
				water_time = 20.0
				GameState.toast.emit("%s 帮你的%s浇了水" % [who, GameState.item_name(crop)])
				return ["帮忙浇水成功！+2 摩尔豆", "", 2]
		"bug":
			if bug:
				bug = false
				GameState.toast.emit("%s 帮你的农场抓走了害虫" % who)
				return ["帮忙抓虫成功！+3 摩尔豆", "", 3]
		"pick":
			if crop != "" and growth >= 1.0 and not picked:
				picked = true
				GameState.toast.emit("%s 从你的农场摘走了一个%s" % [who, GameState.item_name(crop)])
				return ["顺手摘了一个%s~" % GameState.item_name(crop), crop, 0]
	return ["手慢了一步，这块地的情况已经变了", "", 0]


# ---------- 绘制 ----------

func _draw() -> void:
	var s: Dictionary = remote if remote != null else get_state()
	var c_crop: String = s["crop"]
	var c_growth: float = s["growth"]
	var c_water: float = s["water_time"]
	var soil := Color(0.45, 0.3, 0.18) if c_water <= 0.0 else Color(0.32, 0.21, 0.13)
	D.ell(self, Vector2(0, 4), Vector2(46, 30), Color(0, 0, 0, 0.1))
	draw_rect(Rect2(-40, -26, 80, 52), soil.darkened(0.25))
	draw_rect(Rect2(-37, -23, 74, 46), soil)
	for i in 3:
		draw_line(Vector2(-32, -12 + i * 12), Vector2(32, -12 + i * 12), soil.darkened(0.25), 2.0)
	if c_crop == "":
		return
	var col: Color = GameState.CROPS[c_crop]["color"]
	var leaf := Color(0.3, 0.68, 0.25)
	if c_growth < 0.33:
		draw_line(Vector2(0, 4), Vector2(0, -8), leaf, 3.0)
		D.ell(self, Vector2(-6, -10), Vector2(6, 3), leaf)
		D.ell(self, Vector2(6, -10), Vector2(6, 3), leaf)
	elif c_growth < 0.66:
		draw_line(Vector2(0, 4), Vector2(0, -22), leaf.darkened(0.1), 3.0)
		D.ell(self, Vector2(-9, -10), Vector2(9, 4), leaf)
		D.ell(self, Vector2(9, -16), Vector2(9, 4), leaf)
		D.ell(self, Vector2(-7, -22), Vector2(7, 3.5), leaf.lightened(0.1))
	elif c_growth < 1.0:
		var h := -40.0 if c_crop == "sunflower" else -28.0
		draw_line(Vector2(0, 4), Vector2(0, h), leaf.darkened(0.15), 4.0)
		D.ell(self, Vector2(-12, -8), Vector2(12, 5), leaf)
		D.ell(self, Vector2(12, -14), Vector2(12, 5), leaf)
		D.ell(self, Vector2(-10, -22), Vector2(9, 4), leaf.lightened(0.1))
		draw_circle(Vector2(0, h - 4), 7.0, leaf.lerp(col, 0.35))
	else:
		_draw_ripe(c_crop, col, leaf)
		if s["picked"]:
			D.text(self, Vector2(0, 36), "被摘过", 12, Color(1, 0.95, 0.8))
		else:
			var sz := 3.0 + sin(t * 4.0) * 2.0
			var sp := Vector2(24, -46)
			draw_line(sp + Vector2(-sz * 2, 0), sp + Vector2(sz * 2, 0), Color(1, 1, 0.7), 2.0)
			draw_line(sp + Vector2(0, -sz * 2), sp + Vector2(0, sz * 2), Color(1, 1, 0.7), 2.0)

	if c_growth < 1.0:
		draw_rect(Rect2(-30, 30, 60, 6), Color(0.25, 0.18, 0.1, 0.7))
		draw_rect(Rect2(-30, 30, 60 * c_growth, 6), Color(0.45, 0.88, 0.35))
		if c_water <= 0.0:
			var dp := Vector2(30, -44 + sin(t * 4.0) * 3.0)
			draw_circle(dp, 6.0, Color(0.3, 0.6, 1.0))
			draw_colored_polygon(PackedVector2Array([dp + Vector2(-5.2, -3), dp + Vector2(5.2, -3), dp + Vector2(0, -13)]), Color(0.3, 0.6, 1.0))
	if s["bug"]:
		var bp := Vector2(sin(t * 2.0) * 16.0, -10.0 + cos(t * 3.0) * 6.0)
		draw_circle(bp, 6.0, Color(0.85, 0.1, 0.1))
		draw_line(bp + Vector2(0, -6), bp + Vector2(0, 6), Color.BLACK, 1.5)
		draw_circle(bp + Vector2(-2.5, -1), 1.5, Color.BLACK)
		draw_circle(bp + Vector2(2.5, 2), 1.5, Color.BLACK)
		draw_circle(bp + Vector2(0, -7), 3.0, Color.BLACK)


func _draw_ripe(c_crop: String, col: Color, leaf: Color) -> void:
	match c_crop:
		"corn":
			draw_line(Vector2(0, 4), Vector2(0, -56), leaf.darkened(0.15), 4.0)
			for k in 3:
				var y := -10.0 - k * 14.0
				D.ell(self, Vector2(-10 if k % 2 == 0 else 10, y), Vector2(13, 4), leaf)
			for sx in [-1.0, 1.0]:
				var cob := Vector2(sx * 9.0, -34)
				D.ell(self, cob, Vector2(6, 13), col)
				for r in 4:
					draw_line(cob + Vector2(-5, -9 + r * 6), cob + Vector2(5, -9 + r * 6), col.darkened(0.15), 1.0)
				draw_colored_polygon(PackedVector2Array([cob + Vector2(-7, 6), cob + Vector2(7, 6), cob + Vector2(0, 16)]), leaf.lightened(0.15))
		"watermelon":
			D.ell(self, Vector2(-24, -4), Vector2(12, 5), leaf)
			D.ell(self, Vector2(24, -8), Vector2(12, 5), leaf)
			D.ell(self, Vector2(0, -12), Vector2(28, 18), col.darkened(0.1))
			for k in [-14.0, -5.0, 5.0, 14.0]:
				D.ell(self, Vector2(k, -12), Vector2(3, 16), Color(0.15, 0.4, 0.15))
			D.ell(self, Vector2(-9, -20), Vector2(9, 4), Color(1, 1, 1, 0.25))
		"carrot":
			for x in [-16.0, 0.0, 16.0]:
				for k in 3:
					draw_line(Vector2(x, -4), Vector2(x - 6 + k * 6, -26 + absf(k - 1) * 5), leaf, 3.0)
				D.ell(self, Vector2(x, -2), Vector2(7, 6), col)
		"strawberry":
			D.ell(self, Vector2(0, -14), Vector2(28, 15), leaf)
			D.ell(self, Vector2(-8, -20), Vector2(14, 8), leaf.lightened(0.12))
			for p in [Vector2(-16, -8), Vector2(0, -6), Vector2(15, -10), Vector2(-6, -22), Vector2(10, -24)]:
				draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -3), p + Vector2(6, -3), p + Vector2(0, 8)]), col)
				draw_circle(p + Vector2(0, -2), 5.5, col)
				draw_circle(p + Vector2(-2, 0), 0.9, Color(1, 0.95, 0.5))
				draw_circle(p + Vector2(2, 2), 0.9, Color(1, 0.95, 0.5))
		"pumpkin":
			D.ell(self, Vector2(-22, -6), Vector2(14, 6), leaf)
			D.ell(self, Vector2(22, -10), Vector2(14, 6), leaf)
			D.ell(self, Vector2(0, -14), Vector2(26, 18), col)
			D.ell(self, Vector2(0, -14), Vector2(11, 18), col.lightened(0.12))
			D.ring(self, Vector2(-9, -14), Vector2(12, 17), col.darkened(0.2), 1.5)
			D.ring(self, Vector2(9, -14), Vector2(12, 17), col.darkened(0.2), 1.5)
			draw_line(Vector2(0, -30), Vector2(4, -40), Color(0.4, 0.5, 0.15), 4.0)
		"sunflower":
			draw_line(Vector2(0, 4), Vector2(0, -60), leaf.darkened(0.15), 4.0)
			D.ell(self, Vector2(-11, -20), Vector2(11, 5), leaf)
			D.ell(self, Vector2(11, -32), Vector2(11, 5), leaf)
			var fc := Vector2(0, -66)
			for i in 12:
				var a := TAU * i / 12.0 + sin(t) * 0.05
				D.ell(self, fc + Vector2(cos(a), sin(a)) * 13.0, Vector2(6, 6), col)
			draw_circle(fc, 10.0, Color(0.45, 0.28, 0.1))
			draw_circle(fc + Vector2(-3, -3), 2.5, Color(0.6, 0.4, 0.15))
