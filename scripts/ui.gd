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
var lahm_info: Label
var seed_buttons := {}
var toast_label: Label
var toast_timer := 0.0
var toast_queue: Array = []
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
var settings_panel: PanelContainer
var emote_bar: PanelContainer
var collection_panel: PanelContainer
var collection_body: VBoxContainer
var signin_panel: PanelContainer
var signin_cards: HBoxContainer
var signin_button: Button
var signin_info: Label
var creator_panel: PanelContainer
var creator_name: LineEdit
var creator_color := ""
var preview_mole
var visit_bar: PanelContainer
var visit_label: Label

var fishing := false
var fish_phase := 0  # 0 等待 1 上钩 2 结束
var fish_timer := 0.0
var fish_marker := 0.0
var fish_dir := 1.0
var fish_zone := Vector2(0.4, 0.2)  # 起点, 宽度
var fish_speed := 1.5


func _ready() -> void:
	add_to_group("ui")
	layer = 5
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
	_build_visit_bar()
	_build_settings()
	_build_emote_bar()
	_build_creator()
	_build_collection()
	_build_signin()
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
	help_panel.visible = false
	if GameState.is_new_player:
		open_creator()
	else:
		show_signin_if_needed()


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
	b.pressed.connect(Sfx.play.bind("click"))
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
	lahm_info = _label("", 13)
	lahm_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lahm_info)
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
	top.add_child(_button("图鉴 (C)", toggle_collection))
	top.add_child(_button("背包 (B)", toggle_bag))
	top.add_child(_button("设置", toggle_settings))
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
	hb.add_child(_button("表情 (E)", toggle_emotes))

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
	var visit_opt: Array = ["回自己家", Net.leave_farm] if Net.visiting == m.peer_id else ["去TA家农场串门", _visit.bind(m)]
	show_dialog(m.display_name, "这是来自远方的小摩尔「%s」！" % m.display_name, [
		["打招呼", _greet.bind(m)],
		visit_opt,
		["送 10 摩尔豆", _send_gift.bind(m)],
		["再见", _noop],
	])


func _visit(m) -> void:
	Net.visit(m.peer_id)
	_on_chat("我来你家农场串门啦~")


func _build_visit_bar() -> void:
	visit_bar = _panel()
	_place(visit_bar, [0.5, 0, 0.5, 0], [0, 12, 0, 12], true)
	visit_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	visit_bar.add_child(hb)
	visit_label = _label("", 17)
	visit_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(visit_label)
	hb.add_child(_button("回家", Net.leave_farm))
	visit_bar.visible = false
	Net.visit_changed.connect(_refresh_visit)


func _refresh_visit() -> void:
	visit_bar.visible = Net.visiting != 0
	if Net.visiting != 0:
		visit_label.text = "正在「%s」家农场做客" % Net.player_name(Net.visiting)
		show_toast("帮好友浇水、抓虫能拿摩尔豆，成熟的作物可以摘一个~")
	else:
		show_toast("回到了自己的农场")


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
	l.text = "• 鼠标左键点击地面走路，点击人物 / 物体互动；也可以用 WASD / 方向键走路，按 F 和身边的东西互动\n" \
		+ "• 开心农场（右下）：在底部选好种子，点空地播种；点作物浇水（生长加速）；成熟后点击收获；有虫子时点击抓虫\n" \
		+ "• 钓鱼湖（左下）：点击湖面开始钓鱼，鱼上钩后，红色标记在绿色区域内时按空格收杆\n" \
		+ "• 摩尔百货（右上）：找店长买种子、拉姆果、帽子，也能卖掉收获的作物和鱼\n" \
		+ "• 乐乐（广场）：领取任务，完成后回来领摩尔豆奖励\n" \
		+ "• 拉姆：你的小宠物，饿了会飞不动，点击它喂食，吃饱了点击是摸摸它；亲密度升级后会帮你抓虫、找宝物、浇水\n" \
		+ "• 联机：按 N，一人「创建房间」，其他人填房主 IP 后「加入房间」，就能看到彼此、聊天、送摩尔豆\n" \
		+ "• 串门：点击其他玩家选「去TA家农场串门」，帮好友浇水、抓虫能拿摩尔豆，成熟的作物还能摘一个；点顶部「回家」返回\n" \
		+ "• 快捷键：回车 聊天，B 背包，N 联机，H 帮助，Esc 关闭窗口\n" \
		+ "• 游戏每 30 秒自动保存，离线时农场里的作物也会继续生长"
	v.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(_button("开始玩吧！", func():
		help_panel.visible = false
		show_signin_if_needed()))
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
	# 上一条还没看清（显示不到 1 秒）时先排队，避免连续提示互相覆盖
	if toast_timer > 1.6:
		if toast_queue.size() < 5:
			toast_queue.append(text)
		return
	toast_label.text = text
	toast_label.visible = true
	toast_label.reset_size()
	toast_label.offset_left = -toast_label.size.x / 2.0
	toast_label.offset_right = toast_label.size.x / 2.0
	toast_timer = 2.6


