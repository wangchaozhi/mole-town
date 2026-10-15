extends CanvasLayer
## 下雨效果：屏幕空间的雨丝和地面小水花，随天气淡入淡出。

var amount := 0.0  # 0 = 晴天，1 = 大雨
var drops: Array = []  # [位置, 速度, 长度]
var splashes: Array = []  # [位置, 剩余时间]
var canvas: Node2D
var rainbow_t := 0.0  # 雨停后彩虹剩余显示时间
var was_raining := false
var rainbow: Node2D
var air: Node2D  # 大风的飘落物和雾
var wind_amount := 0.0
var fog_amount := 0.0
var wind_parts: Array = []  # [位置, 速度, 相位]
var t_air := 0.0


func _ready() -> void:
	layer = 1
	canvas = Node2D.new()
	canvas.draw.connect(_draw_rain)
	add_child(canvas)
	rainbow = Node2D.new()
	rainbow.draw.connect(_draw_rainbow)
	add_child(rainbow)
	move_child(rainbow, 0)
	air = Node2D.new()
	air.draw.connect(_draw_air)
	add_child(air)
	for i in 60:
		wind_parts.append([Vector2(randf() * 1400.0, randf() * 760.0), randf_range(220.0, 420.0), randf() * TAU])
	for i in 160:
		drops.append(_new_drop(true))


func _new_drop(anywhere: bool) -> Array:
	var vs := get_viewport().get_visible_rect().size
	var y := randf() * vs.y if anywhere else -randf_range(10, 120)
	return [Vector2(randf() * (vs.x + 200) - 100, y), randf_range(700, 950), randf_range(12, 22)]


func _process(delta: float) -> void:
	_update_rainbow(delta)
	_update_air(delta)
	var cs = get_tree().current_scene
	var indoors: bool = cs != null and cs.get("inside") == true
	amount = move_toward(amount, 1.0 if GameState.raining and not indoors else 0.0, delta * (3.0 if indoors else 0.5))
	if amount <= 0.0:
		if canvas.visible:
			canvas.visible = false
		return
	canvas.visible = true
	var vs := get_viewport().get_visible_rect().size
	var snow := GameState.season() == 3
	for d in drops:
		if snow:
			d[0] += Vector2(sin(d[0].y * 0.02 + d[2]) * 30.0, d[1] * 0.12) * delta
		else:
			d[0] += Vector2(-0.25, 1.0) * d[1] * delta
		if d[0].y > vs.y or d[0].x < -100:
			if not snow and randf() < 0.3:
				splashes.append([Vector2(d[0].x, randf_range(vs.y * 0.3, vs.y)), 0.35])
			var nd := _new_drop(false)
			d[0] = nd[0]
			d[1] = nd[1]
			d[2] = nd[2]
	for s in splashes:
		s[1] -= delta
	splashes = splashes.filter(func(s): return s[1] > 0.0)
	canvas.queue_redraw()


func _draw_rain() -> void:
	var n := int(drops.size() * amount)
	for i in n:
		var d: Array = drops[i]
		var p: Vector2 = d[0]
		if GameState.season() == 3:
			canvas.draw_circle(p, 1.5 + float(d[2]) * 0.08, Color(1, 1, 1, 0.85 * amount))
			continue
		canvas.draw_line(p, p + Vector2(-0.25, 1.0) * float(d[2]), Color(0.8, 0.88, 1.0, 0.55 * amount), 1.5)
	for s in splashes:
		var k: float = s[1] / 0.35
		var c: Vector2 = s[0]
		canvas.draw_arc(c, 6.0 * (1.6 - k), PI, TAU, 8, Color(0.85, 0.92, 1.0, 0.6 * k * amount), 1.2)


# ---------- 雨后彩虹 ----------

const RAINBOW_TIME := 25.0
const RAINBOW_COLORS := [Color(1, 0.3, 0.3), Color(1, 0.6, 0.2), Color(1, 0.9, 0.3), Color(0.4, 0.85, 0.4), Color(0.35, 0.6, 1), Color(0.6, 0.4, 0.9)]


