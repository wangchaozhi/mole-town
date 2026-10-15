extends Node2D
## 场景装饰：树、房子、城堡、喷泉、路灯、栅栏、路牌……

const D = preload("res://scripts/util/draw_util.gd")

var kind := "tree"
var text := ""
var size := Vector2.ZERO
var variant := 0
var t := 0.0
var was_night := false
var light: PointLight2D = null


func _ready() -> void:
	variant = randi() % 3
	if kind in ["tree", "pine", "bush"]:
		GameState.season_changed.connect(queue_redraw)
	set_process(kind in ["fountain", "castle", "lamp", "house", "shop", "cottage"])
	if kind == "lamp":
		light = _make_light(Vector2(0, -105), 1.6, Color(1, 0.72, 0.38))
	elif kind == "house" or kind == "shop" or kind == "cottage":
		light = _make_light(Vector2(0, -70), 2.2, Color(1, 0.8, 0.5))


## 夜晚的暖色光源（在昼夜 CanvasModulate 之上照亮周围）
func _make_light(at: Vector2, scale_: float, col: Color) -> PointLight2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var l := PointLight2D.new()
	l.texture = tex
	l.texture_scale = scale_
	l.color = col
	l.energy = 0.5  # 太亮会把浅色的广场照得发白
	l.position = at
	l.enabled = false
	add_child(l)
	return l


func _process(delta: float) -> void:
	t += delta
	if kind == "fountain" or kind == "castle":
		queue_redraw()
	elif GameState.is_night() != was_night:
		was_night = GameState.is_night()
		if light != null:
			light.enabled = was_night
		queue_redraw()


func _draw() -> void:
	match kind:
		"tree": _tree()
		"pine": _pine()
		"bush": _bush()
		"flowers": _flowers()
		"lamp": _lamp()
		"sign": _sign()
		"fence": _fence()
		"vfence": _vfence()
		"house": _building(Color(1.0, 0.93, 0.8), Color(0.95, 0.45, 0.55))
		"shop": _building(Color(0.85, 0.93, 1.0), Color(0.3, 0.6, 0.85))
		"cottage":
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.68, 0.68))
			_building(Color(0.98, 0.9, 0.7), Color(0.55, 0.75, 0.4))
			draw_set_transform(Vector2.ZERO)
		"fountain": _fountain()
		"castle": _castle()


## 树叶颜色随季节变化：春嫩绿、夏深绿、秋橙红、冬灰绿（上面积雪）
func _leaf_color() -> Color:
	match GameState.season():
		0:
			return [Color(0.38, 0.72, 0.32), Color(0.45, 0.76, 0.35), Color(0.34, 0.68, 0.36)][variant]
		2:
			return [Color(0.9, 0.55, 0.18), Color(0.85, 0.32, 0.18), Color(0.92, 0.75, 0.25)][variant]
		3:
			return [Color(0.4, 0.5, 0.42), Color(0.45, 0.52, 0.44), Color(0.38, 0.48, 0.42)][variant]
	return [Color(0.25, 0.6, 0.25), Color(0.32, 0.66, 0.28), Color(0.22, 0.55, 0.32)][variant]


func _tree() -> void:
	var s := GameState.season()
	D.ell(self, Vector2.ZERO, Vector2(40, 12), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(-8, -50, 16, 50), Color(0.5, 0.33, 0.2))
	var g := _leaf_color()
	draw_circle(Vector2(-24, -62), 28.0, g.darkened(0.15))
	draw_circle(Vector2(24, -62), 28.0, g.darkened(0.15))
	draw_circle(Vector2(0, -88), 36.0, g)
	draw_circle(Vector2(-12, -100), 13.0, g.lightened(0.18))
	if s == 0:
		for p in [Vector2(-20, -70), Vector2(15, -92), Vector2(26, -60), Vector2(-4, -76), Vector2(-26, -50), Vector2(8, -108)]:
			draw_circle(p, 4.0, Color(1, 0.75, 0.82))
	elif s == 1 and variant == 2:
		for p in [Vector2(-20, -70), Vector2(15, -92), Vector2(26, -60), Vector2(-4, -76)]:
			draw_circle(p, 5.0, Color(0.95, 0.25, 0.2))
	elif s == 3:
		D.ell(self, Vector2(0, -114), Vector2(26, 10), Color(0.97, 0.98, 1.0))
		D.ell(self, Vector2(-26, -84), Vector2(18, 7), Color(0.97, 0.98, 1.0))
		D.ell(self, Vector2(26, -84), Vector2(18, 7), Color(0.97, 0.98, 1.0))


