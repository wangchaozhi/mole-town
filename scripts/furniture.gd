extends Node2D
## 小院家具：全部用代码绘制。自己院子里的家具可以点击移动 / 收起；串门时显示好友的家具（不可操作）。

const D = preload("res://scripts/draw_util.gd")

var kind := "pot"
var index := -1  # 在 GameState.home 里的下标；-1 = 好友的家具或摆放预览
var ghost := false  # 摆放预览
var valid := true  # 预览位置是否可以摆
var t := 0.0
var light: PointLight2D = null


func _ready() -> void:
	t = randf() * 10.0
	if index >= 0:
		add_to_group("interactable")
	set_process(kind in ["swing", "windmill", "campfire", "lantern", "pumpkin_lamp"])
	if kind == "campfire" or kind == "lantern" or kind == "pumpkin_lamp":
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		light = PointLight2D.new()
		light.texture = tex
		light.texture_scale = 1.3
		light.color = Color(1, 0.7, 0.35) if kind == "campfire" else Color(1, 0.88, 0.6)
		light.position = Vector2(0, -20 if kind == "campfire" else -50)
		light.enabled = false
		add_child(light)
	if ghost:
		modulate = Color(1, 1, 1, 0.6)


func _process(delta: float) -> void:
	t += delta
	if light != null:
		light.enabled = not ghost and GameState.is_night()
		if kind == "campfire":
			light.energy = 0.9 + sin(t * 9.0) * 0.12
	queue_redraw()


func set_valid(v: bool) -> void:
	valid = v
	modulate = Color(1, 1, 1, 0.6) if v else Color(1, 0.4, 0.4, 0.6)


func hit_test(p: Vector2) -> bool:
	return Rect2(position + Vector2(-32, -70), Vector2(64, 78)).has_point(p)


func get_interact_point() -> Vector2:
	return position + Vector2(0, 30)


func interact(_pl) -> void:
	get_tree().call_group("ui", "on_furniture_interact", self)


func _draw() -> void:
	D.ell(self, Vector2.ZERO, Vector2(26, 7), Color(0, 0, 0, 0.18))
	match kind:
		"pot": _pot()
		"mailbox": _mailbox()
		"table": _table()
		"bench": _bench()
		"lantern": _lantern()
		"scarecrow": _scarecrow()
		"campfire": _campfire()
		"swing": _swing()
		"lahm_house": _lahm_house()
		"windmill": _windmill()
		"trophy": _trophy()
		"sakura_bonsai": _sakura_bonsai()
		"melon_chair": _melon_chair()
		"pumpkin_lamp": _pumpkin_lamp()
		"snowman": _snowman()


func _pot() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -22), Vector2(14, -22), Vector2(10, 0), Vector2(-10, 0)]), Color(0.78, 0.42, 0.25))
	draw_rect(Rect2(-16, -26, 32, 6), Color(0.7, 0.36, 0.2))
	for p in [Vector2(-8, -36), Vector2(8, -38), Vector2(0, -46)]:
		draw_line(Vector2(0, -26), p, Color(0.3, 0.62, 0.25), 2.0)
		for k in 5:
			var a := TAU * k / 5.0
			draw_circle(p + Vector2(cos(a), sin(a)) * 4.0, 3.2, Color(1, 0.5, 0.65))
		draw_circle(p, 2.5, Color(1, 0.9, 0.3))


func _mailbox() -> void:
	draw_rect(Rect2(-3, -36, 6, 36), Color(0.5, 0.33, 0.2))
	draw_rect(Rect2(-14, -56, 28, 22), Color(0.2, 0.5, 0.85))
	draw_circle(Vector2(0, -56), 14.0, Color(0.2, 0.5, 0.85))
	draw_rect(Rect2(-10, -50, 20, 4), Color(0.12, 0.3, 0.55))
	draw_rect(Rect2(12, -66, 3, 16), Color(0.9, 0.15, 0.15))
	draw_rect(Rect2(12, -66, 10, 7), Color(0.9, 0.15, 0.15))


