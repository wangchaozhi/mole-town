extends Node
## 摩尔百货界面：买种子、卖东西、帽子、家具、拉姆用品。由 ui.gd 创建，ui 提供通用的面板 / 按钮工具。

var ui  # ui.gd
var panel: PanelContainer
var list: VBoxContainer
var beans_label: Label
var tab := "seeds"


func build() -> void:
	panel = ui._panel()
	ui._centered(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := HBoxContainer.new()
	var tl: Label = ui._label("摩尔百货", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	beans_label = ui._label("", 17)
	title.add_child(beans_label)
	title.add_child(ui._button("关闭", hide))
	v.add_child(title)
	var tabs := HBoxContainer.new()
	for t in [["买种子", "seeds"], ["卖东西", "sell"], ["帽子", "hats"], ["家具", "furniture"], ["拉姆用品", "lahm"]]:
		tabs.add_child(ui._button(t[0], set_tab.bind(t[1])))
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	v.add_child(scroll)
	panel.visible = false


func open() -> void:
	ui.close_popups()
	panel.visible = true
	populate()


func hide() -> void:
	panel.visible = false


func is_open() -> bool:
	return panel != null and panel.visible


func refresh_beans() -> void:
	if is_open():
		beans_label.text = "摩尔豆：%d  " % GameState.beans


func set_tab(t: String) -> void:
	tab = t
	populate()


func _row(text: String, buttons: Array) -> void:
	var hb := HBoxContainer.new()
	var l: Label = ui._label(text, 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	for o in buttons:
		var b: Button = ui._button(o[0], o[1])
		if o.size() > 2 and o[2]:
			b.disabled = true
		hb.add_child(b)
	list.add_child(hb)
	list.add_child(HSeparator.new())


func populate() -> void:
	for c in list.get_children():
		c.queue_free()
	beans_label.text = "摩尔豆：%d  " % GameState.beans
	var noop: Callable = ui._noop
	match tab:
		"seeds":
			for id in GameState.CROPS:
				var c: Dictionary = GameState.CROPS[id]
				var price := GameState.seed_price(id)
				var tag := "  【今日特价 6 折】" if GameState.market()["sale"] == id else ""
				if GameState.in_season(id):
					tag += "  【当季，长得快】"
				var info := "%s种子   %d豆%s\n约%d秒成熟 · 今日收购价%d豆" % [c["name"], price, tag, int(c["grow_time"]), GameState.sell_price(id)]
				if GameState.is_unlocked(id):
					_row(info, [["买1个", buy.bind("seed_" + id, price, 1)], ["买5个", buy.bind("seed_" + id, price, 5)]])
				else:
					_row(info, [["Lv%d 解锁" % int(c["level"]), noop, true]])
		"sell":
			var any := false
			for id in GameState.inventory.keys():
				var p := GameState.sell_price(id)
				if p > 0:
					any = true
					var trend := ""
					if GameState.CROPS.has(id):
						var mlt := GameState.price_mult(id)
						trend = "  【今日热门】" if GameState.market()["hot"] == id else ("  ↑" if mlt > 1.01 else ("  ↓" if mlt < 0.99 else ""))
					_row("%s ×%d   单价%d豆%s" % [GameState.item_name(id), GameState.count(id), p, trend],
						[["卖1个", sell.bind(id, 1)], ["全部卖出", sell.bind(id, -1)]])
			if not any:
				list.add_child(ui._label("没有可以卖的东西。去农场种菜或者去湖边钓鱼吧！", 16))
		"hats":
			for id in GameState.HATS:
				var h: Dictionary = GameState.HATS[id]
				var owned: bool = id in GameState.owned_hats
				var wearing: bool = GameState.hat == id
				var label := "%s%s" % [h["name"], "" if owned else "   %d豆" % h["price"]]
				if wearing:
					_row(label, [["穿戴中", noop, true]])
				elif owned:
					_row(label, [["穿戴", wear.bind(id)]])
				elif not GameState.hat_unlocked(id):
					_row(label, [["Lv%d 解锁" % int(h.get("level", 1)), noop, true]])
				else:
					_row(label, [["购买并穿戴", wear.bind(id)]])
		"furniture":
			list.add_child(ui._label("买好的家具在背包里点「摆放」，放到农场旁边的「我的小院」里。好友串门时能看到哦！", 15))
			for id in GameState.FURNITURE:
				var f: Dictionary = GameState.FURNITURE[id]
				if not f.get("shop", true):
					continue
				var have := GameState.count("furn_" + id)
				var info := "%s   %d豆%s" % [f["name"], f["price"], "（背包里有 %d 个）" % have if have > 0 else ""]
				if GameState.player_level >= int(f["level"]):
					_row(info, [["购买", buy.bind("furn_" + id, int(f["price"]), 1)]])
				else:
					_row(info, [["Lv%d 解锁" % int(f["level"]), noop, true]])
		"lahm":
			var fp := GameState.LAHM_FRUIT_PRICE
			_row("拉姆果   %d豆\n拉姆最爱吃的果子，恢复40点饱食度（你有 %d 个）" % [fp, GameState.count("lahm_fruit")],
				[["买1个", buy.bind("lahm_fruit", fp, 1)], ["买5个", buy.bind("lahm_fruit", fp, 5)]])
			for aid in GameState.LAHM_ACCS:
				if aid == "none":
					continue
				var a: Dictionary = GameState.LAHM_ACCS[aid]
				var owned: bool = aid in GameState.owned_lahm_accs
				var text := "拉姆的%s%s" % [a["name"], "" if owned else "   %d豆" % int(a["price"])]
				if GameState.lahm_acc == aid:
					_row(text, [["摘下", lahm_acc.bind("none")]])
				elif owned:
					_row(text, [["戴上", lahm_acc.bind(aid)]])
				else:
					_row(text, [["购买并戴上", lahm_acc.bind(aid)]])


func buy(id: String, price: int, n: int) -> void:
	if GameState.spend_beans(price * n):
		GameState.add_item(id, n)
		ui.show_toast("买到了 %s ×%d" % [GameState.item_name(id), n])
		if id.begins_with("seed_"):
			GameState.tutorial_event("buy_seed")
	else:
		ui.show_toast("摩尔豆不够啦！")
	populate()


func sell(id: String, n: int) -> void:
	if n < 0:
		n = GameState.count(id)
	var p := GameState.sell_price(id)
	if GameState.remove_item(id, n):
		GameState.add_beans(p * n)
		ui.show_toast("卖掉 %s ×%d，获得 %d 摩尔豆" % [GameState.item_name(id), n, p * n])
	populate()


func wear(id: String) -> void:
	if not id in GameState.owned_hats:
		var price: int = GameState.HATS[id]["price"]
		if not GameState.spend_beans(price):
			ui.show_toast("摩尔豆不够啦！")
			return
		GameState.owned_hats.append(id)
		GameState.check_achievements()
		ui.show_toast("买到了 %s！" % GameState.HATS[id]["name"])
	GameState.hat = id
	GameState.hat_changed.emit()
	populate()


## 给拉姆买 / 换饰品（再点一次「佩戴中」就摘下来）
func lahm_acc(id: String) -> void:
	if not id in GameState.owned_lahm_accs:
		var price: int = GameState.LAHM_ACCS[id]["price"]
		if not GameState.spend_beans(price):
			ui.show_toast("摩尔豆不够啦！")
			return
		GameState.owned_lahm_accs.append(id)
		ui.show_toast("给拉姆买了%s！" % GameState.LAHM_ACCS[id]["name"])
	GameState.set_lahm_acc(id)
	populate()
