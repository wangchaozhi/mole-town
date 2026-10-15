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
var fest_label: Label
var tut_box: HBoxContainer
var tut_label: Label
var story_label: Label
var level_label: Label
var exp_bar: ProgressBar
var seed_buttons := {}
var toast_label: Label
var toast_timer := 0.0
var toast_queue: Array = []
var badge: PanelContainer
var badge_name: Label
var badge_queue: Array = []
var badge_busy := false
var dialog_panel: PanelContainer
var dialog_name: Label
var dialog_text: Label
var dialog_opts: HBoxContainer
var shop  # ui_shop.gd：摩尔百货
var bag_panel: PanelContainer
var bag_list: GridContainer
var help_panel: PanelContainer
var help_scroll: ScrollContainer
var chat_edit: LineEdit
var chat_log: VBoxContainer
var online_label: Label
var profile  # ui_profile.gd：设置、表情、捏脸
var progress  # ui_progress.gd：图鉴、成就、签到
var minimap_panel: PanelContainer
var act  # ui_activities.gd：送礼物、小游戏、留言板
var kitchen  # ui_kitchen.gd：烹饪
var mailui  # ui_mail.gd：信箱

var fish  # ui_fishing.gd：钓鱼
var netui  # ui_net.gd：联机面板、玩家菜单、串门
var fishing: bool:  # 是否正在钓鱼（其他脚本只读）
	get:
		return fish != null and fish.fishing


func _ready() -> void:
	add_to_group("ui")
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = GameState.ui_theme
	add_child(root)
	apply_ui_scale()
	get_viewport().size_changed.connect(apply_ui_scale)
	_build_hud()
	_build_minimap()  # 先建小地图，后面的面板都盖在它上面
	_build_seed_bar()
	_build_chat()
	_build_dialog()
	shop = preload("res://scripts/ui/ui_shop.gd").new()
	shop.ui = self
	add_child(shop)
	shop.build()
	_build_bag()
	fish = preload("res://scripts/ui/ui_fishing.gd").new()
	fish.ui = self
	add_child(fish)
	fish.build()
	netui = preload("res://scripts/ui/ui_net.gd").new()
	netui.ui = self
	add_child(netui)
	netui.build()
	profile = preload("res://scripts/ui/ui_profile.gd").new()
	profile.ui = self
	add_child(profile)
	profile.build()
	progress = preload("res://scripts/ui/ui_progress.gd").new()
	progress.ui = self
	add_child(progress)
	progress.build()
	act = preload("res://scripts/ui/ui_activities.gd").new()
	act.ui = self
	add_child(act)
	act.build()
	kitchen = preload("res://scripts/ui/ui_kitchen.gd").new()
	kitchen.ui = self
	add_child(kitchen)
	kitchen.build()
	mailui = preload("res://scripts/ui/ui_mail.gd").new()
	mailui.ui = self
	add_child(mailui)
	mailui.build()
	_build_help()
	_build_toast()
	_build_badge()
	GameState.achievement_unlocked.connect(func(a): badge_queue.append(a); _next_badge())
	GameState.beans_changed.connect(_refresh_hud)
	GameState.quest_changed.connect(_refresh_hud)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.toast.connect(show_toast)
	GameState.level_changed.connect(_refresh_seeds)
	_refresh_hud()
	_refresh_seeds()
	help_panel.visible = false
	if GameState.loaded_from_backup:
		show_toast("存档文件损坏了，已经从上一次的备份恢复")
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
	var lvrow := HBoxContainer.new()
	level_label = _label("", 15)
	lvrow.add_child(level_label)
	exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(130, 10)
	exp_bar.show_percentage = false
	exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lvrow.add_child(exp_bar)
	v.add_child(lvrow)
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
	fest_label = _label("", 14)
	fest_label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.15))
	fest_label.custom_minimum_size = Vector2(260, 0)
	fest_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(fest_label)
	tut_box = HBoxContainer.new()
	tut_label = _label("", 14)
	tut_label.add_theme_color_override("font_color", Color(0.85, 0.45, 0.05))
	tut_label.custom_minimum_size = Vector2(210, 0)
	tut_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	tut_box.add_child(tut_label)
	var skip := _button("跳过", GameState.skip_tutorial)
	skip.add_theme_font_size_override("font_size", 13)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tut_box.add_child(skip)
	v.add_child(tut_box)
	story_label = _label("", 14)
	story_label.add_theme_color_override("font_color", Color(0.45, 0.25, 0.7))
	story_label.custom_minimum_size = Vector2(260, 0)
	story_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(story_label)
	GameState.story_changed.connect(_refresh_story)
	GameState.story_beat.connect(func(title, text): show_dialog(title, text, [["继续", _noop]]))
	GameState.tutorial_changed.connect(_refresh_tutorial)
	_refresh_tutorial()
	_refresh_story()
	GameState.tutorial_changed.connect(_refresh_story)
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
	_place(p, [1, 1, 1, 1], [-12, -12, -12, -12], true)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
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


