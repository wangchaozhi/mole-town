extends Node2D
## 小摩尔基类：画出摩尔（标志性的红鼻子！）、走路、头顶气泡说话。

signal arrived

const D = preload("res://scripts/draw_util.gd")

var body_color := Color(0.58, 0.4, 0.27)
var display_name := ""
var hat := "none"
var speed := 200.0
var target := Vector2.ZERO
var moving := false
var facing := 1.0
var walk_t := 0.0
var world_rect := Rect2(40, 150, 2320, 1210)
var name_label: Label
var bubble: Label
var bubble_timer := 0.0
var fishing := false
var bite := false
var anim_t := 0.0


func _ready() -> void:
	target = position
	name_label = Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-60, 6)
	name_label.size = Vector2(120, 20)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.05))
	name_label.add_theme_constant_override("outline_size", 5)
	add_child(name_label)

	bubble = Label.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.95)
	sb.border_color = Color(0.55, 0.4, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	bubble.add_theme_stylebox_override("normal", sb)
	bubble.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1))
	bubble.add_theme_font_size_override("font_size", 15)
	bubble.z_index = 20
	bubble.visible = false
	add_child(bubble)


func set_display_name(n: String) -> void:
	display_name = n
	if name_label != null:
		name_label.text = n


func move_to(p: Vector2) -> void:
	target = Vector2(clampf(p.x, world_rect.position.x, world_rect.end.x),
		clampf(p.y, world_rect.position.y, world_rect.end.y))
	moving = true


func say(text: String) -> void:
	var parts := PackedStringArray()
	var s := text
	while s.length() > 14:
		parts.append(s.substr(0, 14))
		s = s.substr(14)
	parts.append(s)
	bubble.text = "\n".join(parts)
	bubble.visible = true
	bubble_timer = 3.0 + text.length() * 0.1
	bubble.reset_size()


func hit_test(p: Vector2) -> bool:
	return Rect2(position + Vector2(-28, -72), Vector2(56, 80)).has_point(p)


func _process(delta: float) -> void:
	anim_t += delta
	if moving:
		var d := target - position
		var step := speed * delta
		if absf(d.x) > 1.0:
			facing = signf(d.x)
		if d.length() <= step:
			position = target
			moving = false
			arrived.emit()
		else:
			position += d.normalized() * step
		walk_t += delta * 12.0
	else:
		walk_t = 0.0
	if bubble.visible:
		bubble_timer -= delta
		if bubble_timer <= 0.0:
			bubble.visible = false
		bubble.reset_size()
		bubble.position = Vector2(-bubble.size.x / 2.0, -100.0 - bubble.size.y)
	queue_redraw()


func _draw() -> void:
	var bob := -absf(sin(walk_t)) * 3.0
	var sw := sin(walk_t) * 4.0
	D.ell(self, Vector2.ZERO, Vector2(20, 6), Color(0, 0, 0, 0.22))
	var foot := body_color.darkened(0.3)
	D.ell(self, Vector2(-9, -3 - maxf(0.0, sw)), Vector2(7, 4), foot)
	D.ell(self, Vector2(9, -3 - maxf(0.0, -sw)), Vector2(7, 4), foot)

	var c := Vector2(0, -30 + bob)
	D.ell(self, c, Vector2(23, 29), body_color.darkened(0.35))
	D.ell(self, c, Vector2(21, 27), body_color)
	D.ell(self, c + Vector2(facing * 2.0, 8), Vector2(13, 14), Color(0.96, 0.86, 0.7))
	var hand := body_color.darkened(0.15)
	D.ell(self, c + Vector2(-20, 5 + sw * 0.5), Vector2(6, 5), hand)
	D.ell(self, c + Vector2(20, 5 - sw * 0.5), Vector2(6, 5), hand)

	var ex := facing * 3.0
	for sx in [-7.0, 7.0]:
		var e: Vector2 = c + Vector2(sx + ex, -10)
		draw_circle(e, 3.4, Color(0.08, 0.05, 0.05))
		draw_circle(e + Vector2(1, -1.2), 1.2, Color.WHITE)
	D.ell(self, c + Vector2(-13 + ex, 0), Vector2(4, 2.5), Color(1, 0.5, 0.5, 0.45))
	D.ell(self, c + Vector2(13 + ex, 0), Vector2(4, 2.5), Color(1, 0.5, 0.5, 0.45))

	# 摩尔的红鼻子
	var n := c + Vector2(facing * 5.0, -2)
	var wc := Color(0.3, 0.18, 0.1, 0.8)
	for i in 3:
		var dy := (i - 1) * 3.5
		draw_line(n + Vector2(5, dy * 0.3), n + Vector2(17, dy - 1), wc, 1.0)
		draw_line(n + Vector2(-5, dy * 0.3), n + Vector2(-17, dy - 1), wc, 1.0)
	draw_circle(n, 6.0, Color(0.88, 0.08, 0.12))
	draw_circle(n + Vector2(-1.8, -1.8), 1.8, Color(1, 0.65, 0.65))

	_draw_hat(c + Vector2(0, -24))

	if fishing:
		var hand2 := Vector2(facing * 20.0, -26.0)
		var tip := Vector2(facing * 64.0, -82.0)
		draw_line(hand2, tip, Color(0.45, 0.28, 0.12), 3.0)
		var bob_p := Vector2(facing * 100.0, 4.0 + sin(anim_t * 3.0) * 2.0)
		if bite:
			bob_p.y += 5.0 + sin(anim_t * 25.0) * 3.0
		draw_line(tip, bob_p, Color(0.95, 0.95, 0.95, 0.8), 1.0)
		draw_circle(bob_p, 4.5, Color(0.95, 0.2, 0.2))
		draw_circle(bob_p + Vector2(0, -2), 2.5, Color.WHITE)


func _draw_hat(b: Vector2) -> void:
	match hat:
		"red_cap":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				pts.append(b + Vector2(cos(a) * 16, sin(a) * 13))
			draw_colored_polygon(pts, Color(0.9, 0.15, 0.15))
			D.ell(self, b + Vector2(facing * 10.0, 0), Vector2(13, 3.5), Color(0.72, 0.1, 0.1))
			draw_circle(b + Vector2(0, -13), 3, Color.WHITE)
		"straw":
			D.ell(self, b + Vector2(0, 1), Vector2(28, 6), Color(0.9, 0.78, 0.42))
			D.ell(self, b + Vector2(0, -7), Vector2(14, 10), Color(0.96, 0.84, 0.5))
			draw_rect(Rect2(b.x - 14, b.y - 4, 28, 4), Color(0.85, 0.2, 0.2))
		"flower":
			var f := b + Vector2(12, 4)
			for i in 5:
				var a := TAU * i / 5.0
				draw_circle(f + Vector2(cos(a), sin(a)) * 5.5, 4.5, Color(1, 0.55, 0.75))
			draw_circle(f, 3.5, Color(1, 0.9, 0.3))
		"crown":
			var pts := PackedVector2Array([b + Vector2(-13, 2), b + Vector2(13, 2), b + Vector2(14, -14),
				b + Vector2(7, -6), b + Vector2(0, -17), b + Vector2(-7, -6), b + Vector2(-14, -14)])
			draw_colored_polygon(pts, Color(1, 0.82, 0.15))
			draw_circle(b + Vector2(0, -3), 3, Color(0.9, 0.1, 0.3))