func _pine() -> void:
	D.ell(self, Vector2.ZERO, Vector2(34, 10), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(-6, -30, 12, 30), Color(0.45, 0.3, 0.18))
	var g := Color(0.18, 0.5, 0.32)
	for i in 3:
		var y := -25.0 - i * 32.0
		var w := 42.0 - i * 9.0
		draw_colored_polygon(PackedVector2Array([Vector2(-w, y), Vector2(w, y), Vector2(0, y - 55)]), g.lightened(i * 0.08))
		if GameState.season() == 3:
			draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.35, y - 35), Vector2(w * 0.35, y - 35), Vector2(0, y - 55)]), Color(0.97, 0.98, 1.0))


func _bush() -> void:
	var s := GameState.season()
	D.ell(self, Vector2.ZERO, Vector2(32, 8), Color(0, 0, 0, 0.18))
	var g := Color(0.3, 0.62, 0.3)
	if s == 2:
		g = Color(0.78, 0.45, 0.2)
	elif s == 3:
		g = Color(0.42, 0.5, 0.42)
	draw_circle(Vector2(-15, -14), 16.0, g.darkened(0.1))
	draw_circle(Vector2(15, -14), 16.0, g.darkened(0.1))
	draw_circle(Vector2(0, -24), 18.0, g)
	if s == 3:
		D.ell(self, Vector2(0, -38), Vector2(14, 6), Color(0.97, 0.98, 1.0))
	elif variant > 0 and s != 2:
		for p in [Vector2(-12, -20), Vector2(8, -30), Vector2(16, -12)]:
			draw_circle(p, 3.5, Color(1, 0.4, 0.6) if variant == 1 else Color(1, 1, 1))


func _flowers() -> void:
	D.ell(self, Vector2(0, -6), Vector2(44, 15), Color(0.5, 0.35, 0.22))
	var cols := [Color(1, 0.4, 0.5), Color(1, 0.85, 0.2), Color(0.75, 0.55, 1), Color(1, 1, 1)]
	var pts := [Vector2(-30, -6), Vector2(-15, -12), Vector2(0, -4), Vector2(15, -12), Vector2(30, -6), Vector2(-8, -16), Vector2(8, 2)]
	for i in pts.size():
		var p: Vector2 = pts[i]
		draw_line(p, p + Vector2(0, -10), Color(0.3, 0.6, 0.25), 2.0)
		var c: Color = cols[(i + variant) % cols.size()]
		for k in 5:
			var a := TAU * k / 5.0
			draw_circle(p + Vector2(0, -12) + Vector2(cos(a), sin(a)) * 3.5, 3.0, c)
		draw_circle(p + Vector2(0, -12), 2.2, Color(1, 0.9, 0.3))


func _lamp() -> void:
	D.ell(self, Vector2.ZERO, Vector2(14, 5), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(-7, -10, 14, 10), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(-3, -100, 6, 92), Color(0.3, 0.3, 0.36))
	draw_rect(Rect2(-10, -120, 20, 20), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(-7, -117, 14, 15), Color(1, 0.93, 0.55) if not was_night else Color(1, 1, 0.8))
	if was_night:
		D.ell(self, Vector2(0, 0), Vector2(70, 22), Color(1, 0.9, 0.5, 0.22))
		draw_circle(Vector2(0, -109), 48.0, Color(1, 0.9, 0.5, 0.16))
		draw_circle(Vector2(0, -109), 24.0, Color(1, 0.92, 0.6, 0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -120), Vector2(14, -120), Vector2(0, -132)]), Color(0.25, 0.25, 0.3))


