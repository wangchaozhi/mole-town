extends Node
## 聊天：左下角的聊天框和聊天记录（30 秒后淡出），附近的 NPC 会随口回一句。由 ui.gd 创建。

const CHAT := [
	"今天天气真好呀~", "我刚种了一片草莓！", "你的拉姆好可爱！", "一起去钓鱼吧？",
	"摩尔豆好难攒呀……", "城堡里好像住着一位大人物。", "嘿嘿~", "你好呀，新朋友！",
]

var ui  # ui.gd
var chat_edit: LineEdit
var chat_log: VBoxContainer


func build() -> void:
	var p: PanelContainer = ui._panel()
	ui._place(p, [0, 1, 0, 1], [12, -12, 12, -12], true)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hb := HBoxContainer.new()
	p.add_child(hb)
	chat_edit = LineEdit.new()
	chat_edit.custom_minimum_size = Vector2(200, 0)
	chat_edit.placeholder_text = "按回车聊天……"
	chat_edit.max_length = 40
	chat_edit.text_submitted.connect(send)
	hb.add_child(chat_edit)
	hb.add_child(ui._button("发送", func(): send(chat_edit.text)))
	hb.add_child(ui._button("表情 (E)", ui.toggle_emotes))

	# 聊天记录（聊天框上方）
	chat_log = VBoxContainer.new()
	ui._place(chat_log, [0, 1, 0, 1], [16, -76, 16, -76])
	chat_log.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chat_log.add_theme_constant_override("separation", 2)


func add_line(who: String, text: String, col: Color = Color.WHITE) -> void:
	var l: Label = ui._label(("%s：%s" % [who, text]) if who != "" else text, 15)
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


func send(text: String) -> void:
	text = text.strip_edges()
	chat_edit.text = ""
	chat_edit.release_focus()
	if text == "" or ui.player == null:
		return
	ui.player.say(text)
	add_line(GameState.player_name, text, Color(1, 1, 0.85))
	if Net.is_online():
		Net.send_chat(text)
	var best = null
	var best_d := 400.0
	for npc in get_tree().get_nodes_in_group("npcs"):
		var d: float = npc.position.distance_to(ui.player.position)
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
