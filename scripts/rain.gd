extends CanvasLayer
## 下雨效果：屏幕空间的雨丝和地面小水花，随天气淡入淡出。

var amount := 0.0  # 0 = 晴天，1 = 大雨
var drops: Array = []  # [位置, 速度, 长度]
var splashes: Array = []  # [位置, 剩余时间]
var canvas: Node2D


func _ready() -> void:
	layer = 1
	canvas = Node2D.new()
	canvas.draw.connect(_draw_rain)
	add_child(canvas)
	for i in 160:
		drops.append(_new_drop(true))


func _new_drop(anywhere: bool) -> Array:
	var vs := get_viewport().get_visible_rect().size
	var y := randf() * vs.y if anywhere else -randf_range(10, 120)
	return [Vector2(randf() * (vs.x + 200) - 100, y), randf_range(700, 950), randf_range(12, 22)]


func _process(delta: float) -> void:
	amount = move_toward(amount, 1.0 if GameState.raining else 0.0, delta * 0.5)
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
