extends Node2D
## 广场边的扭蛋机：50 摩尔豆扭一次，能扭到摩尔豆、种子、拉姆果、家具，还有扭蛋限定的帽子（兔耳朵、小黄鸡）。

const D = preload("res://scripts/util/draw_util.gd")
const BALL_COLORS := [Color(1, 0.45, 0.5), Color(0.45, 0.7, 1), Color(1, 0.85, 0.3), Color(0.5, 0.85, 0.5), Color(0.8, 0.55, 1)]

var t := 0.0
var spin := 0.0  # 摇把转动的动画时间
var balls: Array = []  # 玻璃罩里的彩球 [偏移, 颜色]


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("gacha")
	for i in 14:
		balls.append([Vector2(randf_range(-17, 17), randf_range(-10, 12)), BALL_COLORS.pick_random()])


func _process(delta: float) -> void:
	t += delta
	spin = maxf(0.0, spin - delta)
	queue_redraw()


func hit_test(p: Vector2) -> bool:
	return Rect2(position + Vector2(-32, -100), Vector2(64, 104)).has_point(p)


func get_interact_point() -> Vector2:
	return position + Vector2(0, 34)


func interact(_pl) -> void:
	get_tree().call_group("ui", "open_gacha")


func play_spin() -> void:
	spin = 1.0


func _draw() -> void:
	D.ell(self, Vector2.ZERO, Vector2(30, 8), Color(0, 0, 0, 0.18))
	var red := Color(0.88, 0.25, 0.3)
	draw_rect(Rect2(-24, -46, 48, 46), red)
	draw_rect(Rect2(-24, -46, 48, 6), red.lightened(0.2))
	draw_rect(Rect2(-10, -18, 20, 14), Color(0.25, 0.12, 0.12))  # 出口
	var crank := Vector2(14, -32)
	draw_circle(crank, 7.0, Color(0.95, 0.85, 0.3))
	var ang := spin * TAU * 2.0
	draw_line(crank, crank + Vector2(cos(ang), sin(ang)) * 9.0, Color(0.5, 0.35, 0.1), 3.0)
	# 玻璃罩和里面的彩球（转的时候跟着晃）
	var dome := Vector2(0, -70)
	var shake := sin(t * 40.0) * 2.0 * spin
	D.ell(self, dome, Vector2(26, 24), Color(0.85, 0.95, 1.0, 0.35))
	for b in balls:
		draw_circle(dome + b[0] + Vector2(shake, 0), 6.0, b[1])
	D.ring(self, dome, Vector2(26, 24), Color(0.7, 0.85, 0.95), 2.0)
	D.ell(self, dome + Vector2(-9, -10), Vector2(6, 4), Color(1, 1, 1, 0.6))
	draw_circle(dome + Vector2(0, -24), 5.0, red)
	D.text(self, Vector2(0, -52), "扭蛋", 11, Color(1, 1, 0.9))
