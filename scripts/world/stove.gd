extends Node2D
## 广场边的小厨房：砖砌灶台和一口大锅，点击打开烹饪界面。

const D = preload("res://scripts/util/draw_util.gd")

var t := 0.0
var cooking := 0.0  # 刚做完菜时冒大团蒸汽


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("stove")


func _process(delta: float) -> void:
	t += delta
	cooking = maxf(0.0, cooking - delta)
	queue_redraw()


func hit_test(p: Vector2) -> bool:
	return Rect2(position + Vector2(-50, -96), Vector2(100, 100)).has_point(p)


func get_interact_point() -> Vector2:
	return position + Vector2(0, 36)


func interact(_pl) -> void:
	get_tree().call_group("ui", "open_kitchen")


func puff() -> void:
	cooking = 1.5


func _draw() -> void:
	D.ell(self, Vector2.ZERO, Vector2(52, 12), Color(0, 0, 0, 0.18))
	var brick := Color(0.72, 0.38, 0.28)
	draw_rect(Rect2(-44, -40, 88, 40), brick)
	for row in 3:
		var y := -40.0 + row * 13.0
		draw_line(Vector2(-44, y), Vector2(44, y), brick.darkened(0.25), 1.5)
		var off := 0.0 if row % 2 == 0 else 11.0
		var x := -44.0 + off
		while x < 44.0:
			draw_line(Vector2(x, y), Vector2(x, y + 13), brick.darkened(0.25), 1.5)
			x += 22.0
	# 灶口和火
	draw_rect(Rect2(-14, -22, 28, 18), Color(0.2, 0.12, 0.1))
	var f := sin(t * 10.0) * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -4), Vector2(9, -4), Vector2(2 + f, -16), Vector2(-3, -20 - f)]), Color(1, 0.55, 0.15))
	# 大锅
	D.ell(self, Vector2(0, -44), Vector2(36, 10), Color(0.25, 0.25, 0.28))
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -44), Vector2(34, -44), Vector2(26, -64), Vector2(-26, -64)]), Color(0.3, 0.3, 0.34))
	D.ell(self, Vector2(0, -64), Vector2(28, 7), Color(0.95, 0.75, 0.4))
	draw_line(Vector2(10, -64), Vector2(30, -90), Color(0.55, 0.36, 0.2), 3.0)
	# 蒸汽
	var n := 6 if cooking > 0.0 else 3
	for i in n:
		var ph := fmod(t * 0.5 + float(i) / n, 1.0)
		var r := 5.0 + ph * (14.0 if cooking > 0.0 else 7.0)
		draw_circle(Vector2(sin(ph * 6.0 + i) * 10.0, -70 - ph * 50.0), r, Color(1, 1, 1, 0.5 * (1.0 - ph)))
	draw_rect(Rect2(-32, -112, 64, 18), Color(0.62, 0.42, 0.24))
	D.text(self, Vector2(0, -103), "小厨房", 13, Color(1, 0.95, 0.8))