func _table() -> void:
	var wood := Color(0.75, 0.52, 0.32)
	draw_rect(Rect2(-3, -28, 6, 28), wood.darkened(0.2))
	draw_rect(Rect2(-12, -3, 24, 4), wood.darkened(0.2))
	D.ell(self, Vector2(0, -30), Vector2(26, 9), Color(1, 0.95, 0.95))
	D.ell(self, Vector2(0, -32), Vector2(26, 9), Color(1, 1, 1))
	for i in 8:
		var a := TAU * i / 8.0
		draw_circle(Vector2(cos(a) * 20, -32 + sin(a) * 6), 2.0, Color(1, 0.4, 0.5))
	D.ell(self, Vector2(6, -38), Vector2(6, 3), Color(0.95, 0.95, 1))
	draw_rect(Rect2(1, -46, 10, 8), Color(0.95, 0.95, 1))
	draw_arc(Vector2(12, -42), 3.0, -PI * 0.5, PI * 0.5, 6, Color(0.95, 0.95, 1), 1.5)


func _bench() -> void:
	var wood := Color(0.72, 0.48, 0.28)
	for x in [-24.0, 22.0]:
		draw_rect(Rect2(x, -18, 4, 18), Color(0.3, 0.3, 0.32))
	draw_rect(Rect2(-30, -22, 60, 7), wood)
	for i in 3:
		draw_rect(Rect2(-30, -46 + i * 8, 60, 6), wood.lightened(0.05 * i))
	draw_rect(Rect2(-28, -48, 4, 30), Color(0.3, 0.3, 0.32))
	draw_rect(Rect2(24, -48, 4, 30), Color(0.3, 0.3, 0.32))


func _lantern() -> void:
	draw_rect(Rect2(-2, -44, 4, 44), Color(0.3, 0.3, 0.32))
	var on := GameState.is_night() and not ghost
	draw_rect(Rect2(-9, -62, 18, 18), Color(1, 0.92, 0.6) if on else Color(1, 0.95, 0.8))
	draw_rect(Rect2(-9, -62, 18, 18), Color(0.3, 0.3, 0.32), false, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -62), Vector2(12, -62), Vector2(0, -72)]), Color(0.75, 0.2, 0.2))
	if on:
		draw_circle(Vector2(0, -53), 16.0, Color(1, 0.9, 0.5, 0.25))


func _scarecrow() -> void:
	draw_rect(Rect2(-2, -70, 4, 70), Color(0.55, 0.38, 0.2))
	draw_rect(Rect2(-24, -52, 48, 4), Color(0.55, 0.38, 0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -54), Vector2(14, -54), Vector2(10, -24), Vector2(-10, -24)]), Color(0.3, 0.5, 0.8))
	for x in [-24.0, 24.0]:
		draw_line(Vector2(x, -50), Vector2(x + signf(x) * 5, -44), Color(0.95, 0.85, 0.4), 2.0)
	draw_circle(Vector2(0, -64), 10.0, Color(0.95, 0.88, 0.65))
	draw_line(Vector2(-4, -66), Vector2(-2, -64), Color(0.2, 0.2, 0.2), 2.0)
	draw_line(Vector2(4, -66), Vector2(2, -64), Color(0.2, 0.2, 0.2), 2.0)
	draw_arc(Vector2(0, -62), 4.0, 0.3, PI - 0.3, 6, Color(0.6, 0.2, 0.2), 1.5)
	D.ell(self, Vector2(0, -73), Vector2(17, 4), Color(0.92, 0.78, 0.4))
	D.ell(self, Vector2(0, -78), Vector2(9, 6), Color(0.95, 0.82, 0.45))


