extends CanvasLayer
## 界面：状态栏、种子栏、聊天、对话框、商店、背包、帮助、钓鱼小游戏、提示。

const TIPS := [
	"给作物浇水，接下来一段时间生长速度会翻倍哦！",
	"听说湖里偶尔能钓到金灿灿的金鱼！",
	"拉姆饿了就飞不动了，记得喂它拉姆果。",
	"庄稼上有害虫的话，点一下就能把它抓走，还有摩尔豆奖励。",
	"晚上的摩尔小镇特别漂亮，路灯都亮起来啦。",
	"乐乐在广场上发任务，完成了奖励很丰厚！",
	"向日葵虽然长得慢，但是卖得最贵。",
	"摩尔百货有新帽子，戴上小王冠超神气！",
]

const CHAT := [
	"今天天气真好呀~", "我刚种了一片草莓！", "你的拉姆好可爱！", "一起去钓鱼吧？",
	"摩尔豆好难攒呀……", "城堡里好像住着一位大人物。", "嘿嘿~", "你好呀，新朋友！",
]

var player = null
var root: Control
var beans_label: Label
var time_label: Label
var quest_label: Label
var hunger_bar: ProgressBar
var seed_buttons := {}
var toast_label: Label
var toast_timer := 0.0
var dialog_panel: PanelContainer
var dialog_name: Label
var dialog_text: Label
var dialog_opts: HBoxContainer
var shop_panel: PanelContainer
var shop_list: VBoxContainer
var shop_beans: Label
var shop_tab := "seeds"
var bag_panel: PanelContainer
var bag_list: GridContainer
var help_panel: PanelContainer
var fish_panel: PanelContainer
var fish_label: Label
var fish_bar: Control
var chat_edit: LineEdit
var chat_log: VBoxContainer
var online_label: Label
var net_panel: PanelContainer
var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var net_status: Label
var net_list: Label

var fishing := false
var fish_phase := 0  # 0 等待 1 上钩 2 结束
var fish_timer := 0.0
var fish_marker := 0.0
var fish_dir := 1.0
var fish_zone := Vector2(0.4, 0.2)  # 起点, 宽度
var fish_speed := 1.5


func _ready() -> void:
	add_to_group("ui")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = GameState.ui_theme
	add_child(root)
	_build_hud()
	_build_seed_bar()
	_build_chat()
	_build_dialog()
	_build_shop()
	_build_bag()
	_build_fish()
	_build_net()
	_build_help()
	_build_toast()
	Net.status_changed.connect(func(_t): _refresh_net())
	Net.roster_changed.connect(_refresh_net)
	_refresh_net()
	GameState.beans_changed.connect(_refresh_hud)
	GameState.quest_changed.connect(_refresh_hud)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.toast.connect(show_toast)
	_refresh_hud()
	_refresh_seeds()


# ---------- 小工具 ----------

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.97, 0.88)
	sb.border_color = Color(0.6, 0.4, 0.22)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, fs: int = 17) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _place(c: Control, anchors: Array, offsets: Array, stop: bool = false) -> Control:
	c.anchor_left = anchors[0]
	c.anchor_top = anchors[1]
	c.anchor_right = anchors[2]
	c.anchor_bottom = anchors[3]
	c.offset_left = offsets[0]
	c.offset_top = offsets[1]
	c.offset_right = offsets[2]
	c.offset_bottom = offsets[3]
	c.mouse_filter = Control.MOUSE_FILTER_STOP if stop else Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


func _centered(p: Control) -> void:
	var cc := CenterContainer.new()
	_place(cc, [0, 0, 1, 1], [0, 0, 0, 0])
	cc.add_child(p)


# ---------- 构建界面 ----------

