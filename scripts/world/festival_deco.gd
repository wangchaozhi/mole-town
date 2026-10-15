extends Node2D
## 节日装饰：节日当天在广场四盏路灯之间挂上彩旗，中间挂节日横幅。

const D = preload("res://scripts/util/draw_util.gd")
const CORNERS := [Vector2(1030, 440), Vector2(1370, 440), Vector2(1370, 770), Vector2(1030, 770)]
const FLAG_COLORS := [Color(0.95, 0.3, 0.3), Color(1, 0.8, 0.2), Color(0.35, 0.7, 0.95), Color(0.5, 0.85, 0.4), Color(0.95, 0.5, 0.8)]

var t := 0.0
var current := ""


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	t += delta
	var f := GameState.festival()
	visible = f != ""
	if visible:
		current = f
		queue_redraw()


func _draw() -> void:
	for i in 4:
		var a: Vector2 = CORNERS[i]
		var b: Vector2 = CORNERS[(i + 1) % 4]
		var pts := PackedVector2Array()
		var n := 14
		for k in n + 1:
			var s := float(k) / n
			pts.append(a.lerp(b, s) + Vector2(0, sin(s * PI) * 28.0))
		draw_polyline(pts, Color(0.4, 0.3, 0.2), 1.5)
		for k in range(1, n):
			var p: Vector2 = pts[k]
			var sway := sin(t * 3.0 + k + i) * 2.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 0), p + Vector2(6, 0), p + Vector2(sway, 14)]), FLAG_COLORS[(k + i) % FLAG_COLORS.size()])
	var title := "钓鱼大赛" if current == "fishing" else "丰收节"
	var c := Vector2(1200, 478)
	draw_rect(Rect2(c + Vector2(-70, -18), Vector2(140, 36)), Color(0.85, 0.2, 0.2))
	draw_rect(Rect2(c + Vector2(-70, -18), Vector2(140, 36)), Color(1, 0.85, 0.3), false, 3.0)
	D.text(self, c, title, 22, Color(1, 0.95, 0.7))
