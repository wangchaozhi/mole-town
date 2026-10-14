extends Node2D
## 城堡大厅：放在地图外（世界坐标 x≈3000, y≈1000），从城堡大门进来。
## 石砖地板、红地毯、王座、挂旗和火把；国王 NPC 和出口由 main.gd 放置。

const D = preload("res://scripts/draw_util.gd")
const ROOM := Rect2(3000, 1000, 640, 400)
const VIEW := Rect2(2680, 840, 1280, 720)

var t := 0.0


func _ready() -> void:
	z_index = -9
	for x in [ROOM.position.x + 90, ROOM.end.x - 90]:
		var l := PointLight2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		l.texture = tex
		l.texture_scale = 1.8
		l.color = Color(1, 0.7, 0.4)
		l.energy = 0.8
		l.position = Vector2(x, ROOM.position.y + 70)
		add_child(l)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var bg := Rect2(VIEW.position.x - 260, VIEW.position.y - 110, VIEW.size.x + 500, VIEW.size.y + 400)  # 上边界在 y=730，不和小屋的镜头范围重叠
	draw_rect(bg, Color(0.14, 0.11, 0.16))  # 左边界停在 x=2420，不会盖到室外
	var wall := Rect2(ROOM.position, Vector2(ROOM.size.x, 130))
	var floor_r := Rect2(ROOM.position + Vector2(0, 130), Vector2(ROOM.size.x, ROOM.size.y - 130))
	# 石墙
	draw_rect(wall, Color(0.82, 0.8, 0.9))
	var row := 0
	var y := wall.position.y
	while y < wall.end.y:
		draw_line(Vector2(wall.position.x, y), Vector2(wall.end.x, y), Color(0.68, 0.66, 0.78), 1.5)
		var x := wall.position.x + (0.0 if row % 2 == 0 else 24.0)
		while x < wall.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 22, wall.end.y)), Color(0.68, 0.66, 0.78), 1.5)
			x += 48.0
		y += 22.0
		row += 1
	# 石砖地板
	draw_rect(floor_r, Color(0.7, 0.68, 0.74))
	var fy := floor_r.position.y
	while fy < floor_r.end.y:
		draw_line(Vector2(floor_r.position.x, fy), Vector2(floor_r.end.x, fy), Color(0.6, 0.58, 0.65), 1.0)
		fy += 40.0
	var fx := floor_r.position.x
	while fx < floor_r.end.x:
		draw_line(Vector2(fx, floor_r.position.y), Vector2(fx, floor_r.end.y), Color(0.6, 0.58, 0.65), 1.0)
		fx += 40.0
	# 红地毯
	var cx := ROOM.get_center().x
	draw_rect(Rect2(cx - 50, wall.end.y - 10, 100, ROOM.end.y - wall.end.y + 10), Color(0.75, 0.15, 0.2))
	draw_rect(Rect2(cx - 50, wall.end.y - 10, 100, ROOM.end.y - wall.end.y + 10), Color(1, 0.8, 0.3), false, 3.0)
	# 挂旗
	for bx in [ROOM.position.x + 170, ROOM.end.x - 170]:
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 26, ROOM.position.y + 10), Vector2(bx + 26, ROOM.position.y + 10),
			Vector2(bx + 26, ROOM.position.y + 100), Vector2(bx, ROOM.position.y + 85), Vector2(bx - 26, ROOM.position.y + 100)]), Color(0.45, 0.3, 0.75))
		var cr := Vector2(bx, ROOM.position.y + 45)
		draw_colored_polygon(PackedVector2Array([cr + Vector2(-12, 8), cr + Vector2(12, 8), cr + Vector2(13, -6),
			cr + Vector2(6, 0), cr + Vector2(0, -10), cr + Vector2(-6, 0), cr + Vector2(-13, -6)]), Color(1, 0.82, 0.2))
	# 火把
	for tx in [ROOM.position.x + 90, ROOM.end.x - 90]:
		draw_rect(Rect2(tx - 4, ROOM.position.y + 70, 8, 30), Color(0.4, 0.28, 0.18))
		var fl := sin(t * 10.0 + tx) * 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 9, ROOM.position.y + 72), Vector2(tx + 9, ROOM.position.y + 72),
			Vector2(tx + 2 + fl, ROOM.position.y + 52), Vector2(tx - 2, ROOM.position.y + 44 - fl)]), Color(1, 0.6, 0.15))
	# 王座
	var th := Vector2(cx, wall.end.y + 30)
	draw_rect(Rect2(th + Vector2(-40, -100), Vector2(80, 100)), Color(0.95, 0.75, 0.2))
	draw_rect(Rect2(th + Vector2(-32, -92), Vector2(64, 70)), Color(0.75, 0.15, 0.25))
	draw_rect(Rect2(th + Vector2(-48, -30), Vector2(96, 30)), Color(0.95, 0.75, 0.2))
	draw_circle(th + Vector2(0, -104), 10.0, Color(1, 0.85, 0.3))
	draw_circle(th + Vector2(0, -104), 4.0, Color(0.9, 0.1, 0.2))
	D.text(self, ROOM.position + Vector2(ROOM.size.x / 2.0, -18), "摩尔城堡 · 大厅", 22, Color(1, 0.92, 0.8))