func _process(delta: float) -> void:
	time_label.text = GameState.time_text()
	hunger_bar.value = GameState.lahm_hunger
	var nx := GameState.lahm_exp_to_next()
	lahm_info.text = " Lv%d · %s" % [GameState.lahm_level, "满级" if nx < 0 else "还差%d" % nx]
	if toast_timer > 0.0:
		toast_timer -= delta
		toast_label.modulate.a = clampf(toast_timer / 0.5, 0.0, 1.0)
		if toast_timer <= 0.0:
			toast_label.visible = false
	if not toast_queue.is_empty() and toast_timer <= 1.6:
		show_toast(toast_queue.pop_front())
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
	settings_panel.visible = false
	emote_bar.visible = false
	collection_panel.visible = false
	signin_panel.visible = false
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
		KEY_E:
			toggle_emotes()
		KEY_F:
			if player != null and not fishing:
				player.interact_nearest()
		KEY_C:
			toggle_collection()
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
		GameState.check_achievements()
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
	Sfx.play("splash")
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
				Sfx.play("bite")
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
				Sfx.play("fail")
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
		Sfx.play("fail")
		_fish_end("拉得太早了，鱼被吓跑了！")
	elif fish_phase == 1:
		if fish_marker >= fish_zone.x and fish_marker <= fish_zone.x + fish_zone.y:
			var id := _roll_fish()
			GameState.add_item(id)
			GameState.record("fish", id)
			if id == "boot":
				Sfx.play("fail")
				_fish_end("钓上来一只……破靴子？！")
			else:
				GameState.report("fish", id)
				Sfx.play("catch")
				_fish_end("钓到了一条%s！" % GameState.item_name(id))
		else:
			Sfx.play("fail")
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


# ---------- 设置 ----------