func _build_hud() -> void:
	var p := _panel()
	_place(p, [0, 0, 0, 0], [12, 12, 12, 12], true)
	var v := VBoxContainer.new()
	p.add_child(v)
	beans_label = _label("", 20)
	time_label = _label("", 15)
	v.add_child(beans_label)
	v.add_child(time_label)
	var hb := HBoxContainer.new()
	hb.add_child(_label("拉姆饱食度", 14))
	hunger_bar = ProgressBar.new()
	hunger_bar.custom_minimum_size = Vector2(130, 14)
	hunger_bar.show_percentage = false
	hunger_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(hunger_bar)
	v.add_child(hb)
	quest_label = _label("", 14)
	quest_label.custom_minimum_size = Vector2(260, 0)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(quest_label)
	online_label = _label("", 14)
	online_label.add_theme_color_override("font_color", Color(0.15, 0.5, 0.8))
	v.add_child(online_label)

	var top := HBoxContainer.new()
	_place(top, [1, 0, 1, 0], [-12, 12, -12, 12])
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.add_child(_button("联机 (N)", toggle_net))
	top.add_child(_button("背包 (B)", toggle_bag))
	top.add_child(_button("帮助 (H)", func(): help_panel.visible = not help_panel.visible))
	top.add_child(_button("保存", func():
		GameState.save_game()
		show_toast("游戏已保存")))


func _build_seed_bar() -> void:
	var p := _panel()
	_place(p, [0.5, 1, 0.5, 1], [0, -12, 0, -12], true)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hb := HBoxContainer.new()
	p.add_child(hb)
	hb.add_child(_label("播种：", 16))
	var group := ButtonGroup.new()
	for id in GameState.CROPS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): GameState.selected_seed = id)
		hb.add_child(b)
		seed_buttons[id] = b


func _build_chat() -> void:
	var p := _panel()
	_place(p, [0, 1, 0, 1], [12, -12, 12, -12], true)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hb := HBoxContainer.new()
	p.add_child(hb)
	chat_edit = LineEdit.new()
	chat_edit.custom_minimum_size = Vector2(200, 0)
	chat_edit.placeholder_text = "按回车聊天……"
	chat_edit.max_length = 40
	chat_edit.text_submitted.connect(_on_chat)
	hb.add_child(chat_edit)
	hb.add_child(_button("发送", func(): _on_chat(chat_edit.text)))

	# 聊天记录（聊天框上方）
	chat_log = VBoxContainer.new()
	_place(chat_log, [0, 1, 0, 1], [16, -76, 16, -76])
	chat_log.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chat_log.add_theme_constant_override("separation", 2)


func add_chat_line(who: String, text: String, col: Color = Color.WHITE) -> void:
	var l := _label(("%s：%s" % [who, text]) if who != "" else text, 15)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	chat_log.add_child(l)
	while chat_log.get_child_count() > 6:
		var old := chat_log.get_child(0)
		chat_log.remove_child(old)
		old.queue_free()
	get_tree().create_timer(30.0).timeout.connect(func():
		if is_instance_valid(l):
			l.queue_free())


