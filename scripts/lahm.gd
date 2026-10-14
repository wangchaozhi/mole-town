extends Node2D
## 拉姆：跟着你飞的小宠物。饿了会跟不上，点击它喂食。

const D = preload("res://scripts/draw_util.gd")

var player = null
var t := 0.0
var facing := 1.0
var hearts: Array = []  # [位置, 剩余时间]
var name_label: Label
var is_remote := false  # 其他玩家的拉姆：只跟随、不能喂


func _ready() -> void:
	if not is_remote:
		add_to_group("interactable")
	name_label = Label.new()
	name_label.text = "拉姆"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-40, 4)
	name_label.size = Vector2(80, 20)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.9))
	name_label.add_theme_color_override("font_outline_color", Color(0.4, 0.1, 0.2))
	name_label.add_theme_constant_override("outline_size", 4)
	add_child(name_label)


func is_hungry() -> bool:
	return not is_remote and GameState.lahm_hunger < 25.0


func _process(delta: float) -> void:
	t += delta
	if player != null:
		var goal: Vector2 = player.position + Vector2(-55.0 * player.facing, 10.0)
		var d := goal - position
		var spd := 50.0 if is_hungry() else 240.0 * clampf(d.length() / 80.0, 0.4, 2.0)
		if d.length() > 8.0:
			position += d.normalized() * minf(d.length(), spd * delta)
			if absf(d.x) > 3.0:
				facing = signf(d.x)
	for h in hearts:
		h[0] += Vector2(0, -40) * delta
		h[1] -= delta
	hearts = hearts.filter(func(h): return h[1] > 0.0)
	queue_redraw()


func hit_test(p: Vector2) -> bool:
	return (p - (position + Vector2(0, -32))).length() < 26.0


func get_interact_point() -> Vector2:
	return position + Vector2(45, 4)


func interact(_pl) -> void:
	if GameState.remove_item("lahm_fruit"):
		GameState.lahm_hunger = minf(100.0, GameState.lahm_hunger + 40.0)
		GameState.toast.emit("拉姆吃了拉姆果，好开心！")
		_burst()
		return
	for c in GameState.CROPS:
		if GameState.count(c) > 0:
			GameState.remove_item(c)
			GameState.lahm_hunger = minf(100.0, GameState.lahm_hunger + 20.0)
			GameState.toast.emit("拉姆吃了一个%s" % GameState.item_name(c))
			_burst()
			return
	GameState.toast.emit("背包里没有吃的了，去摩尔百货买拉姆果吧")


func _burst() -> void:
	for i in 5:
		hearts.append([Vector2(randf_range(-20, 20), -50 - randf_range(0, 15)), randf_range(0.8, 1.4)])


func _draw() -> void:
	var hungry := is_hungry()
	var hover := -24.0 + (0.0 if hungry else sin(t * 3.0) * 4.0)
	if hungry:
		hover = -16.0
	D.ell(self, Vector2.ZERO, Vector2(15, 5), Color(0, 0, 0, 0.2))
	var c := Vector2(0, hover - 8)
	var pink := Color(1.0, 0.66, 0.78)
	var flap := sin(t * 14.0) * 4.0 if not hungry else 0.0
	D.ell(self, c + Vector2(-19, -6), Vector2(9, 6 + flap), Color(1, 1, 1, 0.9))
	D.ell(self, c + Vector2(19, -6), Vector2(9, 6 + flap), Color(1, 1, 1, 0.9))
	draw_circle(c, 18.5, pink.darkened(0.3))
	draw_circle(c, 17.0, pink)
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
	var ant := c + Vector2(-3.0 * facing, -32)
	draw_line(c + Vector2(0, -16), ant, Color(0.5, 0.3, 0.35), 2.0)
	draw_circle(ant, 4.5, Color(1, 0.85, 0.2))
	if hungry and fmod(t, 2.0) < 1.3:
		D.text(self, c + Vector2(0, -48), "饿…", 16, Color(0.6, 0.2, 0.3))
	for h in hearts:
		D.heart(self, h[0], 6.0, Color(1, 0.3, 0.45, clampf(h[1], 0.0, 1.0)))
