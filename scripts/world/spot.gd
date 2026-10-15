extends Node2D
## 小屋相关的互动点：屋外的门、屋里的出口、床、衣柜、奖杯架。互动交给主场景处理。

const D = preload("res://scripts/util/draw_util.gd")

var kind := "home_door"


func _ready() -> void:
	add_to_group("interactable")
	if kind == "mailbox":
		GameState.mail_changed.connect(queue_redraw)


func hit_test(p: Vector2) -> bool:
	var r: Rect2 = {
		"home_door": Rect2(-30, -70, 60, 72),
		"exit_door": Rect2(-40, -30, 80, 36),
		"castle_exit": Rect2(-50, -30, 100, 36),
		"bed": Rect2(-50, -60, 100, 66),
		"wardrobe": Rect2(-34, -110, 68, 112),
		"shelf": Rect2(-44, -100, 88, 80),
		"mailbox": Rect2(-20, -64, 40, 66),
	}[kind]
	return Rect2(position + r.position, r.size).has_point(p)


func get_interact_point() -> Vector2:
	return position + (Vector2(0, 30) if kind == "home_door" else Vector2(0, 26))


func interact(_pl) -> void:
	get_tree().current_scene.home_action(kind)


func _draw() -> void:
	match kind:
		"bed":
			draw_rect(Rect2(-50, -46, 100, 46), Color(0.6, 0.4, 0.28))
			draw_rect(Rect2(-50, -60, 14, 60), Color(0.5, 0.32, 0.22))
			draw_rect(Rect2(-36, -44, 84, 30), Color(1, 1, 1))
			draw_rect(Rect2(-6, -44, 54, 30), Color(0.55, 0.7, 0.95))
			D.ell(self, Vector2(-22, -34), Vector2(12, 8), Color(1, 0.95, 0.95))
		"wardrobe":
			var wood := Color(0.7, 0.48, 0.3)
			draw_rect(Rect2(-34, -110, 68, 110), wood)
			draw_rect(Rect2(-34, -110, 68, 110), wood.darkened(0.3), false, 2.0)
			draw_line(Vector2(0, -104), Vector2(0, -6), wood.darkened(0.3), 2.0)
			draw_circle(Vector2(-6, -56), 3.0, Color(1, 0.85, 0.3))
			draw_circle(Vector2(6, -56), 3.0, Color(1, 0.85, 0.3))
			D.text(self, Vector2(0, -122), "衣柜", 13, Color(0.45, 0.3, 0.2))
		"shelf":
			var wood := Color(0.7, 0.48, 0.3)
			draw_rect(Rect2(-44, -98, 88, 6), wood)
			draw_rect(Rect2(-44, -62, 88, 6), wood)
			var n := GameState.achievements.size()
			for i in mini(n, 8):
				var p := Vector2(-34 + (i % 4) * 22, -104 if i < 4 else -68)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 0), p + Vector2(6, 0), p + Vector2(4, -10), p + Vector2(-4, -10)]), Color(1, 0.82, 0.2))
				draw_rect(Rect2(p + Vector2(-3, -14), Vector2(6, 4)), Color(1, 0.82, 0.2))
			D.text(self, Vector2(0, -116), "奖杯架 %d" % n, 13, Color(0.45, 0.3, 0.2))
		"mailbox":
			draw_rect(Rect2(-3, -36, 6, 36), Color(0.5, 0.33, 0.2))
			draw_rect(Rect2(-15, -58, 30, 24), Color(0.2, 0.5, 0.85))
			draw_circle(Vector2(0, -58), 15.0, Color(0.2, 0.5, 0.85))
			draw_rect(Rect2(-11, -52, 22, 4), Color(0.12, 0.3, 0.55))
			var unread := GameState.unread_mail()
			if unread > 0:
				draw_rect(Rect2(13, -76, 3, 22), Color(0.9, 0.15, 0.15))
				draw_rect(Rect2(13, -76, 12, 8), Color(0.9, 0.15, 0.15))
				D.text(self, Vector2(0, -88), "%d 封新信" % unread, 12, Color(0.85, 0.15, 0.15))
			else:
				draw_rect(Rect2(13, -50, 12, 3), Color(0.9, 0.15, 0.15))
		"exit_door", "castle_exit":
			D.text(self, Vector2(0, -2), "出门", 13, Color(1, 0.95, 0.85))