func _build_net() -> void:
	net_panel = _panel()
	_centered(net_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	net_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl := _label("多人联机", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(_button("关闭", toggle_net))
	v.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	grid.add_child(_label("我的名字", 16))
	name_edit = LineEdit.new()
	name_edit.max_length = 10
	name_edit.text = GameState.player_name
	name_edit.custom_minimum_size = Vector2(300, 0)
	name_edit.text_submitted.connect(func(_t): _apply_name())
	name_edit.focus_exited.connect(_apply_name)
	grid.add_child(name_edit)
	grid.add_child(_label("房主 IP", 16))
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	grid.add_child(ip_edit)
	grid.add_child(_label("端口", 16))
	port_edit = LineEdit.new()
	port_edit.text = str(Net.DEFAULT_PORT)
	grid.add_child(port_edit)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(_button("创建房间", _on_host))
	hb.add_child(_button("加入房间", _on_join))
	hb.add_child(_button("断开", func(): Net.leave()))
	v.add_child(hb)

	net_status = _label("", 16)
	net_status.add_theme_color_override("font_color", Color(0.15, 0.45, 0.75))
	v.add_child(net_status)
	var ips := PackedStringArray()
	for a in IP.get_local_addresses():
		if "." in a and not a.begins_with("127.") and not a.begins_with("169.254."):
			ips.append(a)
	var tip := _label("本机局域网 IP：%s\n房主把这个 IP 告诉小伙伴；同一台电脑测试就填 127.0.0.1。\n第一次创建房间时 Windows 防火墙可能会询问，请允许。" % (", ".join(ips) if ips.size() > 0 else "未知"), 14)
	tip.custom_minimum_size = Vector2(440, 0)
	tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(tip)
	net_list = _label("", 15)
	net_list.custom_minimum_size = Vector2(440, 0)
	net_list.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(net_list)
	net_panel.visible = false


func toggle_net() -> void:
	net_panel.visible = not net_panel.visible
	if net_panel.visible:
		name_edit.text = GameState.player_name


func _apply_name() -> void:
	var n := name_edit.text.strip_edges().left(10)
	if n == "" or n == GameState.player_name:
		return
	GameState.player_name = n
	if player != null:
		player.set_display_name(n)
	Net.send_info()


func _on_host() -> void:
	_apply_name()
	var err := Net.host(int(port_edit.text))
	if err != "":
		show_toast(err)
	else:
		add_chat_line("", "【系统】房间已创建，等待小伙伴加入", Color(1, 0.9, 0.4))


func _on_join() -> void:
	_apply_name()
	var err := Net.join(ip_edit.text.strip_edges(), int(port_edit.text))
	if err != "":
		show_toast(err)


func _refresh_net() -> void:
	if net_status == null:
		return
	net_status.text = "状态：" + Net.status
	if Net.is_online():
		online_label.text = "联机中 · 在线 %d 人" % Net.players.size()
		var names := PackedStringArray()
		for id in Net.players:
			names.append(str(Net.players[id]["name"]) + ("（我）" if id == Net.my_id() else ""))
		net_list.text = "在线玩家：" + "、".join(names)
	else:
		online_label.text = "单机模式 · 按 N 联机"
		net_list.text = ""


func on_remote_interact(m) -> void:
	show_dialog(m.display_name, "这是来自远方的小摩尔「%s」！" % m.display_name, [
		["打招呼", _greet.bind(m)],
		["送 10 摩尔豆", _send_gift.bind(m)],
		["再见", _noop],
	])


func _greet(m) -> void:
	_on_chat("你好呀，%s！" % m.display_name)


func _send_gift(m) -> void:
	if GameState.spend_beans(10):
		Net.send_gift(m.peer_id, 10)
		show_toast("送给 %s 10 摩尔豆" % m.display_name)
		_on_chat("送你 10 摩尔豆~")
	else:
		show_toast("摩尔豆不够啦")


func _build_dialog() -> void:
	dialog_panel = _panel()
	var cc := CenterContainer.new()
	_place(cc, [0, 1, 1, 1], [0, -250, 0, -86])
	cc.add_child(dialog_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	dialog_panel.add_child(v)
	dialog_name = _label("", 20)
	dialog_name.add_theme_color_override("font_color", Color(0.85, 0.35, 0.1))
	v.add_child(dialog_name)
	dialog_text = _label("", 17)
	dialog_text.custom_minimum_size = Vector2(560, 0)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(dialog_text)
	dialog_opts = HBoxContainer.new()
	dialog_opts.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(dialog_opts)
	dialog_panel.visible = false


func _build_shop() -> void:
	shop_panel = _panel()
	_centered(shop_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	shop_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl := _label("摩尔百货", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	shop_beans = _label("", 17)
	title.add_child(shop_beans)
	title.add_child(_button("关闭", func(): shop_panel.visible = false))
	v.add_child(title)
	var tabs := HBoxContainer.new()
	for tab in [["买种子", "seeds"], ["卖东西", "sell"], ["帽子", "hats"], ["拉姆用品", "lahm"]]:
		tabs.add_child(_button(tab[0], _shop_tab.bind(tab[1])))
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 6)
	scroll.add_child(shop_list)
	v.add_child(scroll)
	shop_panel.visible = false


func _build_bag() -> void:
	bag_panel = _panel()
	_centered(bag_panel)
	var v := VBoxContainer.new()
	bag_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl := _label("我的背包", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(_button("关闭", toggle_bag))
	v.add_child(title)
	bag_list = GridContainer.new()
	bag_list.columns = 3
	bag_list.custom_minimum_size = Vector2(480, 200)
	bag_list.add_theme_constant_override("h_separation", 24)
	v.add_child(bag_list)
	bag_panel.visible = false


func _build_fish() -> void:
	fish_panel = _panel()
	_centered(fish_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	fish_panel.add_child(v)
	v.add_child(_label("钓鱼中", 22))
	fish_label = _label("", 16)
	fish_label.custom_minimum_size = Vector2(420, 0)
	fish_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(fish_label)
	fish_bar = Control.new()
	fish_bar.custom_minimum_size = Vector2(420, 34)
	fish_bar.draw.connect(_draw_fish_bar)
	v.add_child(fish_bar)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(_button("收杆！(空格)", _reel))
	hb.add_child(_button("不钓了", _stop_fishing))
	v.add_child(hb)
	fish_panel.visible = false


func _build_help() -> void:
	help_panel = _panel()
	_centered(help_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	help_panel.add_child(v)
	v.add_child(_label("欢迎来到摩尔小镇！", 26))
	var l := _label("", 16)
	l.custom_minimum_size = Vector2(600, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.text = "• 鼠标左键点击地面走路，点击人物 / 物体互动\n" \
		+ "• 开心农场（右下）：在底部选好种子，点空地播种；点作物浇水（生长加速）；成熟后点击收获；有虫子时点击抓虫\n" \
		+ "• 钓鱼湖（左下）：点击湖面开始钓鱼，鱼上钩后，红色标记在绿色区域内时按空格收杆\n" \
		+ "• 摩尔百货（右上）：找店长买种子、拉姆果、帽子，也能卖掉收获的作物和鱼\n" \
		+ "• 乐乐（广场）：领取任务，完成后回来领摩尔豆奖励\n" \
		+ "• 拉姆：你的小宠物，饿了会飞不动，点击它喂食\n" \
		+ "• 联机：按 N，一人「创建房间」，其他人填房主 IP 后「加入房间」，就能看到彼此、聊天、送摩尔豆\n" \
		+ "• 快捷键：回车 聊天，B 背包，N 联机，H 帮助，Esc 关闭窗口\n" \
		+ "• 游戏每 30 秒自动保存，离线时农场里的作物也会继续生长"
	v.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(_button("开始玩吧！", func(): help_panel.visible = false))
	v.add_child(hb)


func _build_toast() -> void:
	toast_label = Label.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.15, 0.08, 0.85)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	toast_label.add_theme_stylebox_override("normal", sb)
	toast_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	toast_label.add_theme_font_size_override("font_size", 18)
	_place(toast_label, [0.5, 0, 0.5, 0], [0, 70, 0, 70])
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.visible = false


# ---------- 刷新 ----------

func _refresh_hud() -> void:
	beans_label.text = "摩尔豆：%d" % GameState.beans
	quest_label.text = "任务：" + GameState.quest_text()
	if shop_panel != null and shop_panel.visible:
		shop_beans.text = "摩尔豆：%d  " % GameState.beans


func _refresh_seeds() -> void:
	for id in seed_buttons:
		var b: Button = seed_buttons[id]
		b.text = "%s ×%d" % [GameState.CROPS[id]["name"], GameState.count("seed_" + id)]
		b.set_pressed_no_signal(id == GameState.selected_seed)


func _on_inventory_changed() -> void:
	_refresh_seeds()
	if bag_panel.visible:
		_refresh_bag()


func _refresh_bag() -> void:
	for c in bag_list.get_children():
		c.queue_free()
	if GameState.inventory.is_empty():
		bag_list.add_child(_label("背包空空的……", 16))
	for id in GameState.inventory:
		bag_list.add_child(_label("%s ×%d" % [GameState.item_name(id), GameState.count(id)], 17))


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.reset_size()
	toast_label.offset_left = -toast_label.size.x / 2.0
	toast_label.offset_right = toast_label.size.x / 2.0
	toast_timer = 2.6


func _process(delta: float) -> void:
	time_label.text = GameState.time_text()
	hunger_bar.value = GameState.lahm_hunger
	if toast_timer > 0.0:
		toast_timer -= delta
		toast_label.modulate.a = clampf(toast_timer / 0.5, 0.0, 1.0)
		if toast_timer <= 0.0:
			toast_label.visible = false
	if fishing:
		_fish_process(delta)


# ---------- 窗口 ----------

func toggle_bag() -> void:
	bag_panel.visible = not bag_panel.visible
	if bag_panel.visible:
		_refresh_bag()


func close_popups() -> void:
	dialog_panel.visible = false
	shop_panel.visible = false
	bag_panel.visible = false


func _close_all() -> void:
	close_popups()
	help_panel.visible = false
	net_panel.visible = false
	if fishing:
		_stop_fishing()


func _input(event) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		if k.keycode == KEY_ESCAPE:
			focus.release_focus()
		return
	match k.keycode:
		KEY_SPACE:
			if fishing:
				_reel()
				get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			chat_edit.grab_focus()
			get_viewport().set_input_as_handled()
		KEY_B:
			toggle_bag()
		KEY_N:
			toggle_net()
		KEY_H:
			help_panel.visible = not help_panel.visible
		KEY_ESCAPE:
			_close_all()


# ---------- 聊天 ----------

func _on_chat(text: String) -> void:
	text = text.strip_edges()
	chat_edit.text = ""
	chat_edit.release_focus()
	if text == "" or player == null:
		return
	player.say(text)
	add_chat_line(GameState.player_name, text, Color(1, 1, 0.85))
	if Net.is_online():
		Net.send_chat(text)
	var best = null
	var best_d := 400.0
	for npc in get_tree().get_nodes_in_group("npcs"):
		var d: float = npc.position.distance_to(player.position)
		if d < best_d:
			best_d = d
			best = npc
	if best != null:
		var reply := _npc_reply(text)
		get_tree().create_timer(1.0).timeout.connect(func(): best.say(reply))


func _npc_reply(text: String) -> String:
	if "你好" in text or "嗨" in text or "hi" in text.to_lower():
		return ["你好呀！", "嗨~ 欢迎来到摩尔小镇！"].pick_random()
	if "拉姆" in text:
		return "你的拉姆好可爱！"
	if "鱼" in text:
		return "湖里偶尔能钓到金鱼哦！"
	if "种" in text or "农场" in text or "菜" in text:
		return "记得给作物浇水呀~"
	if "再见" in text or "拜拜" in text:
		return "下次见！"
	return CHAT.pick_random()


# ---------- 对话 ----------

func show_dialog(who: String, text: String, options: Array) -> void:
	dialog_name.text = who
	dialog_text.text = text
	for c in dialog_opts.get_children():
		c.queue_free()
	for o in options:
		var cb: Callable = o[1]
		dialog_opts.add_child(_button(o[0], func():
			dialog_panel.visible = false
			cb.call()))
	shop_panel.visible = false
	bag_panel.visible = false
	dialog_panel.visible = true


func _noop() -> void:
	pass


func on_npc_interact(npc) -> void:
	match npc.role:
		"lele":
			_lele_dialog(npc)
		"shop":
			show_dialog(npc.display_name, "欢迎光临摩尔百货！种子、拉姆果、漂亮的帽子，应有尽有哦~\n作物和鱼也可以卖给我。",
				[["看看商品", open_shop], ["下次再来", _noop]])
		_:
			show_dialog(npc.display_name, TIPS.pick_random(), [["再聊聊", on_npc_interact.bind(npc)], ["再见", _noop]])


func _lele_dialog(npc) -> void:
	if GameState.quest_done():
		show_dialog(npc.display_name, "哇，你完成了任务！真是能干的小摩尔~ 这是给你的奖励！",
			[["领取奖励", _claim_quest.bind(npc)]])
	else:
		show_dialog(npc.display_name, "你好呀，小摩尔！能帮我一个忙吗？\n" + GameState.quest_text(),
			[["交给我吧！", _noop], ["换一个任务（10豆）", _reroll_quest.bind(npc)]])


func _claim_quest(npc) -> void:
	var r := GameState.claim_quest()
	show_toast("获得 %d 摩尔豆！" % r)
	npc.say("谢谢你！下一个任务也拜托啦~")


func _reroll_quest(npc) -> void:
	if GameState.spend_beans(10):
		GameState.new_quest()
		_lele_dialog(npc)
	else:
		show_toast("摩尔豆不够啦")


# ---------- 商店 ----------

func open_shop() -> void:
	close_popups()
	shop_panel.visible = true
	_populate_shop()


func _shop_tab(tab: String) -> void:
	shop_tab = tab
	_populate_shop()


func _shop_row(text: String, buttons: Array) -> void:
	var hb := HBoxContainer.new()
	var l := _label(text, 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	for o in buttons:
		var b := _button(o[0], o[1])
		if o.size() > 2 and o[2]:
			b.disabled = true
		hb.add_child(b)
	shop_list.add_child(hb)
	shop_list.add_child(HSeparator.new())


func _populate_shop() -> void:
	for c in shop_list.get_children():
		c.queue_free()
	shop_beans.text = "摩尔豆：%d  " % GameState.beans
	match shop_tab:
		"seeds":
			for id in GameState.CROPS:
				var c: Dictionary = GameState.CROPS[id]
				var price: int = c["seed_price"]
				_shop_row("%s种子   %d豆\n约%d秒成熟 · 售价%d豆" % [c["name"], price, int(c["grow_time"]), c["sell"]],
					[["买1个", _buy.bind("seed_" + id, price, 1)], ["买5个", _buy.bind("seed_" + id, price, 5)]])
		"sell":
			var any := false
			for id in GameState.inventory.keys():
				var p := GameState.sell_price(id)
				if p > 0:
					any = true
					_shop_row("%s ×%d   单价%d豆" % [GameState.item_name(id), GameState.count(id), p],
						[["卖1个", _sell.bind(id, 1)], ["全部卖出", _sell.bind(id, -1)]])
			if not any:
				shop_list.add_child(_label("没有可以卖的东西。去农场种菜或者去湖边钓鱼吧！", 16))
		"hats":
			for id in GameState.HATS:
				var h: Dictionary = GameState.HATS[id]
				var owned: bool = id in GameState.owned_hats
				var wearing: bool = GameState.hat == id
				var label := "%s%s" % [h["name"], "" if owned else "   %d豆" % h["price"]]
				if wearing:
					_shop_row(label, [["穿戴中", _noop, true]])
				elif owned:
					_shop_row(label, [["穿戴", _wear.bind(id)]])
				else:
					_shop_row(label, [["购买并穿戴", _wear.bind(id)]])
		"lahm":
			var fp := GameState.LAHM_FRUIT_PRICE
			_shop_row("拉姆果   %d豆\n拉姆最爱吃的果子，恢复40点饱食度（你有 %d 个）" % [fp, GameState.count("lahm_fruit")],
				[["买1个", _buy.bind("lahm_fruit", fp, 1)], ["买5个", _buy.bind("lahm_fruit", fp, 5)]])


func _buy(id: String, price: int, n: int) -> void:
	if GameState.spend_beans(price * n):
		GameState.add_item(id, n)
		show_toast("买到了 %s ×%d" % [GameState.item_name(id), n])
	else:
		show_toast("摩尔豆不够啦！")
	_populate_shop()


func _sell(id: String, n: int) -> void:
	if n < 0:
		n = GameState.count(id)
	var p := GameState.sell_price(id)
	if GameState.remove_item(id, n):
		GameState.add_beans(p * n)
		show_toast("卖掉 %s ×%d，获得 %d 摩尔豆" % [GameState.item_name(id), n, p * n])
	_populate_shop()


func _wear(id: String) -> void:
	if not id in GameState.owned_hats:
		var price: int = GameState.HATS[id]["price"]
		if not GameState.spend_beans(price):
			show_toast("摩尔豆不够啦！")
			return
		GameState.owned_hats.append(id)
		show_toast("买到了 %s！" % GameState.HATS[id]["name"])
	GameState.hat = id
	GameState.hat_changed.emit()
	_populate_shop()


# ---------- 钓鱼 ----------

func start_fishing(pond_pos: Vector2) -> void:
	if fishing or player == null:
		return
	close_popups()
	fishing = true
	fish_phase = 0
	fish_timer = randf_range(1.5, 4.0)
	player.fishing = true
	player.bite = false
	var dx: float = pond_pos.x - player.position.x
	if absf(dx) > 1.0:
		player.facing = signf(dx)
	fish_label.text = "等待鱼儿上钩……（太早收杆会把鱼吓跑哦）"
	fish_panel.visible = true
	fish_bar.queue_redraw()


func _fish_process(delta: float) -> void:
	match fish_phase:
		0:
			fish_timer -= delta
			if fish_timer <= 0.0:
				fish_phase = 1
				fish_timer = 3.5
				fish_marker = 0.0
				fish_dir = 1.0
				fish_zone = Vector2(randf_range(0.15, 0.7), randf_range(0.14, 0.24))
				fish_speed = randf_range(1.2, 2.0)
				fish_label.text = "鱼上钩了！红色标记在绿色区域时按空格收杆！"
				player.bite = true
		1:
			fish_marker += fish_dir * fish_speed * delta
			if fish_marker > 1.0:
				fish_marker = 1.0
				fish_dir = -1.0
			elif fish_marker < 0.0:
				fish_marker = 0.0
				fish_dir = 1.0
			fish_timer -= delta
			if fish_timer <= 0.0:
				_fish_end("鱼儿挣脱跑掉了……")
		2:
			fish_timer -= delta
			if fish_timer <= 0.0:
				_stop_fishing()
	fish_bar.queue_redraw()


func _reel() -> void:
	if not fishing:
		return
	if fish_phase == 0:
		_fish_end("拉得太早了，鱼被吓跑了！")
	elif fish_phase == 1:
		if fish_marker >= fish_zone.x and fish_marker <= fish_zone.x + fish_zone.y:
			var id := _roll_fish()
			GameState.add_item(id)
			if id == "boot":
				_fish_end("钓上来一只……破靴子？！")
			else:
				GameState.report("fish", id)
				_fish_end("钓到了一条%s！" % GameState.item_name(id))
		else:
			_fish_end("没拉住，鱼跑掉了！")


func _roll_fish() -> String:
	var total := 0
	for id in GameState.FISH:
		total += int(GameState.FISH[id]["weight"])
	var r := randi() % total
	for id in GameState.FISH:
		r -= int(GameState.FISH[id]["weight"])
		if r < 0:
			return id
	return "small_fish"


func _fish_end(msg: String) -> void:
	fish_phase = 2
	fish_timer = 1.6
	fish_label.text = msg
	player.bite = false


func _stop_fishing() -> void:
	fishing = false
	fish_panel.visible = false
	if player != null:
		player.fishing = false
		player.bite = false


func _draw_fish_bar() -> void:
	var s := fish_bar.size
	fish_bar.draw_rect(Rect2(Vector2.ZERO, s), Color(0.35, 0.6, 0.9))
	if fish_phase == 1:
		fish_bar.draw_rect(Rect2(fish_zone.x * s.x, 0, fish_zone.y * s.x, s.y), Color(0.35, 0.9, 0.45))
		var x := fish_marker * s.x
		fish_bar.draw_rect(Rect2(x - 4, -4, 8, s.y + 8), Color(0.95, 0.25, 0.2))
	fish_bar.draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.2, 0.1), false, 2.0)
