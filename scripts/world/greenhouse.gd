extends Node2D
## 农场右边的温室（在商店「工具」里买）：玻璃屋顶和框架画在地面层，里面 4 块地由 main.gd 放置。

const D = preload("res://scripts/util/draw_util.gd")
const AREA := Rect2(2135, 880, 190, 300)


func _ready() -> void:
	z_index = -6
	GameState.tools_changed.connect(queue_redraw)


func _draw() -> void:
	if not GameState.has_greenhouse:
		# 还没买：画一块待开垦的空地和木牌
		draw_rect(AREA, Color(0.55, 0.62, 0.35, 0.5))
		draw_rect(AREA, Color(0.45, 0.35, 0.2, 0.6), false, 2.0)
		D.text(self, AREA.get_center(), "温室预留地", 16, Color(0.35, 0.25, 0.15))
		return
	# 地面：浅色石板
	draw_rect(AREA, Color(0.82, 0.86, 0.8))
	var y := AREA.position.y
	while y < AREA.end.y:
		draw_line(Vector2(AREA.position.x, y), Vector2(AREA.end.x, y), Color(0.72, 0.76, 0.7), 1.0)
		y += 30.0
	# 玻璃框架
	var frame := Color(0.95, 0.97, 1.0)
	draw_rect(AREA, frame, false, 5.0)
	draw_rect(AREA.grow(-4), Color(0.7, 0.88, 1.0, 0.12))
	for x in [AREA.position.x + 63, AREA.position.x + 127]:
		draw_line(Vector2(x, AREA.position.y), Vector2(x, AREA.end.y), Color(1, 1, 1, 0.6), 3.0)
	# 屋顶招牌
	draw_rect(Rect2(AREA.get_center().x - 40, AREA.position.y - 22, 80, 22), Color(0.4, 0.7, 0.45))
	D.text(self, Vector2(AREA.get_center().x, AREA.position.y - 11), "温室", 15, Color(1, 1, 0.9))
