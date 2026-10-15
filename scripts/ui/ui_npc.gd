extends Node
## NPC 对话：乐乐的任务、店长、国王的每周挑战、旅行商人、扭蛋机。由 ui.gd 创建，ui 提供对话框和通用工具。

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

var ui  # ui.gd


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
			ui.show_dialog(_npc_title(npc), "欢迎光临摩尔百货！今天%s收购价特别高（×1.5），%s种子打 6 折哦~\n种子、拉姆果、漂亮的帽子，应有尽有，作物和鱼也可以卖给我。" % [GameState.item_name(m["hot"]), GameState.item_name(m["sale"])],
				[["看看商品", ui.open_shop], ["送礼物", ui.act.open_npc_gift.bind(npc)], ["下次再来", ui._noop]])
		_:
			var text: String = TIPS.pick_random()
			if GameState.affinity(npc.display_name) >= 50 and randf() < 0.4:
				text = "我们是好朋友啦！悄悄告诉你：" + text
			ui.show_dialog(_npc_title(npc), text, [["再聊聊", on_npc_interact.bind(npc)], ["送礼物", ui.act.open_npc_gift.bind(npc)], ["再见", ui._noop]])


func _merchant_dialog(npc) -> void:
	var lines := PackedStringArray()
	var opts := []
	for i in GameState.MERCHANT_STOCK.size():
		var it: Dictionary = GameState.MERCHANT_STOCK[i]
		lines.append("· %s ×%d  %d豆：%s" % [GameState.item_name(str(it["id"])), int(it["n"]), int(it["price"]), it["desc"]])
		opts.append(["买%s" % GameState.item_name(str(it["id"])), _merchant_buy.bind(i, npc)])
	opts.append(["再见", ui._noop])
	ui.show_dialog("旅行商人阿布", "周末限定小摊！（你有 %d 豆）\n" % GameState.beans + "\n".join(lines), opts)


func _merchant_buy(i: int, npc) -> void:
	ui.show_toast(GameState.merchant_buy(i))
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
		ui.show_dialog(_npc_title(npc), "哇，你完成了任务！真是能干的小摩尔~ 这是给你的奖励！",
			[["领取奖励", _claim_quest.bind(npc)]])
	else:
		ui.show_dialog(_npc_title(npc), "你好呀，小摩尔！能帮我一个忙吗？\n" + GameState.quest_text(),
			[["交给我吧！", ui._noop], ["换一个任务（10豆）", _reroll_quest.bind(npc)], ["送礼物", ui.act.open_npc_gift.bind(npc)]])


func _claim_quest(npc) -> void:
	var r := GameState.claim_quest()
	ui.show_toast("获得 %d 摩尔豆！" % r)
	npc.say("谢谢你！下一个任务也拜托啦~")


func _reroll_quest(npc) -> void:
	if GameState.spend_beans(10):
		GameState.new_quest()
		_lele_dialog(npc)
	else:
		ui.show_toast("摩尔豆不够啦")


## 点湖面开始钓鱼（main.gd 通过 call_group 调用）


func open_gacha() -> void:
	ui.show_dialog("扭蛋机", "%d 摩尔豆扭一次！可能扭到：摩尔豆、种子、拉姆果、家具……\n还有扭蛋限定的帽子「兔耳朵」和「小黄鸡」哦！（你有 %d 豆）" % [GameState.GACHA_PRICE, GameState.beans],
		[["扭一次", _gacha_spin], ["下次再来", ui._noop]])


func _gacha_spin() -> void:
	var r := GameState.gacha_spin()
	if r["ok"]:
		Sfx.play("gift")
		var g = get_tree().get_first_node_in_group("gacha")
		if g != null:
			g.play_spin()
	ui.show_dialog("扭蛋机", str(r["text"]), [["再扭一次", _gacha_spin], ["不扭了", ui._noop]])


# ---------- 国王的每周挑战 ----------

func _king_dialog(npc) -> void:
	var w := GameState.weekly()
	var prog := GameState.weekly_progress()
	var head := "哈哈，小摩尔，欢迎来到我的城堡！\n本周挑战：%s（%d/%d）  奖励 %d 摩尔豆" % [w["text"], prog, int(w["target"]), GameState.WEEKLY_REWARD]
	if GameState.weekly_claimed:
		ui.show_dialog("摩尔国王", head + "\n这周的奖励你已经领过啦，下周再来挑战吧！", [["好的", ui._noop]])
	elif GameState.weekly_done():
		ui.show_dialog("摩尔国王", head + "\n了不起！你完成了本周的挑战！", [["领取奖励", _claim_weekly.bind(npc)]])
	else:
		ui.show_dialog("摩尔国王", head + "\n每 7 天换一个挑战，加油哦！", [["我会努力的！", ui._noop]])


func _claim_weekly(npc) -> void:
	var had_trophy := GameState.count("furn_trophy")
	if GameState.claim_weekly():
		Sfx.play("catch")
		npc.play_emote("happy")
		npc.say("这是你应得的！")
		var extra := "，还有一座金奖杯（放进背包了，可以摆在小院里）" if GameState.count("furn_trophy") > had_trophy else ""
		ui.show_toast("获得 %d 摩尔豆%s！" % [GameState.WEEKLY_REWARD, extra])
