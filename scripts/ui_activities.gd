extends Node
## 送礼物（给联机好友 / NPC）、城堡小游戏「接果子」、广场留言板。由 ui.gd 创建，ui 提供通用的面板 / 按钮工具。

var ui  # ui.gd
var gift_panel: PanelContainer
var gift_list: VBoxContainer
var gift_title: Label
var gift_target = null
var gift_to_npc := false  # true = 送给 NPC（加好感），false = 送给联机好友
var game_panel: PanelContainer
var game_view
var game_result: HBoxContainer
var game_result_label: Label
var board_panel: PanelContainer
var board_list: VBoxContainer
var board_edit: LineEdit
var board_scroll: ScrollContainer


func build() -> void:
	_build_gift()
	_build_minigame()
	_build_board()


func close() -> void:
	gift_panel.visible = false
	_close_minigame()
	board_panel.visible = false


# ---------- 送礼物 ----------

func _build_gift() -> void:
	gift_panel = ui._panel()
	ui._centered(gift_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	gift_panel.add_child(v)
	var title := HBoxContainer.new()
	gift_title = ui._label("", 22)
	gift_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(gift_title)
	title.add_child(ui._button("关闭", func(): gift_panel.visible = false))
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gift_list = VBoxContainer.new()
	gift_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(gift_list)
	v.add_child(scroll)
	gift_panel.visible = false


func open_gift(m) -> void:
	gift_target = m
	gift_to_npc = false
	gift_title.text = "送礼物给 %s" % m.display_name
	_refresh_gift()
	gift_panel.visible = true


func _refresh_gift() -> void:
	for c in gift_list.get_children():
		c.queue_free()
	var any := false
	for id in GameState.inventory:
		if not GameState.is_giftable(id):
			continue
		any = true
		var hb := HBoxContainer.new()
		var l: Label = ui._label("%s ×%d" % [GameState.item_name(id), GameState.count(id)], 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		if gift_to_npc and GameState.NPC_INFO.has(gift_target.display_name) and id in GameState.NPC_INFO[gift_target.display_name]["likes"]:
			l.text += "   ♥ 它很喜欢"
		hb.add_child(ui._button("送1个", _give.bind(id, 1)))
		if GameState.count(id) >= 5 and not gift_to_npc:
			hb.add_child(ui._button("送5个", _give.bind(id, 5)))
		gift_list.add_child(hb)
	if not any:
		gift_list.add_child(ui._label("背包里没有可以送的东西。", 16))


func _give(item: String, n: int) -> void:
	if gift_to_npc:
		_give_npc(item)
		return
	if gift_target == null or not is_instance_valid(gift_target) or not Net.is_online():
		ui.show_toast("对方已经不在了")
		gift_panel.visible = false
		return
	if not GameState.remove_item(item, n):
		return
	Net.send_item(gift_target.peer_id, item, n)
	Sfx.play("gift")
	var msg := "送给 %s %s ×%d" % [gift_target.display_name, GameState.item_name(item), n]
	ui.show_toast(msg)
	ui.add_chat_line("", "【礼物】" + msg, Color(1, 0.8, 0.9))
	ui.player.play_emote("happy")
	_refresh_gift()


func open_npc_gift(npc) -> void:
	var n: String = npc.display_name
	if not GameState.can_gift_npc(n):
		ui.show_toast("%s今天已经收过你的礼物啦，明天再来吧" % n)
		return
	gift_target = npc
	gift_to_npc = true
	gift_title.text = "送礼物给 %s（好感 %d）" % [n, GameState.affinity(n)]
	_refresh_gift()
	gift_panel.visible = true


func _give_npc(item: String) -> void:
	var npc = gift_target
	gift_panel.visible = false
	if npc == null or not is_instance_valid(npc):
		return
	var r := GameState.gift_npc(npc.display_name, item)
	if not r["ok"]:
		ui.show_toast(r["msg"])
		return
	Sfx.play("gift")
	npc.moving = false
	npc.idle_timer = 5.0
	if item == "boot":
		npc.play_emote("cry")
		npc.say("呃……破靴子？谢、谢谢……")
	elif r["birthday"]:
		npc.play_emote("sing")
		npc.say("你记得我的生日！太感动了~")
	elif r["liked"]:
		npc.play_emote("happy")
		npc.say("哇！我最喜欢%s了！" % GameState.item_name(item))
	else:
		npc.play_emote("wave")
		npc.say("谢谢你的%s~" % GameState.item_name(item))
	ui.show_toast("%s 好感 +%d（现在 %d）" % [npc.display_name, r["gain"], GameState.affinity(npc.display_name)])
	for rw in r["rewards"]:
		ui.show_toast("%s 回赠了你 %s！" % [npc.display_name, rw])
		ui.add_chat_line("", "【回礼】%s 送给你 %s" % [npc.display_name, rw], Color(1, 0.85, 0.5))


# ---------- 接果子小游戏 ----------

func _build_minigame() -> void:
	game_panel = ui._panel()
	ui._centered(game_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	game_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl: Label = ui._label("城堡小游戏：接果子", 22)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(ui._button("离开", _close_minigame))
	v.add_child(title)
	game_view = preload("res://scripts/minigame.gd").new()
	game_view.finished.connect(_on_minigame_finished)
	v.add_child(game_view)
	game_result = HBoxContainer.new()
	game_result_label = ui._label("", 17)
	game_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_result.add_child(game_result_label)
	game_result.add_child(ui._button("再玩一次", _start_minigame))
	v.add_child(game_result)
	game_panel.visible = false


func open_minigame_intro() -> void:
	var left := GameState.catch_plays_left()
	var reward_text := "今天还有 %d 次奖励机会（得分 ×2 摩尔豆，最多 120）。" % left if left > 0 else "今天的奖励次数用完啦，不过还可以玩着练手~"
	ui.show_dialog("城堡大门", "接果子：用鼠标或 A / D 移动篮子，30 秒内接住掉下来的果子！\n普通果子 +1，金果子 +5，坏果子 -2。" + reward_text + "\n最高纪录：%d 分" % GameState.best_catch,
		[["开始游戏", _start_minigame], ["下次再说", ui._noop]])


func _start_minigame() -> void:
	ui.close_popups()
	game_result_label.text = "移动篮子接果子！"
	game_panel.visible = true
	GameState.input_locked = true
	game_view.start()
	Sfx.play("door")


func _on_minigame_finished(score: int) -> void:
	var r := GameState.finish_catch(score)
	var msg := "时间到！得分 %d" % score
	if r[2]:
		msg += "  · 新纪录！"
	if int(r[0]) > 0:
		msg += "  · 获得 %d 摩尔豆、%d 经验" % [r[0], r[1]]
	else:
		msg += "  · 今天的奖励次数用完了"
	game_result_label.text = msg
	Sfx.play("catch" if score >= 20 else "harvest")
	if ui.player != null:
		ui.player.play_emote("happy" if score >= 15 else "wave")


func _close_minigame() -> void:
	if game_panel == null:
		return
	if game_view.active:
		game_view.active = false
	game_panel.visible = false
	GameState.input_locked = false


# ---------- 留言板 ----------

func _build_board() -> void:
	board_panel = ui._panel()
	ui._centered(board_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	board_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl: Label = ui._label("广场留言板", 22)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(ui._button("关闭", func(): board_panel.visible = false))
	v.add_child(title)
	board_scroll = ScrollContainer.new()
	board_scroll.custom_minimum_size = Vector2(520, 300)
	board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_list = VBoxContainer.new()
	board_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_list.add_theme_constant_override("separation", 6)
	board_scroll.add_child(board_list)
	v.add_child(board_scroll)
	var hb := HBoxContainer.new()
	board_edit = LineEdit.new()
	board_edit.max_length = 40
	board_edit.placeholder_text = "写点什么吧（最多 40 字）"
	board_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_edit.text_submitted.connect(func(_t): _post_board())
	hb.add_child(board_edit)
	hb.add_child(ui._button("贴上去", _post_board))
	v.add_child(hb)
	board_panel.visible = false
	Net.board_changed.connect(func():
		if board_panel.visible:
			_refresh_board())


func open_board() -> void:
	ui.close_popups()
	_refresh_board()
	board_panel.visible = true


func _refresh_board() -> void:
	for c in board_list.get_children():
		c.queue_free()
	var b := Net.current_board()
	if b.is_empty():
		board_list.add_child(ui._label("还没有人留言，来写第一条吧！", 16))
	var colors := [Color(1, 0.97, 0.75), Color(0.85, 0.94, 1), Color(1, 0.88, 0.9), Color(0.88, 1, 0.88)]
	for i in range(b.size() - 1, -1, -1):
		var m: Dictionary = b[i]
		var note := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[i % colors.size()]
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		note.add_theme_stylebox_override("panel", sb)
		var l: Label = ui._label("%s（第%d天）：%s" % [m["name"], int(m["day"]), m["text"]], 16)
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size = Vector2(480, 0)
		note.add_child(l)
		board_list.add_child(note)


func _post_board() -> void:
	var text := board_edit.text.strip_edges()
	board_edit.text = ""
	board_edit.release_focus()
	if text == "":
		return
	Net.post_board(text)
	Sfx.play("pop")
	ui.show_toast("留言已贴到留言板上")
	if not Net.is_online() or multiplayer.is_server():
		_refresh_board()