func _sign() -> void:
	var wood := Color(0.82, 0.62, 0.36)
	D.ell(self, Vector2.ZERO, Vector2(14, 4), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(-4, -42, 8, 42), wood.darkened(0.3))
	draw_rect(Rect2(-58, -80, 116, 38), wood)
	draw_rect(Rect2(-58, -80, 116, 38), wood.darkened(0.4), false, 2.0)
	D.text(self, Vector2(0, -61), text, 18, Color(0.35, 0.2, 0.08))


func _fence() -> void:
	var wood := Color(0.88, 0.68, 0.42)
	draw_rect(Rect2(0, -30, size.x, 6), wood.darkened(0.12))
	draw_rect(Rect2(0, -16, size.x, 6), wood.darkened(0.12))
	var x := 0.0
	while x <= size.x + 0.1:
		draw_rect(Rect2(x - 4, -38, 8, 38), wood)
		draw_rect(Rect2(x - 4, -38, 8, 38), wood.darkened(0.35), false, 1.5)
		x += 40.0


func _vfence() -> void:
	var wood := Color(0.88, 0.68, 0.42)
	draw_rect(Rect2(-3, -size.y - 22, 6, size.y), wood.darkened(0.12))
	var y := 0.0
	while y <= size.y + 0.1:
		draw_rect(Rect2(-4, -y - 38, 8, 38), wood)
		draw_rect(Rect2(-4, -y - 38, 8, 38), wood.darkened(0.35), false, 1.5)
		y += 40.0


func _building(wall: Color, roof: Color) -> void:
	D.ell(self, Vector2(0, 0), Vector2(150, 18), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(-120, -150, 240, 150), wall)
	draw_rect(Rect2(-120, -150, 240, 150), wall.darkened(0.3), false, 3.0)
	draw_rect(Rect2(60, -268, 26, 50), Color(0.6, 0.4, 0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-145, -145), Vector2(145, -145), Vector2(95, -238), Vector2(-95, -238)]), roof)
	for i in 4:
		var y := -165.0 - i * 20.0
		draw_line(Vector2(-137 + i * 12.5, y), Vector2(137 - i * 12.5, y), roof.darkened(0.15), 2.0)
	var door := Color(0.58, 0.35, 0.2)
	draw_rect(Rect2(-24, -80, 48, 80), door)
	draw_circle(Vector2(0, -80), 24.0, door)
	draw_circle(Vector2(14, -40), 3.5, Color(1, 0.85, 0.3))
	for wx in [-95.0, 45.0]:
		draw_rect(Rect2(wx, -100, 50, 42), Color(1, 0.86, 0.45) if was_night else Color(0.65, 0.85, 1.0))
		if was_night:
			draw_rect(Rect2(wx - 8, -108, 66, 58), Color(1, 0.86, 0.45, 0.18))
		draw_rect(Rect2(wx, -100, 50, 42), wall.darkened(0.4), false, 3.0)
		draw_line(Vector2(wx + 25, -100), Vector2(wx + 25, -58), wall.darkened(0.4), 2.0)
		draw_line(Vector2(wx, -79), Vector2(wx + 50, -79), wall.darkened(0.4), 2.0)
	var wood := Color(0.85, 0.62, 0.35)
	draw_rect(Rect2(-70, -144, 140, 32), wood)
	draw_rect(Rect2(-70, -144, 140, 32), wood.darkened(0.4), false, 2.0)
	D.text(self, Vector2(0, -128), text, 19, Color(0.35, 0.18, 0.06))