func _build_help() -> void:
	help_panel = _panel()
	_centered(help_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	help_panel.add_child(v)
	v.add_child(_label("欢迎来到摩尔小镇！", 26))
	# 说明越来越长：放进滚动区域，高度跟着窗口和界面缩放走，保证底下的按钮一直看得到
	help_scroll = ScrollContainer.new()
	help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(help_scroll)
	var l := _label("", 16)
	l.custom_minimum_size = Vector2(600, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.text = "• 新玩家会有一段新手引导：跟着左上角的提示和地图上的橙色箭头走，每完成一步都有奖励（可以跳过）\n" \
		+ "• 鼠标左键点击地面走路，点击人物 / 物体互动；也可以用 WASD / 方向键走路，按 F 和身边的东西互动\n" \
		+ "• 开心农场（右下）：在右下角的种子栏选好种子（数字键 1~6 也能切换），点空地播种（新作物随等级解锁）；点作物浇水（生长加速），浇过水再点一下可以施肥（Lv2 起商店有卖）；成熟后点击收获；有虫子时点击抓虫\n" \
		+ "• 钓鱼湖（左下）：点击湖面开始钓鱼，鱼上钩后，红色标记在绿色区域内时按空格收杆\n" \
		+ "• 摩尔百货（右上）：找店长买种子、拉姆果、帽子，也能卖掉收获的作物和鱼\n" \
		+ "• 乐乐（广场）：领取任务，完成后回来领摩尔豆奖励\n" \
		+ "• 我的小屋（钓鱼湖和小院之间）：进门后可以上床睡觉（晚上 8 点后直接睡到早上）、在衣柜换帽子、看奖杯架\n" \
		+ "• 信箱（小屋门口）：小镇的朋友们偶尔会寄信来，拆信可以收到小礼物\n" \
		+ "• 小厨房（广场左边）：用作物和鱼做菜，菜卖得更贵，也是拉姆和 NPC 最爱的礼物\n" \
		+ "• 留言板（广场右边）：贴一张留言，联机时所有人都能看到\n" \
		+ "• NPC 好感：每个 NPC 每天可以送一次礼物，送他们喜欢的东西好感涨得快，好感到 20 / 50 / 100 会收到回礼\n" \
		+ "• 我的小院（农场左边）：在商店「家具」页买家具，背包里点「摆放」装扮小院，点家具可以移动或收起\n" \
		+ "• 拉姆：你的小宠物，饿了会飞不动，点击它喂食，吃饱了点击是摸摸它；亲密度升级后会帮你抓虫、找宝物、浇水\n" \
		+ "• 联机：按 N，一人「创建房间」，其他人填房主 IP 后「加入房间」，就能看到彼此、聊天、送摩尔豆\n" \
		+ "• 串门：点击其他玩家选「去TA家农场串门」，帮好友浇水、抓虫能拿摩尔豆，成熟的作物还能摘一个；点顶部「回家」返回\n" \
		+ "• 右上角小地图：点击任意位置直接传送过去；鼠标滚轮 / +- 键 / 双指捏合可以缩放镜头\n" \
		+ "• 快捷键：回车 聊天，E 表情，F 互动，C 图鉴，M 小地图，B 背包，N 联机，H 帮助，F12 截图，Esc 关闭窗口\n" \
		+ "• 四季小玩法：春天草丛里找四叶草（找到当天是幸运日），夏夜湖边抓萤火虫，秋天翻落叶堆，冬天翻雪堆；左上角会提示今天有什么\n" \
		+ "• 广场东边的扭蛋机：50 豆扭一次，有限定帽子；每周末白天湖边有旅行商人阿布摆摊\n" \
		+ "• 拉姆 Lv2 起，每天第一次在它吃饱时摸摸它，会和你玩捉迷藏\n" \
		+ "• 游戏每 30 秒自动保存，离线时农场里的作物也会继续生长"
	help_scroll.add_child(l)
	help_panel.visibility_changed.connect(_fit_help)
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
	if shop != null:
		shop.refresh_beans()


func _refresh_seeds() -> void:
	for id in seed_buttons:
		var b: Button = seed_buttons[id]
		if GameState.is_unlocked(id) or GameState.count("seed_" + id) > 0:
			b.text = "%s ×%d" % [GameState.CROPS[id]["name"], GameState.count("seed_" + id)]
			b.tooltip_text = "快捷键 %d" % (GameState.CROPS.keys().find(id) + 1)
			b.disabled = false
		else:
			b.text = "%s Lv%d" % [GameState.CROPS[id]["name"], int(GameState.CROPS[id]["level"])]
			b.disabled = true
		b.set_pressed_no_signal(id == GameState.selected_seed)


func _on_inventory_changed() -> void:
	_refresh_seeds()
	_refresh_hud()  # 送货任务的进度跟着背包变
	if bag_panel.visible:
		_refresh_bag()


func _refresh_bag() -> void:
	for c in bag_list.get_children():
		c.queue_free()
	if GameState.inventory.is_empty():
		bag_list.add_child(_label("背包空空的……", 16))
	for id in GameState.inventory:
		var l := _label("%s ×%d" % [GameState.item_name(id), GameState.count(id)], 17)
		if str(id).begins_with("furn_"):
			var hb := HBoxContainer.new()
			hb.add_child(l)
			hb.add_child(_button("摆放", _place_from_bag.bind(str(id).substr(5))))
			bag_list.add_child(hb)
		elif str(id) == "mystery_seed":
			var hb := HBoxContainer.new()
			hb.add_child(l)
			hb.add_child(_button("打开", func():
				show_toast(GameState.open_mystery_seed())
				_refresh_bag()))
			bag_list.add_child(hb)
		else:
			bag_list.add_child(l)


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
	if Engine.get_process_frames() % 20 == 0:
		fest_label.text = GameState.festival_text()
		fest_label.visible = fest_label.text != ""
	var lv := GameState.player_level
	if lv >= GameState.MAX_LEVEL:
		level_label.text = "Lv%d（满级）" % lv
		exp_bar.value = 100
	else:
		var lo := GameState.exp_for_level(lv)
		var hi := GameState.exp_for_level(lv + 1)
		level_label.text = "Lv%d  经验 %d/%d " % [lv, GameState.player_exp - lo, hi - lo]
		exp_bar.value = 100.0 * (GameState.player_exp - lo) / (hi - lo)
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
		fish.process(delta)


# ---------- 窗口 ----------

func toggle_bag() -> void:
	bag_panel.visible = not bag_panel.visible
	if bag_panel.visible:
		_refresh_bag()


func close_popups() -> void:
	dialog_panel.visible = false
	shop.hide()
	bag_panel.visible = false


func _close_all() -> void:
	close_popups()
	var main = get_tree().current_scene
	if main != null and main.has_method("cancel_placing"):
		main.cancel_placing()
	help_panel.visible = false
	netui.net_panel.visible = false
	profile.close()
	progress.close()
	act.close()
	kitchen.close()
	mailui.close()
	if fishing:
		fish._stop_fishing()


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
				fish._reel()
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
		KEY_F12:
			take_screenshot()
		KEY_M:
			minimap_panel.visible = not minimap_panel.visible
		KEY_H:
			help_panel.visible = not help_panel.visible
		KEY_ESCAPE:
			_close_all()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			select_seed_index(k.keycode - KEY_1)


## 数字键 1~9 快速切换种子
func select_seed_index(i: int) -> void:
	var ids := GameState.CROPS.keys()
	if i < 0 or i >= ids.size() or fishing:
		return
	var id: String = ids[i]
	var b: Button = seed_buttons[id]
	if b.disabled:
		show_toast("%s要 Lv%d 才能种哦" % [GameState.CROPS[id]["name"], int(GameState.CROPS[id]["level"])])
		return
	GameState.selected_seed = id
	_refresh_seeds()
	show_toast("准备播种：%s（还有 %d 颗）" % [GameState.item_name("seed_" + id), GameState.count("seed_" + id)])


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
	shop.hide()
	bag_panel.visible = false
	dialog_panel.visible = true


func _noop() -> void:
	pass


func on_npc_interact(npc) -> void:
	match npc.role:
		"lele":
			_lele_dialog(npc)
		"king":
			_king_dialog(npc)
		"merchant":
			_merchant_dialog(npc)
		"shop":
			var m := GameState.market()
			show_dialog(_npc_title(npc), "欢迎光临摩尔百货！今天%s收购价特别高（×1.5），%s种子打 6 折哦~\n种子、拉姆果、漂亮的帽子，应有尽有，作物和鱼也可以卖给我。" % [GameState.item_name(m["hot"]), GameState.item_name(m["sale"])],
				[["看看商品", open_shop], ["送礼物", act.open_npc_gift.bind(npc)], ["下次再来", _noop]])
		_:
			var text: String = TIPS.pick_random()
			if GameState.affinity(npc.display_name) >= 50 and randf() < 0.4:
				text = "我们是好朋友啦！悄悄告诉你：" + text
			show_dialog(_npc_title(npc), text, [["再聊聊", on_npc_interact.bind(npc)], ["送礼物", act.open_npc_gift.bind(npc)], ["再见", _noop]])


func _merchant_dialog(npc) -> void:
	var lines := PackedStringArray()
	var opts := []
	for i in GameState.MERCHANT_STOCK.size():
		var it: Dictionary = GameState.MERCHANT_STOCK[i]
		lines.append("· %s ×%d  %d豆：%s" % [GameState.item_name(str(it["id"])), int(it["n"]), int(it["price"]), it["desc"]])
		opts.append(["买%s" % GameState.item_name(str(it["id"])), _merchant_buy.bind(i, npc)])
	opts.append(["再见", _noop])
	show_dialog("旅行商人阿布", "周末限定小摊！（你有 %d 豆）\n" % GameState.beans + "\n".join(lines), opts)


func _merchant_buy(i: int, npc) -> void:
	show_toast(GameState.merchant_buy(i))
	_merchant_dialog(npc)


func _npc_title(npc) -> String:
	var n: String = npc.display_name
	var bd := ""
	if GameState.NPC_INFO.has(n):
		bd = "  · 今天生日！" if GameState.birthday_npc() == n else "  · 生日：%s" % GameState.birthday_text(n)
	return "%s · %s（好感 %d）%s" % [n, GameState.affinity_tier(n), GameState.affinity(n), bd]


func _lele_dialog(npc) -> void:
	GameState.tutorial_event("talk_lele")
	if GameState.quest_done():
		show_dialog(_npc_title(npc), "哇，你完成了任务！真是能干的小摩尔~ 这是给你的奖励！",
			[["领取奖励", _claim_quest.bind(npc)]])
	else:
		show_dialog(_npc_title(npc), "你好呀，小摩尔！能帮我一个忙吗？\n" + GameState.quest_text(),
			[["交给我吧！", _noop], ["换一个任务（10豆）", _reroll_quest.bind(npc)], ["送礼物", act.open_npc_gift.bind(npc)]])


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


## 点湖面开始钓鱼（main.gd 通过 call_group 调用）
func start_fishing(pond_pos: Vector2) -> void:
	fish.start(pond_pos)


# ---------- 小院家具 ----------

func _place_from_bag(kind: String) -> void:
	bag_panel.visible = false
	get_tree().current_scene.start_placing(kind)


func on_furniture_interact(node) -> void:
	var name_: String = GameState.FURNITURE[node.kind]["name"]
	show_dialog(name_, "要怎么摆弄这件%s呢？" % name_, [
		["移动", get_tree().current_scene.start_placing.bind(node.kind, node.index)],
		["收进背包", get_tree().current_scene.store_furniture.bind(node.index)],
		["就这样吧", _noop],
	])


# ---------- 小地图 ----------

func _build_minimap() -> void:
	minimap_panel = _panel()
	var sb: StyleBoxFlat = minimap_panel.get_theme_stylebox("panel").duplicate()
	sb.set_content_margin_all(5)
	minimap_panel.add_theme_stylebox_override("panel", sb)
	_place(minimap_panel, [1, 0, 1, 0], [-12, 60, -12, 60], true)
	minimap_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	minimap_panel.add_child(v)
	var mm = preload("res://scripts/ui/minimap.gd").new()
	mm.main = get_parent()
	v.add_child(mm)
	var tip := _label("点击地图传送 · M 键隐藏", 12)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)




func open_shop() -> void:
	shop.open()


func toggle_collection() -> void:
	progress.toggle_collection()


func show_signin_if_needed() -> void:
	progress.show_signin_if_needed()


# 下面这些会被场景里的物体通过 call_group("ui", ...) 调用，转给对应模块

func open_board() -> void:
	act.open_board()


func open_minigame_intro() -> void:
	act.open_minigame_intro()


func open_creator() -> void:
	profile.open_creator()


func toggle_settings() -> void:
	profile.toggle_settings()


func toggle_emotes() -> void:
	profile.toggle_emotes()


func do_emote(kind: String) -> void:
	profile.do_emote(kind)


func open_kitchen() -> void:
	kitchen.open()


func open_gacha() -> void:
	show_dialog("扭蛋机", "%d 摩尔豆扭一次！可能扭到：摩尔豆、种子、拉姆果、家具……\n还有扭蛋限定的帽子「兔耳朵」和「小黄鸡」哦！（你有 %d 豆）" % [GameState.GACHA_PRICE, GameState.beans],
		[["扭一次", _gacha_spin], ["下次再来", _noop]])


func _gacha_spin() -> void:
	var r := GameState.gacha_spin()
	if r["ok"]:
		Sfx.play("gift")
		var g = get_tree().get_first_node_in_group("gacha")
		if g != null:
			g.play_spin()
	show_dialog("扭蛋机", str(r["text"]), [["再扭一次", _gacha_spin], ["不扭了", _noop]])


func _refresh_tutorial() -> void:
	tut_box.visible = GameState.tutorial_active()
	if tut_box.visible:
		tut_label.text = "新手引导（%d/%d）：%s" % [GameState.tutorial_step + 1, GameState.TUTORIAL.size(), GameState.TUTORIAL[GameState.tutorial_step]["text"]]


func toggle_net() -> void:
	netui.toggle_net()


## 点击其他联机玩家（main.gd 通过 call_group 调用）
func on_remote_interact(m) -> void:
	netui.on_remote_interact(m)


# ---------- 国王的每周挑战 ----------

func _king_dialog(npc) -> void:
	var w := GameState.weekly()
	var prog := GameState.weekly_progress()
	var head := "哈哈，小摩尔，欢迎来到我的城堡！\n本周挑战：%s（%d/%d）  奖励 %d 摩尔豆" % [w["text"], prog, int(w["target"]), GameState.WEEKLY_REWARD]
	if GameState.weekly_claimed:
		show_dialog("摩尔国王", head + "\n这周的奖励你已经领过啦，下周再来挑战吧！", [["好的", _noop]])
	elif GameState.weekly_done():
		show_dialog("摩尔国王", head + "\n了不起！你完成了本周的挑战！", [["领取奖励", _claim_weekly.bind(npc)]])
	else:
		show_dialog("摩尔国王", head + "\n每 7 天换一个挑战，加油哦！", [["我会努力的！", _noop]])


func _claim_weekly(npc) -> void:
	var had_trophy := GameState.count("furn_trophy")
	if GameState.claim_weekly():
		Sfx.play("catch")
		npc.play_emote("happy")
		npc.say("这是你应得的！")
		var extra := "，还有一座金奖杯（放进背包了，可以摆在小院里）" if GameState.count("furn_trophy") > had_trophy else ""
		show_toast("获得 %d 摩尔豆%s！" % [GameState.WEEKLY_REWARD, extra])


# ---------- 截图 ----------

func take_screenshot() -> String:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "user://screenshots/摩尔小镇_%s.png" % stamp
	if img.save_png(path) != OK:
		show_toast("截图失败")
		return ""
	Sfx.play("pop")
	show_toast("截图已保存：" + ProjectSettings.globalize_path(path))
	return path


func open_mail() -> void:
	mailui.open()


# ---------- 界面大小 ----------

## 整个界面层按 GameState.ui_scale 缩放；根节点大小 = 屏幕 / 缩放，这样贴边的面板仍然贴在屏幕边上
func _fit_help() -> void:
	if help_panel.visible:
		help_scroll.custom_minimum_size = Vector2(620, clampf(root.size.y - 170.0, 160.0, 480.0))
		help_scroll.scroll_vertical = 0


func apply_ui_scale() -> void:
	var s := GameState.ui_scale
	scale = Vector2(s, s)
	root.position = Vector2.ZERO
	root.size = get_viewport().get_visible_rect().size / s
	if help_panel != null:
		_fit_help()


func set_ui_scale(s: float) -> void:
	GameState.ui_scale = s
	apply_ui_scale()


# ---------- 成就徽章 ----------

func _build_badge() -> void:
	badge = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.92, 0.6)
	sb.border_color = Color(0.85, 0.55, 0.1)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	badge.add_theme_stylebox_override("panel", sb)
	_place(badge, [0.5, 0, 0.5, 0], [0, 120, 0, 120])
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	badge.add_child(hb)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.draw.connect(func():
		var c := Vector2(26, 26)
		icon.draw_circle(c, 25.0, Color(0.95, 0.65, 0.15))
		icon.draw_circle(c, 21.0, Color(1, 0.85, 0.3))
		var gold := Color(0.85, 0.5, 0.05)
		icon.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -12), c + Vector2(11, -12), c + Vector2(7, 2), c + Vector2(-7, 2)]), gold)
		icon.draw_rect(Rect2(c + Vector2(-2, 2), Vector2(4, 7)), gold)
		icon.draw_rect(Rect2(c + Vector2(-8, 9), Vector2(16, 4)), gold))
	hb.add_child(icon)
	var v := VBoxContainer.new()
	var t := _label("成就达成！", 14)
	t.add_theme_color_override("font_color", Color(0.7, 0.4, 0.05))
	v.add_child(t)
	badge_name = _label("", 22)
	v.add_child(badge_name)
	hb.add_child(v)
	badge.visible = false


func _next_badge() -> void:
	if badge_busy or badge_queue.is_empty():
		return
	badge_busy = true
	var a: Dictionary = badge_queue.pop_front()
	badge_name.text = "%s   +%d 摩尔豆" % [a["name"], int(a["reward"])]
	badge.visible = true
	badge.reset_size()
	badge.offset_left = -badge.size.x / 2.0
	badge.offset_right = badge.size.x / 2.0
	badge.modulate.a = 0.0
	badge.offset_top = 90
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(badge, "modulate:a", 1.0, 0.3)
	tw.tween_property(badge, "offset_top", 120.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(badge, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(func():
		badge.visible = false
		badge_busy = false
		_next_badge())


func _refresh_story() -> void:
	story_label.text = GameState.story_text()
	story_label.visible = story_label.text != "" and not GameState.tutorial_active()
