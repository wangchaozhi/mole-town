extends Node2D
## 「我的小屋」室内：放在地图右边看不到的地方（世界坐标 x≈3000），进门时镜头切过来。
## 这里只画墙、地板、窗户和地毯；床、衣柜、奖杯架、门由 spot.gd 负责互动。

const D = preload("res://scripts/draw_util.gd")
const ROOM := Rect2(3000, 200, 480, 320)  # 墙 + 地板
const VIEW := Rect2(2600, 0, 1280, 720)  # 进屋后镜头能看到的范围

var light: PointLight2D


func _ready() -> void:
	z_index = -9
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
	light.texture_scale = 2.4
	light.color = Color(1, 0.88, 0.65)
	light.position = Vector2(ROOM.get_center().x, ROOM.position.y + 70)
	add_child(light)


func _process(_delta: float) -> void:
	light.enabled = GameState.is_night()
	queue_redraw()


func _draw() -> void:
	draw_rect(VIEW.grow(400), Color(0.18, 0.12, 0.1))  # 比镜头范围大一圈，避免露出外面的草地
	var wall := Rect2(ROOM.position, Vector2(ROOM.size.x, 110))
	var floor_r := Rect2(ROOM.position + Vector2(0, 110), Vector2(ROOM.size.x, ROOM.size.y - 110))
	# 墙纸：浅粉色竖条纹
	draw_rect(wall, Color(1.0, 0.9, 0.86))
	var x := wall.position.x
	while x < wall.end.x:
		draw_rect(Rect2(x, wall.position.y, 12, wall.size.y), Color(1.0, 0.85, 0.82))
		x += 30.0
	draw_rect(Rect2(wall.position.x, wall.end.y - 10, wall.size.x, 10), Color(0.75, 0.55, 0.4))
	# 木地板
	draw_rect(floor_r, Color(0.86, 0.66, 0.44))
	var y := floor_r.position.y
	var row := 0
	while y < floor_r.end.y:
		draw_line(Vector2(floor_r.position.x, y), Vector2(floor_r.end.x, y), Color(0.72, 0.52, 0.34), 1.5)
		var off := 0.0 if row % 2 == 0 else 40.0
		var bx := floor_r.position.x + off
		while bx < floor_r.end.x:
			draw_line(Vector2(bx, y), Vector2(bx, minf(y + 26, floor_r.end.y)), Color(0.72, 0.52, 0.34), 1.0)
			bx += 80.0
		y += 26.0
		row += 1
	# 窗户：显示外面的天色
	var win := Rect2(ROOM.get_center().x - 50, ROOM.position.y + 20, 100, 64)
	var h := GameState.minutes / 60.0
	var sky := Color(0.6, 0.82, 1.0)
	if h < 5.5 or h >= 19.5:
		sky = Color(0.12, 0.15, 0.35)
	elif h >= 17.0:
		sky = Color(1.0, 0.65, 0.45)
	draw_rect(win, sky)
	if sky == Color(0.12, 0.15, 0.35):
		for s in [Vector2(14, 12), Vector2(70, 20), Vector2(40, 40), Vector2(84, 50)]:
			draw_circle(win.position + s, 1.5, Color(1, 1, 0.8))
	draw_rect(win, Color(0.55, 0.36, 0.22), false, 5.0)
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color(0.55, 0.36, 0.22), 3.0)
	draw_line(Vector2(win.position.x, win.get_center().y), Vector2(win.end.x, win.get_center().y), Color(0.55, 0.36, 0.22), 3.0)
	# 地毯
	D.ell(self, ROOM.get_center() + Vector2(0, 60), Vector2(110, 44), Color(0.85, 0.4, 0.45))
	D.ell(self, ROOM.get_center() + Vector2(0, 60), Vector2(90, 34), Color(0.95, 0.65, 0.6))
	# 门口的地垫
	draw_rect(Rect2(ROOM.get_center().x - 36, ROOM.end.y - 14, 72, 14), Color(0.55, 0.35, 0.25))
	D.text(self, ROOM.position + Vector2(ROOM.size.x / 2.0, -16), "我的小屋", 22, Color(1, 0.92, 0.8))
