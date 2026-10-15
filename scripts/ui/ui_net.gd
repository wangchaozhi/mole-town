extends Node
## 联机界面：创建 / 加入房间、局域网房间列表、在线名单，点击其他玩家的菜单（打招呼、串门、送礼），串门时顶部的「回家」条。
## 由 ui.gd 创建，ui 提供通用的面板 / 按钮工具。

var ui  # ui.gd
var net_panel: PanelContainer
var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var net_status: Label
var net_list: Label
var rooms_list: VBoxContainer
var visit_bar: PanelContainer
var visit_label: Label


func build() -> void:
	net_panel = ui._panel()
	ui._centered(net_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	net_panel.add_child(v)
	var title := HBoxContainer.new()
	var tl: Label = ui._label("多人联机", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(ui._button("关闭", toggle_net))
	v.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	grid.add_child(ui._label("我的名字", 16))
	name_edit = LineEdit.new()
	name_edit.max_length = 10
	name_edit.text = GameState.player_name
	name_edit.custom_minimum_size = Vector2(300, 0)
	name_edit.text_submitted.connect(func(_t): _apply_name())
	name_edit.focus_exited.connect(_apply_name)
	grid.add_child(name_edit)
	grid.add_child(ui._label("房主 IP", 16))
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	grid.add_child(ip_edit)
	grid.add_child(ui._label("端口", 16))
	port_edit = LineEdit.new()
	port_edit.text = str(Net.DEFAULT_PORT)
	grid.add_child(port_edit)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(ui._button("创建房间", _on_host))
	hb.add_child(ui._button("加入房间", _on_join))
	hb.add_child(ui._button("断开", func(): Net.leave()))
	v.add_child(hb)

	v.add_child(ui._label("附近的房间（同一个局域网里的房主会自动出现在这里）", 15))
	rooms_list = VBoxContainer.new()
	v.add_child(rooms_list)
	Net.rooms_changed.connect(_refresh_rooms)
	net_status = ui._label("", 16)
	net_status.add_theme_color_override("font_color", Color(0.15, 0.45, 0.75))
	v.add_child(net_status)
	var ips := PackedStringArray()
	for a in IP.get_local_addresses():
		if "." in a and not a.begins_with("127.") and not a.begins_with("169.254."):
			ips.append(a)
	var tip: Label = ui._label("本机局域网 IP：%s\n房主把这个 IP 告诉小伙伴；同一台电脑测试就填 127.0.0.1。\n第一次创建房间时 Windows 防火墙可能会询问，请允许。" % (", ".join(ips) if ips.size() > 0 else "未知"), 14)
	tip.custom_minimum_size = Vector2(440, 0)
	tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(tip)
	net_list = ui._label("", 15)
	net_list.custom_minimum_size = Vector2(440, 0)
	net_list.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(net_list)
	net_panel.visible = false
	_build_visit_bar()
	Net.status_changed.connect(func(_t): refresh())
	Net.roster_changed.connect(refresh)
	refresh()


func toggle_net() -> void:
	net_panel.visible = not net_panel.visible
	if net_panel.visible:
		name_edit.text = GameState.player_name
		if not Net.is_online():
			Net.start_discovery()
	else:
		Net.stop_discovery()
	_refresh_rooms()


func _apply_name() -> void:
	var n := name_edit.text.strip_edges().left(10)
	if n == "" or n == GameState.player_name:
		return
	GameState.player_name = n
	if ui.player != null:
		ui.player.set_display_name(n)
	Net.send_info()


func _on_host() -> void:
	_apply_name()
	var err := Net.host(int(port_edit.text))
	if err != "":
		ui.show_toast(err)
	else:
		ui.add_chat_line("", "【系统】房间已创建，等待小伙伴加入", Color(1, 0.9, 0.4))


func _on_join() -> void:
	_apply_name()
	var err := Net.join(ip_edit.text.strip_edges(), int(port_edit.text))
	if err != "":
		ui.show_toast(err)


func refresh() -> void:
	if net_status == null:
		return
	net_status.text = "状态：" + Net.status
	if Net.is_online():
		ui.online_label.text = "联机中 · 在线 %d 人" % Net.players.size()
		var names := PackedStringArray()
		for id in Net.players:
			names.append(str(Net.players[id]["name"]) + ("（我）" if id == Net.my_id() else ""))
		net_list.text = "在线玩家：" + "、".join(names)
	else:
		ui.online_label.text = "单机模式 · 按 N 联机"
		net_list.text = ""


func on_remote_interact(m) -> void:
	var visit_opt: Array = ["回自己家", Net.leave_farm] if Net.visiting == m.peer_id else ["去TA家农场串门", _visit.bind(m)]
	ui.show_dialog(m.display_name, "这是来自远方的小摩尔「%s」！" % m.display_name, [
		["打招呼", _greet.bind(m)],
		visit_opt,
		["送礼物", ui.act.open_gift.bind(m)],
		["送 10 摩尔豆", _send_gift.bind(m)],
		["再见", ui._noop],
	])


func _visit(m) -> void:
	Net.visit(m.peer_id)
	ui.chat.send("我来你家农场串门啦~")


func _build_visit_bar() -> void:
	visit_bar = ui._panel()
	ui._place(visit_bar, [0.5, 0, 0.5, 0], [0, 12, 0, 12], true)
	visit_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	visit_bar.add_child(hb)
	visit_label = ui._label("", 17)
	visit_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(visit_label)
	hb.add_child(ui._button("回家", Net.leave_farm))
	visit_bar.visible = false
	Net.visit_changed.connect(_refresh_visit)


func _refresh_visit() -> void:
	visit_bar.visible = Net.visiting != 0
	if Net.visiting != 0:
		visit_label.text = "正在「%s」家农场做客" % Net.player_name(Net.visiting)
		ui.show_toast("帮好友浇水、抓虫能拿摩尔豆，成熟的作物可以摘一个~")
	else:
		ui.show_toast("回到了自己的农场")


func _greet(m) -> void:
	ui.chat.send("你好呀，%s！" % m.display_name)


func _send_gift(m) -> void:
	if GameState.spend_beans(10):
		Net.send_gift(m.peer_id, 10)
		ui.show_toast("送给 %s 10 摩尔豆" % m.display_name)
		ui.chat.send("送你 10 摩尔豆~")
	else:
		ui.show_toast("摩尔豆不够啦")


func _refresh_rooms() -> void:
	if rooms_list == null:
		return
	for c in rooms_list.get_children():
		c.queue_free()
	if Net.is_online():
		return
	if Net.rooms.is_empty():
		var l: Label = ui._label("正在寻找……（也可以在下面手动输入房主 IP）", 14)
		l.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
		rooms_list.add_child(l)
		return
	for id in Net.rooms:
		var r: Dictionary = Net.rooms[id]
		var hb := HBoxContainer.new()
		var l: Label = ui._label("%s 的房间 · %d 人 · %s" % [r["name"], int(r["players"]), r["ip"]], 15)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		hb.add_child(ui._button("加入", _join_room.bind(str(r["ip"]), int(r["port"]))))
		rooms_list.add_child(hb)


func _join_room(ip: String, port: int) -> void:
	_apply_name()
	Net.stop_discovery()
	ip_edit.text = ip
	port_edit.text = str(port)
	var err := Net.join(ip, port)
	if err != "":
		ui.show_toast(err)