func _campfire() -> void:
	var log_col := Color(0.45, 0.28, 0.15)
	draw_line(Vector2(-16, -2), Vector2(14, -8), log_col, 6.0)
	draw_line(Vector2(-14, -8), Vector2(16, -2), log_col.darkened(0.15), 6.0)
	for i in 6:
		var a := TAU * i / 6.0
		draw_circle(Vector2(cos(a) * 20, -2 + sin(a) * 6), 4.0, Color(0.55, 0.55, 0.58))
	var f := sin(t * 11.0) * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -6), Vector2(12, -6), Vector2(4 + f, -26), Vector2(0, -36 - f), Vector2(-5 - f, -24)]), Color(1, 0.5, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(2, -18), Vector2(0 + f * 0.5, -26), Vector2(-3, -16)]), Color(1, 0.9, 0.3))
	for i in 3:
		var ph := fmod(t * 0.8 + i / 3.0, 1.0)
		draw_circle(Vector2(sin(ph * 9.0 + i) * 6, -34 - ph * 40), 1.6, Color(1, 0.7, 0.3, 1.0 - ph))


func _swing() -> void:
	var frame := Color(0.55, 0.36, 0.2)
	draw_line(Vector2(-30, 0), Vector2(-20, -80), frame, 5.0)
	draw_line(Vector2(30, 0), Vector2(20, -80), frame, 5.0)
	draw_line(Vector2(-24, -80), Vector2(24, -80), frame, 5.0)
	var sw := sin(t * 2.2) * 0.35
	var top := Vector2(0, -80)
	var seat := top + Vector2(sin(sw), cos(sw)) * 58.0
	for sx in [-10.0, 10.0]:
		draw_line(top + Vector2(sx, 0), seat + Vector2(sx, 0), Color(0.85, 0.8, 0.65), 1.5)
	draw_rect(Rect2(seat.x - 14, seat.y - 3, 28, 6), Color(0.9, 0.35, 0.35))


func _lahm_house() -> void:
	var pink := Color(1.0, 0.72, 0.82)
	draw_rect(Rect2(-26, -30, 52, 30), pink)
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(Vector2(cos(a) * 30, -30 + sin(a) * 26))
	draw_colored_polygon(pts, Color(0.95, 0.45, 0.6))
	draw_circle(Vector2(0, -12), 11.0, Color(0.55, 0.25, 0.35))
	draw_rect(Rect2(-11, -12, 22, 12), Color(0.55, 0.25, 0.35))
	D.heart(self, Vector2(0, -44), 6.0, Color(1, 0.95, 0.4))


func _windmill() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(9, -78), Vector2(-9, -78)]), Color(0.95, 0.92, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -78), Vector2(12, -78), Vector2(0, -94)]), Color(0.8, 0.3, 0.25))
	draw_rect(Rect2(-6, -22, 12, 22), Color(0.55, 0.36, 0.2))
	var hub := Vector2(0, -74)
	for i in 4:
		var a := t * 1.2 + TAU * i / 4.0
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([hub + dir * 6, hub + dir * 44, hub + dir * 44 + side * 10, hub + dir * 10 + side * 10]), Color(0.95, 0.95, 0.95))
		draw_line(hub, hub + dir * 44, Color(0.5, 0.35, 0.2), 2.0)
	draw_circle(hub, 4.0, Color(0.4, 0.3, 0.2))


func _trophy() -> void:
	draw_rect(Rect2(-18, -16, 36, 16), Color(0.5, 0.35, 0.25))
	draw_rect(Rect2(-12, -26, 24, 10), Color(0.6, 0.45, 0.3))
	var gold := Color(1, 0.8, 0.2)
	draw_rect(Rect2(-4, -40, 8, 14), gold.darkened(0.1))
	var cup := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		cup.append(Vector2(cos(a) * 18, -54 + sin(a) * 16))
	cup.append(Vector2(-18, -66))
	cup.append(Vector2(18, -66))
	draw_colored_polygon(cup, gold)
	draw_arc(Vector2(-18, -56), 7.0, PI * 0.5, PI * 1.5, 8, gold, 3.0)
	draw_arc(Vector2(18, -56), 7.0, -PI * 0.5, PI * 0.5, 8, gold, 3.0)
	draw_circle(Vector2(-6, -58), 3.0, Color(1, 1, 0.8, 0.8))
	D.text(self, Vector2(0, -72), "★", 14, Color(1, 0.95, 0.6))


