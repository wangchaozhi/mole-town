extends Control
## 城堡小游戏「接果子」：30 秒内移动篮子接住掉落的果子。
## 普通果子 +1，金果子 +5，坏果子 -2。鼠标或 A/D、方向键控制。

signal finished(score: int)

const D = preload("res://scripts/util/draw_util.gd")
const DURATION := 30.0
const W := 600.0
const H := 380.0

var active := false
var time_left := 0.0
var score := 0
var basket_x := W / 2.0
var mouse_x := -1.0
var fruits: Array = []  # {pos, speed, kind}
var popups: Array = []  # [pos, text, life, color]
var spawn_timer := 0.0
var t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func start() -> void:
	active = true
	time_left = DURATION
	score = 0
	fruits.clear()
	popups.clear()
	spawn_timer = 0.5
	basket_x = W / 2.0
	mouse_x = -1.0


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm != null:
		mouse_x = mm.position.x


func _process(delta: float) -> void:
	t += delta
	if active:
		_step(delta)
	queue_redraw()


func _step(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		active = false
		finished.emit(score)
		return
	# 移动篮子：键盘优先，其次跟随鼠标
	var dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	if dir != 0.0:
		basket_x += dir * 520.0 * delta
		mouse_x = -1.0
	elif mouse_x >= 0.0:
		basket_x = move_toward(basket_x, mouse_x, 900.0 * delta)
	basket_x = clampf(basket_x, 40.0, W - 40.0)

	# 越到后面掉得越快越多
	var progress := 1.0 - time_left / DURATION
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = lerpf(0.75, 0.32, progress)
		var r := randf()
		var kind: String = "gold" if r < 0.08 else ("rotten" if r < 0.3 else ["apple", "berry", "peach"].pick_random())
		fruits.append({"pos": Vector2(randf_range(30, W - 30), -20), "speed": randf_range(150, 230) + progress * 160.0, "kind": kind})

	var basket_y := H - 46.0
	for f in fruits:
		f["pos"].y += f["speed"] * delta
		if f["pos"].y >= basket_y - 14.0 and f["pos"].y <= basket_y + 10.0 and absf(f["pos"].x - basket_x) < 42.0:
			f["caught"] = true
			var pts: int = {"gold": 5, "rotten": -2}.get(f["kind"], 1)
			score = maxi(0, score + pts)
			popups.append([f["pos"], ("+%d" % pts) if pts > 0 else str(pts), 0.8, Color(1, 0.85, 0.2) if pts > 1 else (Color(0.5, 0.35, 0.2) if pts < 0 else Color.WHITE)])
			Sfx.play("coin" if f["kind"] == "gold" else ("fail" if f["kind"] == "rotten" else "pop"))
	fruits = fruits.filter(func(f): return not f.get("caught", false) and f["pos"].y < H + 30.0)
	for p in popups:
		p[0].y -= 40.0 * delta
		p[2] -= delta
	popups = popups.filter(func(p): return p[2] > 0.0)


func _draw() -> void:
	# 背景：天空、城堡剪影、草地
	draw_rect(Rect2(0, 0, W, H), Color(0.62, 0.82, 1.0))
	draw_rect(Rect2(0, H * 0.45, W, H * 0.55), Color(0.7, 0.86, 1.0))
	var castle := Color(0.8, 0.78, 0.92)
	draw_rect(Rect2(170, 120, 260, 150), castle)
	for x in [150.0, 410.0]:
		draw_rect(Rect2(x, 80, 40, 190), castle)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 80), Vector2(x + 46, 80), Vector2(x + 20, 40)]), Color(0.55, 0.62, 0.95))
	draw_rect(Rect2(0, H - 40, W, 40), Color(0.47, 0.75, 0.35))
	for i in 3:
		var cx := fmod(t * 12.0 + i * 230.0, W + 120.0) - 60.0
		D.ell(self, Vector2(cx, 40 + i * 22), Vector2(34, 11), Color(1, 1, 1, 0.85))

	for f in fruits:
		_draw_fruit(f["pos"], f["kind"])

	# 篮子 + 小摩尔
	var bx := basket_x
	var by := H - 46.0
	var body := Color.html(GameState.body_color) if Color.html_is_valid(GameState.body_color) else Color(0.58, 0.4, 0.27)
	D.ell(self, Vector2(bx, by - 26), Vector2(18, 16), body)
	draw_circle(Vector2(bx - 6, by - 30), 2.5, Color(0.1, 0.05, 0.05))
	draw_circle(Vector2(bx + 6, by - 30), 2.5, Color(0.1, 0.05, 0.05))
	draw_circle(Vector2(bx, by - 24), 4.5, Color(0.88, 0.08, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(bx - 40, by - 12), Vector2(bx + 40, by - 12), Vector2(bx + 30, by + 14), Vector2(bx - 30, by + 14)]), Color(0.78, 0.55, 0.3))
	for k in 4:
		draw_line(Vector2(bx - 36 + k * 3, by - 6 + k * 5), Vector2(bx + 36 - k * 3, by - 6 + k * 5), Color(0.6, 0.4, 0.2), 2.0)
	draw_arc(Vector2(bx, by - 12), 40.0, PI, TAU, 16, Color(0.6, 0.4, 0.2), 3.0)

	for p in popups:
		D.text(self, p[0], p[1], 20, Color(p[3].r, p[3].g, p[3].b, clampf(p[2] / 0.4, 0.0, 1.0)))

	# 顶部信息
	draw_rect(Rect2(0, 0, W, 34), Color(0, 0, 0, 0.25))
	D.text(self, Vector2(90, 17), "得分 %d" % score, 20, Color.WHITE)
	D.text(self, Vector2(W / 2.0, 17), "最高 %d" % GameState.best_catch, 16, Color(1, 0.95, 0.7))
	D.text(self, Vector2(W - 90, 17), "剩余 %d 秒" % ceili(maxf(time_left, 0.0)), 20, Color.WHITE)


