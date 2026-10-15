extends Node
## 信箱界面：列出收到的信（新的在上面），打开信件可以收下附带的礼物。由 ui.gd 创建。

var ui  # ui.gd
var panel: PanelContainer
var list: VBoxContainer


func build() -> void:
	panel = ui._panel()
	ui._centered(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := HBoxContainer.new()
	var tl: Label = ui._label("我的信箱", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(ui._button("关闭", close))
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	v.add_child(scroll)
	panel.visible = false
	GameState.mail_changed.connect(func():
		if panel.visible:
			refresh())


func open() -> void:
	ui.close_popups()
	refresh()
	panel.visible = true


func close() -> void:
	panel.visible = false


func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	if GameState.mail.is_empty():
		list.add_child(ui._label("信箱空空的。小镇的朋友们偶尔会给你寄信哦~", 16))
		return
	for i in range(GameState.mail.size() - 1, -1, -1):
		var m: Dictionary = GameState.mail[i]
		var note := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 0.97, 0.85) if not m["read"] else Color(0.93, 0.91, 0.87)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.9, 0.5, 0.2) if not m["read"] else Color(0.75, 0.7, 0.65)
		note.add_theme_stylebox_override("panel", sb)
		var hb := HBoxContainer.new()
		note.add_child(hb)
		var gift := ""
		if str(m["gift"]) != "" and int(m["n"]) > 0:
			gift = "  【附礼物】" if not m["read"] else "  （礼物已收下）"
		var l: Label = ui._label("%s来自 %s（第%d天）%s\n%s" % ["✉ " if not m["read"] else "", m["from"], int(m["day"]), gift, m["text"]], 15)
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size = Vector2(430, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		if not m["read"]:
			hb.add_child(ui._button("拆信", _open_letter.bind(i)))
		list.add_child(note)


func _open_letter(i: int) -> void:
	var got := GameState.open_mail(i)
	Sfx.play("gift" if got != "" else "pop")
	if got != "":
		ui.show_toast("收到了 %s！" % got)
	refresh()
