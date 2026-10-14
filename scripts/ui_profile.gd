extends Node
## 设置面板（音量、重置存档）、表情栏、捏脸面板。由 ui.gd 创建，ui 提供通用的面板 / 按钮工具。

var ui  # ui.gd
var settings_panel: PanelContainer
var emote_bar: PanelContainer
var creator_panel: PanelContainer
var creator_name: LineEdit
var creator_color := ""
var preview_mole


func build() -> void:
	_build_settings()
	_build_emote_bar()
	_build_creator()


func close() -> void:
	settings_panel.visible = false
	emote_bar.visible = false


# ---------- 设置 ----------

func _build_settings() -> void:
	settings_panel = ui._panel()
	ui._centered(settings_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	settings_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl: Label = ui._label("设置", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(ui._button("关闭", toggle_settings))
	v.add_child(title)
	v.add_child(_volume_row("背景音乐", GameState.music_volume, func(x):
		GameState.music_volume = x
		Sfx.apply_volumes()))
	v.add_child(_volume_row("音效", GameState.sfx_volume, func(x):
		GameState.sfx_volume = x
		Sfx.apply_volumes()
		Sfx.play("click")))
	var sizes := HBoxContainer.new()
	var sl: Label = ui._label("界面大小", 17)
	sl.custom_minimum_size = Vector2(90, 0)
	sizes.add_child(sl)
	for opt in [["小", 0.9], ["标准", 1.0], ["大", 1.15], ["特大", 1.3]]:
		sizes.add_child(ui._button(opt[0], ui.set_ui_scale.bind(opt[1])))
	v.add_child(sizes)
	v.add_child(HSeparator.new())
	var hb := HBoxContainer.new()
	var warn: Label = ui._label("清空农场、背包和任务，从头开始", 15)
	warn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(warn)
	hb.add_child(ui._button("重置存档", _confirm_reset))
	v.add_child(hb)
	v.add_child(ui._button("修改形象（名字、毛色）", func():
		settings_panel.visible = false
		open_creator()))
	settings_panel.visible = false


func _volume_row(text: String, value: float, on_change: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l: Label = ui._label(text, 17)
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
	ui.show_dialog("重置存档", "确定要清空农场、背包、摩尔豆和任务，从头开始吗？（名字和音量设置会保留）",
		[["确定重置", _reset_save], ["再想想", ui._noop]])


func _reset_save() -> void:
	Net.leave()
	GameState.reset_game()
	get_tree().reload_current_scene()


# ---------- 表情 ----------

func _build_emote_bar() -> void:
	emote_bar = ui._panel()
	ui._place(emote_bar, [0, 1, 0, 1], [12, -76, 12, -76], true)
	emote_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hb := HBoxContainer.new()
	emote_bar.add_child(hb)
	for kind in GameState.EMOTE_ORDER:
		hb.add_child(ui._button(player_emote_name(kind), do_emote.bind(kind)))
	emote_bar.visible = false


func player_emote_name(kind: String) -> String:
	return {"wave": "挥手", "happy": "开心", "angry": "生气", "cry": "难过", "sing": "唱歌", "sleep": "睡觉"}[kind]


func toggle_emotes() -> void:
	emote_bar.visible = not emote_bar.visible


func do_emote(kind: String) -> void:
	emote_bar.visible = false
	if ui.player == null:
		return
	ui.player.play_emote(kind)
	Net.send_emote(kind)
	Sfx.play("pop")
	# 附近的 NPC 会回应
	var best = null
	var best_d := 260.0
	for npc in get_tree().get_nodes_in_group("npcs"):
		var d: float = npc.position.distance_to(ui.player.position)
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
	creator_panel = ui._panel()
	ui._centered(creator_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	creator_panel.add_child(v)
	v.add_child(ui._label("创建你的小摩尔", 26))
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
	form.add_child(ui._label("名字", 17))
	var name_row := HBoxContainer.new()
	creator_name = LineEdit.new()
	creator_name.max_length = 10
	creator_name.custom_minimum_size = Vector2(220, 0)
	name_row.add_child(creator_name)
	name_row.add_child(ui._button("随机", func():
		creator_name.text = GameState.RANDOM_NAMES.pick_random()
		preview_mole.play_emote("happy")))
	form.add_child(name_row)
	form.add_child(ui._label("毛色", 17))
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
	go.add_child(ui._button("出发！", _finish_creator))
	v.add_child(go)
	creator_panel.visible = false


func open_creator() -> void:
	ui._close_all()
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
	if ui.player != null:
		ui.player.set_display_name(n)
		ui.player.body_color = Color.html(creator_color)
		ui.player.play_emote("happy")
	Net.send_info()
	creator_panel.visible = false
	if GameState.is_new_player:
		GameState.is_new_player = false
		ui.help_panel.visible = true
	GameState.save_game()
	ui.show_toast("你好，%s！欢迎来到摩尔小镇~" % n)


