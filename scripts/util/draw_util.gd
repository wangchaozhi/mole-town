extends RefCounted
## 绘图小工具：所有美术都用代码画，不需要任何图片资源。


static func ell(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, seg: int = 24) -> void:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


static func ring(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, width: float = 2.0, seg: int = 32) -> void:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_polyline(pts, col, width)


static func text(ci: CanvasItem, center: Vector2, s: String, fs: int, col: Color) -> void:
	var f: Font = ThemeDB.fallback_font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(f, center + Vector2(-w / 2.0, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func heart(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-s * 0.5, 0), s * 0.55, col)
	ci.draw_circle(c + Vector2(s * 0.5, 0), s * 0.55, col)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 1.02, s * 0.15), c + Vector2(s * 1.02, s * 0.15), c + Vector2(0, s * 1.25)
	]), col)