func _sakura_bonsai() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -16), Vector2(18, -16), Vector2(13, 0), Vector2(-13, 0)]), Color(0.45, 0.55, 0.75))
	draw_rect(Rect2(-20, -20, 40, 5), Color(0.38, 0.48, 0.68))
	draw_line(Vector2(0, -20), Vector2(-4, -40), Color(0.45, 0.3, 0.2), 4.0)
	draw_line(Vector2(-4, -40), Vector2(10, -52), Color(0.45, 0.3, 0.2), 3.0)
	for p in [Vector2(-12, -48), Vector2(4, -58), Vector2(16, -50), Vector2(-2, -44), Vector2(10, -40)]:
		draw_circle(p, 9.0, Color(1, 0.75, 0.85))
	for p in [Vector2(-8, -54), Vector2(12, -56), Vector2(4, -46)]:
		draw_circle(p, 3.0, Color(1, 0.55, 0.7))


func _melon_chair() -> void:
	var red := Color(0.95, 0.35, 0.4)
	draw_colored_polygon(PackedVector2Array([Vector2(-30, -8), Vector2(26, -8), Vector2(32, -40), Vector2(20, -40), Vector2(16, -18), Vector2(-30, -18)]), Color(0.3, 0.65, 0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-28, -11), Vector2(24, -11), Vector2(29, -37), Vector2(22, -37), Vector2(18, -15), Vector2(-28, -15)]), red)
	for x in [-20.0, -8.0, 4.0]:
		draw_circle(Vector2(x, -13), 1.5, Color(0.15, 0.1, 0.1))
	draw_rect(Rect2(-28, -8, 4, 8), Color(0.4, 0.3, 0.2))
	draw_rect(Rect2(20, -8, 4, 8), Color(0.4, 0.3, 0.2))


func _pumpkin_lamp() -> void:
	var orange := Color(1.0, 0.55, 0.1)
	D.ell(self, Vector2(0, -18), Vector2(22, 17), orange)
	D.ell(self, Vector2(0, -18), Vector2(9, 17), orange.lightened(0.1))
	draw_line(Vector2(0, -35), Vector2(4, -44), Color(0.35, 0.45, 0.15), 4.0)
	var glow := Color(1, 0.95, 0.4) if GameState.is_night() and not ghost else Color(0.35, 0.18, 0.05)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -24), Vector2(-4, -24), Vector2(-8, -16)]), glow)
	draw_colored_polygon(PackedVector2Array([Vector2(4, -24), Vector2(12, -24), Vector2(8, -16)]), glow)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(6, -5), Vector2(0, -8), Vector2(-6, -5)]), glow)


func _snowman() -> void:
	draw_circle(Vector2(0, -16), 18.0, Color(0.97, 0.98, 1.0))
	draw_circle(Vector2(0, -44), 13.0, Color(0.97, 0.98, 1.0))
	draw_circle(Vector2(-4, -47), 1.8, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(4, -47), 1.8, Color(0.1, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -44), Vector2(0, -40), Vector2(12, -42)]), Color(1, 0.55, 0.15))
	draw_rect(Rect2(-14, -36, 28, 5), Color(0.85, 0.2, 0.2))
	draw_rect(Rect2(-10, -66, 20, 12), Color(0.2, 0.2, 0.25))
	draw_rect(Rect2(-14, -56, 28, 4), Color(0.2, 0.2, 0.25))
	for y in [-24.0, -14.0]:
		draw_circle(Vector2(0, y), 2.0, Color(0.2, 0.2, 0.25))
