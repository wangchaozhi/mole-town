extends Node2D
## 农场中间的自动洒水器（在商店「工具」里买）：每 40 秒转一圈喷水，给所有缺水的作物浇水。

const D = preload("res://scripts/draw_util.gd")
const INTERVAL := 40.0

var main = null
var timer := 5.0
var spray := 0.0  # 喷水动画剩余时间
var t := 0.0


func _process(delta: float) -> void:
	visible = GameState.has_sprinkler
	if not visible:
		return
	t += delta
	spray = maxf(0.0, spray - delta)
	timer -= delta
	if timer <= 0.0:
		timer = INTERVAL
		_water()
	queue_redraw()


func _water() -> void:
	if main == null or Net.visiting != 0:
		return
	var n := 0
	for p in main.plots:
		if p.remote == null and p.crop != "" and p.growth < 1.0 and p.water_time <= 0.0:
			p.water_time = 20.0
			n += 1
	if n > 0:
		spray = 2.5
		GameState.toast.emit("洒水器给 %d 块地浇了水" % n)


func _draw() -> void:
	D.ell(self, Vector2.ZERO, Vector2(12, 4), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(-3, -22, 6, 22), Color(0.55, 0.55, 0.6))
	draw_circle(Vector2(0, -24), 6.0, Color(0.3, 0.55, 0.9))
	var a := t * (8.0 if spray > 0.0 else 0.5)
	draw_line(Vector2(0, -24), Vector2(0, -24) + Vector2(cos(a), sin(a) * 0.4) * 10.0, Color(0.85, 0.85, 0.9), 2.0)
	if spray > 0.0:
		for i in 16:
			var ang := TAU * i / 16.0 + a
			var k := fmod(t * 1.5 + i * 0.13, 1.0)
			var p := Vector2(cos(ang) * 150.0 * k, sin(ang) * 80.0 * k - 24.0 - sin(k * PI) * 30.0)
			draw_circle(p, 2.5, Color(0.6, 0.85, 1.0, 0.8 * (1.0 - k)))