func _update_rainbow(delta: float) -> void:
	if was_raining and not GameState.raining and GameState.season() != 3 and not GameState.is_night():
		rainbow_t = RAINBOW_TIME
	was_raining = GameState.raining
	var cs = get_tree().current_scene
	var indoors: bool = cs != null and cs.get("inside") == true
	if rainbow_t > 0.0:
		rainbow_t -= delta
		rainbow.visible = not indoors
		rainbow.queue_redraw()
	elif rainbow.visible:
		rainbow.visible = false


func _draw_rainbow() -> void:
	# 淡入 3 秒、淡出 5 秒
	var a := clampf((RAINBOW_TIME - rainbow_t) / 3.0, 0.0, 1.0) * clampf(rainbow_t / 5.0, 0.0, 1.0) * 0.3
	if a <= 0.0:
		return
	var vs := get_viewport().get_visible_rect().size
	var c := Vector2(vs.x * 0.68, vs.y * 0.48)
	for i in RAINBOW_COLORS.size():
		var col: Color = RAINBOW_COLORS[i]
		col.a = a
		rainbow.draw_arc(c, 230.0 - i * 7.0, PI * 1.12, PI * 1.88, 48, col, 7.0)


# ---------- 大风 / 雾 ----------

func _update_air(delta: float) -> void:
	var cs = get_tree().current_scene
	var indoors: bool = cs != null and cs.get("inside") == true
	wind_amount = move_toward(wind_amount, 1.0 if GameState.sky == "wind" and not indoors else 0.0, delta * 0.6)
	fog_amount = move_toward(fog_amount, 1.0 if GameState.sky == "fog" and not indoors else 0.0, delta * 0.3)
	air.visible = wind_amount > 0.0 or fog_amount > 0.0
	if not air.visible:
		return
	t_air += delta
	var vs := get_viewport().get_visible_rect().size
	for p in wind_parts:
		p[0] += Vector2(p[1], sin(t_air * 2.0 + p[2]) * 40.0) * delta
		if p[0].x > vs.x + 30.0:
			p[0] = Vector2(-30.0, randf() * vs.y)
	air.queue_redraw()


func _draw_air() -> void:
	var vs := get_viewport().get_visible_rect().size
	if fog_amount > 0.0:
		air.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.95, 0.96, 1.0, 0.18 * fog_amount))
		for i in 7:
			var x := fmod(i * 230.0 + t_air * (12.0 + i * 3.0), vs.x + 400.0) - 200.0
			var y := vs.y * (0.15 + 0.12 * i) + sin(t_air * 0.3 + i) * 20.0
			air.draw_circle(Vector2(x, y), 160.0 + i * 12.0, Color(1, 1, 1, 0.1 * fog_amount))
	if wind_amount > 0.0:
		var s := GameState.season()
		var n := int(wind_parts.size() * wind_amount)
		for i in n:
			var p: Vector2 = wind_parts[i][0]
			var ph: float = wind_parts[i][2]
			match s:
				0:  # 樱花花瓣
					var a := t_air * 3.0 + ph
					air.draw_colored_polygon(PackedVector2Array([p + Vector2(cos(a), sin(a)) * 5.0, p + Vector2(-sin(a), cos(a)) * 3.0,
						p - Vector2(cos(a), sin(a)) * 5.0, p - Vector2(-sin(a), cos(a)) * 3.0]), Color(1, 0.72, 0.82, 0.9))
				1:  # 蒲公英
					air.draw_circle(p, 2.0, Color(1, 1, 1, 0.9))
					for k in 5:
						var a := TAU * k / 5.0 + ph
						air.draw_line(p, p + Vector2(cos(a), sin(a)) * 6.0, Color(1, 1, 1, 0.6), 1.0)
				2:  # 落叶
					var a := t_air * 4.0 + ph
					var col := Color(0.9, 0.5, 0.15) if i % 2 == 0 else Color(0.8, 0.3, 0.15)
					air.draw_colored_polygon(PackedVector2Array([p + Vector2(cos(a), sin(a)) * 7.0, p + Vector2(-sin(a), cos(a)) * 3.5,
						p - Vector2(cos(a), sin(a)) * 7.0, p - Vector2(-sin(a), cos(a)) * 3.5]), col)
				_:  # 风雪
					air.draw_circle(p, 2.5, Color(1, 1, 1, 0.85))
