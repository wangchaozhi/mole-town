extends Node
## 图鉴与成就面板（C 键）、每日签到面板。由 ui.gd 创建，ui 提供通用的面板 / 按钮工具。

var ui  # ui.gd
var collection_panel: PanelContainer
var collection_body: VBoxContainer
var signin_panel: PanelContainer
var signin_cards: HBoxContainer
var signin_button: Button
var signin_info: Label


func build() -> void:
	_build_collection()
	_build_signin()


func close() -> void:
	collection_panel.visible = false
	signin_panel.visible = false


# ---------- 图鉴与成就 ----------

func _build_collection() -> void:
	collection_panel = ui._panel()
	ui._centered(collection_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	collection_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl: Label = ui._label("图鉴与成就", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(ui._button("关闭", toggle_collection))
	v.add_child(title)
	collection_body = VBoxContainer.new()
	collection_body.add_theme_constant_override("separation", 8)
	v.add_child(collection_body)
	collection_panel.visible = false


func toggle_collection() -> void:
	collection_panel.visible = not collection_panel.visible
	if collection_panel.visible:
		_refresh_collection()


func _refresh_collection() -> void:
	for c in collection_body.get_children():
		c.queue_free()
	collection_body.add_child(ui._label("作物", 18))
	collection_body.add_child(_item_row(GameState.CROPS.keys()))
	collection_body.add_child(ui._label("钓鱼湖", 18))
	collection_body.add_child(_item_row(GameState.FISH.keys()))
	collection_body.add_child(ui._label("料理", 18))
	collection_body.add_child(_item_row(GameState.DISHES.keys()))
	collection_body.add_child(ui._label("成就（%d/%d）" % [GameState.achievements.size(), GameState.ACHIEVEMENTS.size()], 18))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for a in GameState.ACHIEVEMENTS:
		var done: bool = a["id"] in GameState.achievements
		var hb := HBoxContainer.new()
		var name_l: Label = ui._label(("✓ " if done else "○ ") + str(a["name"]), 16)
		name_l.custom_minimum_size = Vector2(150, 0)
		name_l.add_theme_color_override("font_color", Color(0.2, 0.55, 0.2) if done else Color(0.45, 0.35, 0.25))
		hb.add_child(name_l)
		var desc: Label = ui._label(str(a["desc"]), 15)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(desc)
		var prog := "已完成" if done else "%d/%d" % [mini(GameState.stat_value(a["stat"]), int(a["target"])), int(a["target"])]
		hb.add_child(ui._label(prog + "  · %d豆" % int(a["reward"]), 15))
		list.add_child(hb)
	collection_body.add_child(scroll)


func _item_row(ids: Array) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	for id in ids:
		var n := int(GameState.collection.get(id, 0))
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(96, 0)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(56, 56)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.draw.connect(_draw_item.bind(icon, id, n > 0))
		card.add_child(icon)
		var l: Label = ui._label("%s ×%d" % [GameState.item_name(id), n] if n > 0 else "？？？", 15)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(l)
		hb.add_child(card)
	return hb


## 图鉴图标：用代码画出作物 / 鱼，未获得时显示灰色剪影
func _draw_item(c: Control, id: String, known: bool) -> void:
	var D := preload("res://scripts/draw_util.gd")
	var m := c.size / 2.0
	c.draw_circle(m, 27.0, Color(1, 1, 1, 0.7))
	var gray := Color(0.6, 0.6, 0.6)
	var leaf := Color(0.3, 0.68, 0.25) if known else gray.darkened(0.1)
	var col := gray
	if known:
		if GameState.CROPS.has(id):
			col = GameState.CROPS[id]["color"]
		elif GameState.DISHES.has(id):
			col = GameState.DISHES[id]["color"]
		else:
			col = {"small_fish": Color(0.55, 0.72, 0.88), "big_fish": Color(0.3, 0.5, 0.82),
				"gold_fish": Color(1.0, 0.75, 0.15), "boot": Color(0.5, 0.35, 0.25)}[id]
	if GameState.DISHES.has(id):
		_draw_dish(c, m, id, col, known)
		if not known:
			D.text(c, m + Vector2(0, 2), "?", 22, Color(1, 1, 1))
		return
	match id:
		"corn":
			D.ell(c, m + Vector2(0, -2), Vector2(9, 18), col)
			for r in 5:
				c.draw_line(m + Vector2(-7, -12 + r * 6), m + Vector2(7, -12 + r * 6), col.darkened(0.2), 1.0)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-12, 18), m + Vector2(-2, 2), m + Vector2(0, 20)]), leaf)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(12, 18), m + Vector2(2, 2), m + Vector2(0, 20)]), leaf)
		"watermelon":
			D.ell(c, m, Vector2(20, 15), col.darkened(0.1))
			for k in [-10.0, -3.0, 4.0, 11.0]:
				D.ell(c, m + Vector2(k, 0), Vector2(2.5, 13), col.darkened(0.45) if known else gray.darkened(0.25))
		"carrot":
			for k in 3:
				c.draw_line(m + Vector2(0, -8), m + Vector2(-6 + k * 6, -20), leaf, 3.0)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-8, -8), m + Vector2(8, -8), m + Vector2(0, 18)]), col)
		"strawberry":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-12, -4), m + Vector2(12, -4), m + Vector2(0, 16)]), col)
			c.draw_circle(m + Vector2(0, -3), 11.0, col)
			D.ell(c, m + Vector2(0, -13), Vector2(9, 3), leaf)
			if known:
				for p in [Vector2(-4, 0), Vector2(4, 2), Vector2(0, 7), Vector2(-3, -6), Vector2(4, -5)]:
					c.draw_circle(m + p, 1.0, Color(1, 0.95, 0.5))
		"pumpkin":
			D.ell(c, m + Vector2(0, 3), Vector2(19, 14), col)
			D.ell(c, m + Vector2(0, 3), Vector2(7, 14), col.lightened(0.12))
			c.draw_line(m + Vector2(0, -10), m + Vector2(3, -17), leaf.darkened(0.2), 3.0)
		"sunflower":
			for i in 10:
				var a := TAU * i / 10.0
				D.ell(c, m + Vector2(cos(a), sin(a)) * 12.0, Vector2(5, 5), col)
			c.draw_circle(m, 8.0, Color(0.45, 0.28, 0.1) if known else gray.darkened(0.2))
		"boot":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-8, -16), m + Vector2(4, -16), m + Vector2(4, 4),
				m + Vector2(16, 6), m + Vector2(16, 14), m + Vector2(-8, 14)]), col)
			c.draw_line(m + Vector2(-8, 8), m + Vector2(16, 8), col.darkened(0.3), 2.0)
		_:
			var s := 1.25 if id == "big_fish" else 1.0
			D.ell(c, m + Vector2(-2, 0), Vector2(14, 8) * s, col)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(10, 0) * s, m + Vector2(20, -8) * s, m + Vector2(20, 8) * s]), col.darkened(0.15))
			c.draw_circle(m + Vector2(-9, -2) * s, 2.0, Color(0.1, 0.1, 0.1) if known else gray.darkened(0.3))
	if not known:
		D.text(c, m + Vector2(0, 2), "?", 22, Color(1, 1, 1))