func _fountain() -> void:
	var stone := Color(0.78, 0.78, 0.84)
	var water := Color(0.4, 0.68, 0.96)
	D.ell(self, Vector2(0, 0), Vector2(96, 40), Color(0, 0, 0, 0.15))
	D.ell(self, Vector2(0, -8), Vector2(92, 38), stone.darkened(0.15))
	D.ell(self, Vector2(0, -12), Vector2(90, 34), stone)
	D.ell(self, Vector2(0, -14), Vector2(78, 27), water)
	for i in 3:
		var ph := fmod(t * 0.6 + i / 3.0, 1.0)
		D.ring(self, Vector2(0, -14), Vector2(20 + ph * 55, 7 + ph * 18), Color(1, 1, 1, 0.5 * (1.0 - ph)), 1.5)
	draw_rect(Rect2(-10, -72, 20, 60), stone.darkened(0.08))
	D.ell(self, Vector2(0, -72), Vector2(32, 10), stone)
	D.ell(self, Vector2(0, -74), Vector2(25, 7), water)
	for i in 8:
		var a := TAU * i / 8.0
		for k in 6:
			var s := fmod(t * 1.1 + k / 6.0, 1.0)
			var p := Vector2(cos(a) * 62.0 * s, sin(a) * 22.0 * s - 80.0 - 70.0 * s + 136.0 * s * s)
			draw_circle(p, 2.8, Color(0.8, 0.92, 1.0, 0.85))
	draw_circle(Vector2(0, -88), 6.0, Color(0.85, 0.95, 1.0, 0.9))


func _castle() -> void:
	var wall := Color(0.92, 0.89, 0.97)
	var line := Color(0.72, 0.68, 0.82)
	var roof := Color(0.42, 0.52, 0.92)
	D.ell(self, Vector2.ZERO, Vector2(320, 30), Color(0, 0, 0, 0.15))
	for sx in [-270.0, 270.0]:
		draw_rect(Rect2(sx - 50, -300, 100, 300), wall)
		draw_rect(Rect2(sx - 50, -300, 100, 300), line, false, 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 62, -300), Vector2(sx + 62, -300), Vector2(sx, -410)]), roof)
		draw_rect(Rect2(sx - 14, -240, 28, 40), Color(0.35, 0.4, 0.6))
		draw_circle(Vector2(sx, -240), 14.0, Color(0.35, 0.4, 0.6))
	draw_rect(Rect2(-220, -220, 440, 220), wall)
	for row in range(1, 5):
		draw_line(Vector2(-220, -row * 50.0), Vector2(220, -row * 50.0), line, 2.0)
	for i in 11:
		draw_rect(Rect2(-220 + i * 42, -244, 26, 24), wall)
		draw_rect(Rect2(-220 + i * 42, -244, 26, 24), line, false, 2.0)
	draw_rect(Rect2(-220, -220, 440, 220), line, false, 3.0)
	draw_rect(Rect2(-70, -360, 140, 140), wall)
	draw_rect(Rect2(-70, -360, 140, 140), line, false, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-85, -360), Vector2(85, -360), Vector2(0, -480)]), roof.darkened(0.1))
	draw_line(Vector2(0, -480), Vector2(0, -535), Color(0.35, 0.3, 0.3), 3.0)
	var wave := sin(t * 3.0) * 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(0, -535), Vector2(40, -523 + wave), Vector2(0, -508)]), Color(0.95, 0.25, 0.3))
	draw_circle(Vector2(0, -300), 24.0, Color(1, 0.85, 0.4))
	draw_circle(Vector2(0, -300), 24.0, Color(0.8, 0.6, 0.2), false, 3.0)
	draw_circle(Vector2(0, -300), 7.0, Color(0.88, 0.08, 0.12))
	var gate := Color(0.48, 0.3, 0.16)
	draw_rect(Rect2(-55, -110, 110, 110), gate)
	draw_circle(Vector2(0, -110), 55.0, gate)
	for gx in [-30.0, 0.0, 30.0]:
		draw_line(Vector2(gx, -150), Vector2(gx, 0), gate.darkened(0.3), 3.0)
	D.text(self, Vector2(0, -196), "摩尔城堡", 24, Color(0.42, 0.32, 0.62))
