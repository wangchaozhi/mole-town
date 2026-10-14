extends Node2D
## 广场留言板：点击查看和发布留言。联机时显示房主那边的留言板，所有人都能看到。

const D = preload("res://scripts/draw_util.gd")


func _ready() -> void:
	add_to_group("interactable")


func hit_test(p: Vector2) -> bool:
	return Rect2(position + Vector2(-50, -100), Vector2(100, 104)).has_point(p)


func get_interact_point() -> Vector2:
	return position + Vector2(0, 36)


func interact(_pl) -> void:
	get_tree().call_group("ui", "open_board")


func _draw() -> void:
	var wood := Color(0.62, 0.42, 0.24)
	D.ell(self, Vector2.ZERO, Vector2(44, 8), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(-40, -40, 6, 40), wood)
	draw_rect(Rect2(34, -40, 6, 40), wood)
	draw_rect(Rect2(-46, -96, 92, 60), wood)
	draw_rect(Rect2(-42, -92, 84, 52), Color(0.85, 0.66, 0.42))
	# 贴着的小纸条
	var notes := [[Vector2(-34, -86), Color(1, 0.95, 0.6)], [Vector2(-6, -82), Color(0.75, 0.9, 1)], [Vector2(16, -88), Color(1, 0.8, 0.85)], [Vector2(-22, -62), Color(0.8, 1, 0.8)], [Vector2(8, -60), Color(1, 1, 1)]]
	for n in notes:
		var p: Vector2 = n[0]
		draw_rect(Rect2(p, Vector2(20, 18)), n[1])
		draw_circle(p + Vector2(10, 2), 2.0, Color(0.85, 0.15, 0.15))
		draw_line(p + Vector2(3, 8), p + Vector2(17, 8), Color(0.5, 0.5, 0.5), 1.0)
		draw_line(p + Vector2(3, 12), p + Vector2(13, 12), Color(0.5, 0.5, 0.5), 1.0)
	draw_rect(Rect2(-30, -112, 60, 18), wood.darkened(0.15))
	D.text(self, Vector2(0, -103), "留言板", 13, Color(1, 0.95, 0.8))