# ---------- 每日签到 ----------

func _build_signin() -> void:
	signin_panel = ui._panel()
	ui._centered(signin_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	signin_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl: Label = ui._label("每日签到", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(ui._button("关闭", func(): signin_panel.visible = false))
	v.add_child(title)
	signin_cards = HBoxContainer.new()
	signin_cards.add_theme_constant_override("separation", 8)
	v.add_child(signin_cards)
	signin_info = ui._label("", 15)
	v.add_child(signin_info)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	signin_button = ui._button("签到领取", _do_signin)
	hb.add_child(signin_button)
	v.add_child(hb)
	signin_panel.visible = false


func show_signin_if_needed() -> void:
	if GameState.can_sign_in():
		_refresh_signin()
		signin_panel.visible = true


func _refresh_signin() -> void:
	for c in signin_cards.get_children():
		c.queue_free()
	var can := GameState.can_sign_in()
	var today := GameState.next_signin_day() if can else (GameState.signin_streak - 1) % 7 + 1
	for d in range(1, 8):
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		sb.set_border_width_all(2)
		var done := d < today or (d == today and not can)
		if done:
			sb.bg_color = Color(0.78, 0.92, 0.7)
			sb.border_color = Color(0.4, 0.65, 0.3)
		elif d == today:
			sb.bg_color = Color(1.0, 0.82, 0.5)
			sb.border_color = Color(0.9, 0.5, 0.1)
		else:
			sb.bg_color = Color(1, 0.95, 0.85)
			sb.border_color = Color(0.75, 0.6, 0.45)
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(76, 86)
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(cv)
		for t in ["第%d天" % d, "%d豆" % GameState.SIGNIN_REWARDS[d - 1], ("+3向日葵" if d == 7 else ""), ("✓ 已领" if done else "")]:
			if t == "":
				continue
			var l: Label = ui._label(t, 14)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(l)
		signin_cards.add_child(card)
	signin_info.text = "连续签到奖励更多，第 7 天还送向日葵种子！断签会从第 1 天重新开始。"
	signin_button.disabled = not can
	signin_button.text = "签到领取" if can else "今天已签到，明天再来~"


func _do_signin() -> void:
	var reward := GameState.sign_in()
	if reward > 0:
		Sfx.play("gift")
		ui.show_toast("签到成功！获得 %d 摩尔豆" % reward)
		if ui.player != null:
			ui.player.play_emote("happy")
	_refresh_signin()




## 料理图标：碗装的汤 / 蛋糕 / 烤玉米 / 派 / 冰沙
func _draw_dish(c: Control, m: Vector2, id: String, col: Color, known: bool) -> void:
	var D := preload("res://scripts/draw_util.gd")
	var white := Color(0.97, 0.97, 1.0) if known else Color(0.7, 0.7, 0.7)
	match id:
		"strawberry_cake":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-16, 10), m + Vector2(16, 10), m + Vector2(16, -4), m + Vector2(-16, -4)]), Color(1, 0.92, 0.8) if known else white)
			c.draw_rect(Rect2(m + Vector2(-16, -10), Vector2(32, 7)), col)
			c.draw_circle(m + Vector2(0, -14), 5.0, Color(0.9, 0.15, 0.25) if known else col.darkened(0.2))
		"grilled_corn":
			c.draw_line(m + Vector2(0, 8), m + Vector2(0, 22), Color(0.6, 0.45, 0.3), 3.0)
			D.ell(c, m + Vector2(0, -4), Vector2(9, 16), col)
			for r in 4:
				c.draw_line(m + Vector2(-7, -14 + r * 6), m + Vector2(7, -14 + r * 6), col.darkened(0.35), 1.5)
		"pumpkin_pie":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-18, 10), m + Vector2(18, 10), m + Vector2(0, -16)]), Color(0.85, 0.6, 0.35) if known else white)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-13, 6), m + Vector2(13, 6), m + Vector2(0, -10)]), col)
		"watermelon_smoothie":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-11, -12), m + Vector2(11, -12), m + Vector2(8, 16), m + Vector2(-8, 16)]), col)
			c.draw_line(m + Vector2(4, -12), m + Vector2(10, -22), Color(0.3, 0.7, 0.4), 2.5)
			D.ell(c, m + Vector2(0, -12), Vector2(11, 3), white)
		_:
			# 汤：碗 + 汤面
			D.ell(c, m + Vector2(0, -2), Vector2(18, 6), col)
			var bowl := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				bowl.append(m + Vector2(cos(a) * 18, -2 + sin(a) * 16))
			c.draw_colored_polygon(bowl, white)
			if id == "lahm_meal":
				D.heart(c, m + Vector2(0, -8), 5.0, Color(1, 0.4, 0.55) if known else col)
