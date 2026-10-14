extends Node2D
## 钓鱼湖：点击湖面开始钓鱼。

const D = preload("res://scripts/draw_util.gd")

var radius := Vector2(250, 140)
var t := 0.0
var player = null


func _ready() -> void:
	z_index = -5
	add_to_group("interactable")
	add_to_group("pond")


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func contains(p: Vector2) -> bool:
	var v := p - position
	return Vector2(v.x / radius.x, v.y / radius.y).length() < 1.0


func hit_test(p: Vector2) -> bool:
	return contains(p)


func edge_point(from: Vector2, margin: float = 30.0) -> Vector2:
	var v := from - position
	var a := atan2(v.y / radius.y, v.x / radius.x)
	return position + Vector2(cos(a) * (radius.x + margin), sin(a) * (radius.y + margin))


func get_interact_point() -> Vector2:
	return edge_point(player.position)


func interact(_pl) -> void:
	get_tree().call_group("ui", "start_fishing", position)


func _draw() -> void:
	D.ell(self, Vector2.ZERO, radius + Vector2(26, 18), Color(0.93, 0.85, 0.6), 48)
	D.ell(self, Vector2.ZERO, radius + Vector2(8, 5), Color(0.45, 0.72, 0.9), 48)
	D.ell(self, Vector2.ZERO, radius, Color(0.3, 0.6, 0.9), 48)
	D.ell(self, Vector2(10, 8), radius * 0.62, Color(0.24, 0.5, 0.84), 40)
	for i in 4:
		var ph := fmod(t * 0.35 + i / 4.0, 1.0)
		var centers := [Vector2(-90, -30), Vector2(80, 20), Vector2(-20, 50), Vector2(120, -50)]
		var c: Vector2 = centers[i]
		D.ring(self, c, Vector2(10 + ph * 50, 4 + ph * 20), Color(1, 1, 1, 0.5 * (1.0 - ph)), 2.0)
	for s in [Vector2(-150, -60), Vector2(40, -90), Vector2(150, 40)]:
		var o := sin(t * 1.5 + s.x) * 6.0
		draw_line(s + Vector2(o, 0), s + Vector2(o + 30, 0), Color(1, 1, 1, 0.55), 2.0)
	for lp in [Vector2(-170, 40), Vector2(160, -30), Vector2(-60, -95)]:
		var lc: Vector2 = lp + Vector2(0, sin(t + lp.x) * 1.5)
		D.ell(self, lc, Vector2(20, 11), Color(0.3, 0.65, 0.3))
		draw_colored_polygon(PackedVector2Array([lc, lc + Vector2(20, -3), lc + Vector2(20, 4)]), Color(0.24, 0.5, 0.84))
		draw_circle(lc + Vector2(-5, -3), 5.0, Color(1, 0.65, 0.8))
		draw_circle(lc + Vector2(-5, -3), 2.0, Color(1, 0.95, 0.5))
