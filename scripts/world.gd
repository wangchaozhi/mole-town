extends Node2D
## 地面：草地、小路、广场、农田土地。

const W := 2400.0
const H := 1400.0
const PLAZA := Vector2(1200, 720)
const PATHS := [
	[Vector2(1200, 720), Vector2(1200, 340)],
	[Vector2(1200, 720), Vector2(900, 600), Vector2(650, 500)],
	[Vector2(1200, 720), Vector2(1500, 600), Vector2(1750, 500)],
	[Vector2(1200, 720), Vector2(1450, 980), Vector2(1840, 1270)],
	[Vector2(1200, 720), Vector2(920, 900), Vector2(780, 1010)],
]

var tufts: Array = []
var flowers: Array = []


func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 900:
		tufts.append(Vector2(rng.randf() * W, rng.randf() * H))
	var cols := [Color(1, 1, 1), Color(1, 0.85, 0.2), Color(1, 0.55, 0.7), Color(0.7, 0.6, 1)]
	for i in 260:
		flowers.append([Vector2(rng.randf() * W, rng.randf() * H), cols[rng.randi() % cols.size()]])


func _draw() -> void:
	var grass := Color(0.47, 0.75, 0.35)
	draw_rect(Rect2(-400, -400, W + 800, H + 800), grass)
	var dark := grass.darkened(0.15)
	for p in tufts:
		draw_line(p, p + Vector2(-3, -7), dark, 2.0)
		draw_line(p + Vector2(4, 0), p + Vector2(6, -8), dark, 2.0)
	for f in flowers:
		draw_circle(f[0], 3.0, f[1])
		draw_circle(f[0], 1.2, Color(1, 0.9, 0.3))

	# 小院：浅色草坪 + 石板小路
	var yard := Rect2(1110, 1060, 360, 260)
	draw_rect(yard.grow(6), Color(0.38, 0.62, 0.3))
	draw_rect(yard, Color(0.56, 0.82, 0.42))
	for yy in range(0, 260, 40):
		for xx in range(0, 360, 40):
			if (xx + yy) / 40 % 2 == 0:
				draw_rect(Rect2(1110 + xx, 1060 + yy, 40, 40), Color(0.6, 0.85, 0.46))
	for i in 6:
		D_ell(Vector2(1290, 1080 + i * 44), Vector2(16, 9), Color(0.82, 0.8, 0.75))
	draw_rect(Rect2(1590, 870, 520, 325), Color(0.6, 0.46, 0.3))
	draw_rect(Rect2(1590, 870, 520, 325), Color(0.5, 0.38, 0.24), false, 4.0)

	var edge := Color(0.82, 0.7, 0.46)
	var sand := Color(0.94, 0.85, 0.62)
	for path in PATHS:
		draw_polyline(PackedVector2Array(path), edge, 72.0)
		for pt in path:
			draw_circle(pt, 36.0, edge)
	for path in PATHS:
		draw_polyline(PackedVector2Array(path), sand, 60.0)
		for pt in path:
			draw_circle(pt, 30.0, sand)

	draw_circle(PLAZA, 215.0, Color(0.74, 0.7, 0.64))
	draw_circle(PLAZA, 205.0, Color(0.9, 0.87, 0.82))
	for r in [70.0, 120.0, 165.0]:
		draw_arc(PLAZA, r, 0.0, TAU, 72, Color(0.78, 0.74, 0.68), 3.0)
	for i in 24:
		var a := TAU * i / 24.0
		draw_line(PLAZA + Vector2(cos(a), sin(a)) * 70.0, PLAZA + Vector2(cos(a), sin(a)) * 205.0, Color(0.82, 0.78, 0.72), 2.0)


func D_ell(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
