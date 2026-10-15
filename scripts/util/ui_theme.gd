extends RefCounted
## 界面主题：系统中文字体 + 暖色调的按钮 / 输入框 / 进度条样式。GameState 启动时调用 build()。

static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## 创建系统中文字体和整套界面主题（按钮、输入框、进度条、滑块）。返回 [字体, 主题]
static func build() -> Array:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC",
		"Source Han Sans SC", "WenQuanYi Micro Hei", "SimHei", "sans-serif"])

	var th := Theme.new()
	th.default_font = sf
	th.default_font_size = 17
	var border := Color(0.65, 0.38, 0.12)
	var pressed := _box(Color(0.95, 0.55, 0.2), border)
	th.set_stylebox("normal", "Button", _box(Color(1.0, 0.76, 0.38), border))
	th.set_stylebox("hover", "Button", _box(Color(1.0, 0.85, 0.55), border))
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("hover_pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", _box(Color(0.86, 0.83, 0.78), Color(0.6, 0.58, 0.55)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		th.set_color(k, "Button", Color(0.35, 0.18, 0.05))
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.48, 0.45))
	th.set_color("font_color", "Label", Color(0.33, 0.2, 0.1))
	th.set_stylebox("normal", "LineEdit", _box(Color(1, 1, 1), Color(0.7, 0.5, 0.3)))
	th.set_stylebox("focus", "LineEdit", _box(Color(1, 1, 0.94), Color(1.0, 0.6, 0.2)))
	th.set_color("font_color", "LineEdit", Color(0.3, 0.2, 0.1))
	th.set_color("font_placeholder_color", "LineEdit", Color(0.6, 0.55, 0.5))
	th.set_color("caret_color", "LineEdit", Color(0.3, 0.2, 0.1))
	var bg := _box(Color(0.85, 0.8, 0.72), Color(0.6, 0.45, 0.3))
	bg.set_content_margin_all(0)
	var fill := _box(Color(0.45, 0.82, 0.35), Color(0.3, 0.6, 0.2))
	fill.set_content_margin_all(0)
	th.set_stylebox("background", "ProgressBar", bg)
	th.set_stylebox("fill", "ProgressBar", fill)
	var track := _box(Color(0.85, 0.8, 0.72), Color(0.6, 0.45, 0.3))
	track.set_content_margin_all(3)
	var done := _box(Color(1.0, 0.65, 0.25), Color(0.65, 0.38, 0.12))
	done.set_content_margin_all(3)
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", done)
	th.set_stylebox("grabber_area_highlight", "HSlider", done)
	return [sf, th]