func _draw_fruit(p: Vector2, kind: String) -> void:
	match kind:
		"apple":
			draw_circle(p, 12.0, Color(0.92, 0.2, 0.2))
			draw_circle(p + Vector2(-4, -4), 3.5, Color(1, 0.6, 0.6))
			draw_line(p + Vector2(0, -11), p + Vector2(2, -17), Color(0.4, 0.25, 0.1), 2.0)
			D.ell(self, p + Vector2(6, -15), Vector2(5, 2.5), Color(0.3, 0.65, 0.25))
		"berry":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -4), p + Vector2(11, -4), p + Vector2(0, 14)]), Color(0.95, 0.2, 0.35))
			draw_circle(p + Vector2(0, -4), 10.0, Color(0.95, 0.2, 0.35))
			D.ell(self, p + Vector2(0, -13), Vector2(8, 3), Color(0.3, 0.65, 0.25))
		"peach":
			draw_circle(p, 12.0, Color(1, 0.7, 0.6))
			draw_arc(p, 8.0, -1.2, 0.6, 6, Color(0.95, 0.5, 0.45), 2.0)
			D.ell(self, p + Vector2(5, -13), Vector2(6, 3), Color(0.3, 0.65, 0.25))
		"gold":
			draw_circle(p, 18.0, Color(1, 0.9, 0.4, 0.3 + sin(t * 10.0) * 0.1))
			draw_circle(p, 12.0, Color(1, 0.82, 0.15))
			draw_circle(p + Vector2(-4, -4), 4.0, Color(1, 1, 0.8))
		"rotten":
			draw_circle(p, 12.0, Color(0.45, 0.35, 0.2))
			draw_circle(p + Vector2(4, 2), 4.0, Color(0.3, 0.25, 0.12))
			for i in 2:
				var a := t * 8.0 + i * PI
				draw_circle(p + Vector2(cos(a) * 16, -10 + sin(a) * 5), 1.8, Color(0.1, 0.1, 0.1))