func _build_settings() -> void:
	settings_panel = _panel()
	_centered(settings_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	settings_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl := _label("设置", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(_button("关闭", toggle_settings))
	v.add_child(title)
	v.add_child(_volume_row("背景音乐", GameState.music_volume, func(x):
		GameState.music_volume = x
		Sfx.apply_volumes()))
	v.add_child(_volume_row("音效", GameState.sfx_volume, func(x):
		GameState.sfx_volume = x
		Sfx.apply_volumes()
		Sfx.play("click")))
	v.add_child(HSeparator.new())
	var hb := HBoxContainer.new()
	var warn := _label("清空农场、背包和任务，从头开始", 15)
	warn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(warn)
	hb.add_child(_button("重置存档", _confirm_reset))
	v.add_child(hb)
	v.add_child(_button("修改形象（名字、毛色）", func():
		settings_panel.visible = false
		open_creator()))
	settings_panel.visible = false


func _volume_row(text: String, value: float, on_change: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l := _label(text, 17)
	l.custom_minimum_size = Vector2(90, 0)
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(300, 24)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(on_change)
	hb.add_child(s)
	return hb


func toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible


func _confirm_reset() -> void:
	settings_panel.visible = false
	show_dialog("重置存档", "确定要清空农场、背包、摩尔豆和任务，从头开始吗？（名字和音量设置会保留）",
		[["确定重置", _reset_save], ["再想想", _noop]])


func _reset_save() -> void:
	Net.leave()
	GameState.reset_game()
	get_tree().reload_current_scene()


# ---------- 表情 ----------

func _build_emote_bar() -> void:
	emote_bar = _panel()
	_place(emote_bar, [0, 1, 0, 1], [12, -76, 12, -76], true)
	emote_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hb := HBoxContainer.new()
	emote_bar.add_child(hb)
	for kind in GameState.EMOTE_ORDER:
		hb.add_child(_button(player_emote_name(kind), do_emote.bind(kind)))
	emote_bar.visible = false


func player_emote_name(kind: String) -> String:
	return {"wave": "挥手", "happy": "开心", "angry": "生气", "cry": "难过", "sing": "唱歌", "sleep": "睡觉"}[kind]


func toggle_emotes() -> void:
	emote_bar.visible = not emote_bar.visible


func do_emote(kind: String) -> void:
	emote_bar.visible = false
	if player == null:
		return
	player.play_emote(kind)
	Net.send_emote(kind)
	Sfx.play("pop")
	# 附近的 NPC 会回应
	var best = null
	var best_d := 260.0
	for npc in get_tree().get_nodes_in_group("npcs"):
		var d: float = npc.position.distance_to(player.position)
		if d < best_d:
			best_d = d
			best = npc
	if best == null:
		return
	var reply: Array = {
		"wave": ["wave", "你好呀~"], "happy": ["happy", "看到你真开心！"],
		"angry": ["cry", "别生气啦……"], "cry": ["happy", "别难过，抱抱~"],
		"sing": ["sing", "唱得真好听！"], "sleep": ["sleep", "我也困了……"],
	}[kind]
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(best):
			best.play_emote(reply[0])
			best.say(reply[1]))


# ---------- 捏脸 ----------

func _build_creator() -> void:
	creator_panel = _panel()
	_centered(creator_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	creator_panel.add_child(v)
	v.add_child(_label("创建你的小摩尔", 26))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	v.add_child(hb)

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(170, 180)
	hb.add_child(preview)
	preview_mole = preload("res://scripts/mole.gd").new()
	preview_mole.position = Vector2(85, 160)
	preview_mole.scale = Vector2(2.2, 2.2)
	preview.add_child(preview_mole)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	hb.add_child(form)
	form.add_child(_label("名字", 17))
	var name_row := HBoxContainer.new()
	creator_name = LineEdit.new()
	creator_name.max_length = 10
	creator_name.custom_minimum_size = Vector2(220, 0)
	name_row.add_child(creator_name)
	name_row.add_child(_button("随机", func():
		creator_name.text = GameState.RANDOM_NAMES.pick_random()
		preview_mole.play_emote("happy")))
	form.add_child(name_row)
	form.add_child(_label("毛色", 17))
	var swatches := HBoxContainer.new()
	for c in GameState.BODY_COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(32, 32)
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color.html(c)
			sb.set_corner_radius_all(16)
			sb.border_color = Color(1, 1, 1) if st != "normal" else Color(0.4, 0.25, 0.1)
			sb.set_border_width_all(3 if st != "normal" else 2)
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_pick_color.bind(c))
		swatches.add_child(b)
	form.add_child(swatches)

	var go := HBoxContainer.new()
	go.alignment = BoxContainer.ALIGNMENT_CENTER
	go.add_child(_button("出发！", _finish_creator))
	v.add_child(go)
	creator_panel.visible = false


func open_creator() -> void:
	_close_all()
	creator_name.text = GameState.player_name
	_pick_color(GameState.body_color)
	creator_panel.visible = true


func _pick_color(c: String) -> void:
	creator_color = c
	preview_mole.body_color = Color.html(c)
	preview_mole.hat = GameState.hat
	preview_mole.play_emote("wave")
	Sfx.play("pop")


func _finish_creator() -> void:
	var n := creator_name.text.strip_edges().left(10)
	if n == "":
		n = GameState.RANDOM_NAMES.pick_random()
	GameState.player_name = n
	GameState.body_color = creator_color
	if player != null:
		player.set_display_name(n)
		player.body_color = Color.html(creator_color)
		player.play_emote("happy")
	Net.send_info()
	creator_panel.visible = false
	if GameState.is_new_player:
		GameState.is_new_player = false
		help_panel.visible = true
	GameState.save_game()
	show_toast("你好，%s！欢迎来到摩尔小镇~" % n)


# ---------- 图鉴与成就 ----------

func _build_collection() -> void:
	collection_panel = _panel()
	_centered(collection_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	collection_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl := _label("图鉴与成就", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(_button("关闭", toggle_collection))
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
	collection_body.add_child(_label("作物", 18))
	collection_body.add_child(_item_row(GameState.CROPS.keys()))
	collection_body.add_child(_label("钓鱼湖", 18))
	collection_body.add_child(_item_row(GameState.FISH.keys()))
	collection_body.add_child(_label("成就（%d/%d）" % [GameState.achievements.size(), GameState.ACHIEVEMENTS.size()], 18))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for a in GameState.ACHIEVEMENTS:
		var done: bool = a["id"] in GameState.achievements
		var hb := HBoxContainer.new()
		var name_l := _label(("✓ " if done else "○ ") + str(a["name"]), 16)
		name_l.custom_minimum_size = Vector2(150, 0)
		name_l.add_theme_color_override("font_color", Color(0.2, 0.55, 0.2) if done else Color(0.45, 0.35, 0.25))
		hb.add_child(name_l)
		var desc := _label(str(a["desc"]), 15)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(desc)
		var prog := "已完成" if done else "%d/%d" % [mini(GameState.stat_value(a["stat"]), int(a["target"])), int(a["target"])]
		hb.add_child(_label(prog + "  · %d豆" % int(a["reward"]), 15))
		list.add_child(hb)
	collection_body.add_child(scroll)


func _item_row(ids: Array) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	for id in ids:
		var n := int(GameState.collection.get(id, 0))
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(130, 0)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(56, 56)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.draw.connect(_draw_item.bind(icon, id, n > 0))
		card.add_child(icon)
		var l := _label("%s ×%d" % [GameState.item_name(id), n] if n > 0 else "？？？", 15)
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
		col = GameState.CROPS[id]["color"] if GameState.CROPS.has(id) else {
			"small_fish": Color(0.55, 0.72, 0.88), "big_fish": Color(0.3, 0.5, 0.82),
			"gold_fish": Color(1.0, 0.75, 0.15), "boot": Color(0.5, 0.35, 0.25)}[id]
	match id:
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
	signin_panel = _panel()
	_centered(signin_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	signin_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl := _label("每日签到", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(_button("关闭", func(): signin_panel.visible = false))
	v.add_child(title)
	signin_cards = HBoxContainer.new()
	signin_cards.add_theme_constant_override("separation", 8)
	v.add_child(signin_cards)
	signin_info = _label("", 15)
	v.add_child(signin_info)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	signin_button = _button("签到领取", _do_signin)
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
			var l := _label(t, 14)
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
		show_toast("签到成功！获得 %d 摩尔豆" % reward)
		if player != null:
			player.play_emote("happy")
	_refresh_signin()
