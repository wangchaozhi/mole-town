extends Node
## 烹饪界面：列出所有菜谱、需要的食材和背包里的数量，食材够了就能做。由 ui.gd 创建。

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
	var tl: Label = ui._label("小厨房", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	title.add_child(ui._button("关闭", close))
	v.add_child(title)
	v.add_child(ui._label("用收获的作物和鱼做菜：卖得更贵，也是拉姆和 NPC 最爱的礼物。", 15))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	v.add_child(scroll)
	panel.visible = false


func open() -> void:
	ui.close_popups()
	refresh()
	panel.visible = true


func close() -> void:
	panel.visible = false


func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	for id in GameState.DISHES:
		var d: Dictionary = GameState.DISHES[id]
		var parts := PackedStringArray()
		var needs: Dictionary = d["needs"]
		for k in needs:
			parts.append("%s %d/%d" % [GameState.item_name(k), GameState.count(k), int(needs[k])])
		var hb := HBoxContainer.new()
		var l: Label = ui._label("%s   售价%d豆（已有 %d 份）\n需要：%s" % [d["name"], int(d["sell"]), GameState.count(id), "，".join(parts)], 15)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		var b: Button = ui._button("做一份", cook.bind(id))
		b.disabled = not GameState.can_cook(id)
		hb.add_child(b)
		list.add_child(hb)
		list.add_child(HSeparator.new())


func cook(id: String) -> void:
	if not GameState.cook(id):
		ui.show_toast("食材不够哦")
		return
	Sfx.play("harvest")
	ui.show_toast("做好了一份%s！" % GameState.item_name(id))
	var stove = ui.get_tree().get_first_node_in_group("stove")
	if stove != null:
		stove.puff()
	if ui.player != null:
		ui.player.play_emote("happy")
	refresh()
