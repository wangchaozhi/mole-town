extends Node
## 冒烟测试：启动真正的游戏场景，把主要玩法挨个跑一遍，最后打印结果并用退出码表示成败。
## 运行：godot --headless --path . res://tests/smoke_test.tscn -- --profile=smoke

var failures := 0
var passes := 0
var main = null
var ui = null


var is_runner := false


func _ready() -> void:
	if not is_runner:
		# 测试场景本身会在切换场景时被释放，所以另建一个挂在 root 下的执行者
		var runner = load("res://tests/smoke_test.gd").new()
		runner.is_runner = true
		get_tree().root.add_child.call_deferred(runner)
		return
	_start()


func _start() -> void:
	GameState.reset_game()
	get_tree().change_scene_to_file("res://main.tscn")
	await _frames(5)
	main = get_tree().current_scene
	ui = main.ui
	await _run()
	print("\n==== 冒烟测试：%d 通过，%d 失败 ====" % [passes, failures])
	GameState.reset_game()
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("  ✓ ", what)
	else:
		failures += 1
		print("  ✗ 失败：", what)


func _run() -> void:
	GameState.weather_timer = 9999.0
	var p = main.player

	print("[捏脸]")
	ui.profile.creator_name.text = "测试员"
	ui.profile._pick_color(GameState.BODY_COLORS[2])
	ui.profile._finish_creator()
	ui._close_all()
	check(GameState.player_name == "测试员", "名字已保存")
	check(p.display_name == "测试员", "玩家头顶名字更新")
	check(GameState.tutorial_active() and ui.tut_box.visible, "新玩家有新手引导")
	GameState.tutorial_event("water")
	check(GameState.tutorial_step == 0, "不是当前步骤的事件不推进引导")
	GameState.tutorial_event("plant")
	check(GameState.tutorial_step == 1, "完成当前步骤推进引导")
	GameState.skip_tutorial()
	check(not GameState.tutorial_active() and not ui.tut_box.visible, "跳过新手引导")

	print("[农场]")
	var plot = main.plots[0]
	var seeds := GameState.count("seed_carrot")
	plot.interact(p)
	check(plot.crop == "carrot" and GameState.count("seed_carrot") == seeds - 1, "播种消耗一颗种子")
	plot.interact(p)
	check(plot.water_time > 0.0, "浇水")
	plot.growth = 1.0
	plot.interact(p)
	check(plot.crop == "" and GameState.count("carrot") >= 1, "收获进背包")
	check("first_harvest" in GameState.achievements, "成就「第一次收获」")
	plot.crop = "carrot"
	plot.growth = 0.5
	plot.bug = true
	var b := GameState.beans
	plot.interact(p)
	check(not plot.bug and GameState.beans == b + 3, "抓虫 +3 摩尔豆")

	print("[天气]")
	plot.water_time = 0.0
	GameState.set_raining(true)
	await _frames(2)
	check(plot.water_time > 0.0, "下雨自动浇水")
	GameState.set_raining(false)
	GameState.set_sky("wind")
	check(GameState.sky == "wind", "大风天")
	GameState.set_sky("fog")
	check(GameState.sky == "fog", "起雾")
	GameState.set_sky("")

	print("[钓鱼]")
	ui.start_fishing(main.pond.position)
	check(ui.fishing and p.fishing, "开始钓鱼")
	ui.fish.fish_timer = 0.0
	await _frames(2)
	check(ui.fish.fish_phase == 1, "鱼上钩")
	ui.fish.fish_marker = ui.fish.fish_zone.x + ui.fish.fish_zone.y / 2.0
	ui.fish.fish_speed = 0.0
	var caught := 0
	for f in GameState.FISH:
		caught += GameState.count(f)
	var beans_before := GameState.beans
	ui.fish._reel()
	var caught2 := 0
	for f in GameState.FISH:
		caught2 += GameState.count(f)
	# 约 9% 的概率钓到宝箱 / 漂流瓶（给摩尔豆而不是鱼），两种都算钓到东西
	check(caught2 == caught + 1 or GameState.beans > beans_before, "在绿区收杆钓到东西")
	ui.fish._stop_fishing()
	check(not p.fishing, "结束钓鱼")

	b = GameState.beans
	ui.start_fishing(main.pond.position)
	ui.fish._fish_treasure()
	check(GameState.beans >= b + 100 and "lucky" in GameState.achievements, "钓到宝箱（摩尔豆 + 成就）")
	ui.fish._stop_fishing()

	print("[商店]")
	GameState.add_beans(500)
	b = GameState.beans
	var sp := GameState.seed_price("strawberry")
	ui.shop.buy("seed_strawberry", sp, 2)
	check(GameState.beans == b - sp * 2 and GameState.count("seed_strawberry") == 2, "买种子（含当日价格）")
	GameState.add_item("pumpkin", 2)
	b = GameState.beans
	var price := GameState.sell_price("pumpkin")
	ui.shop.sell("pumpkin", -1)
	check(GameState.count("pumpkin") == 0 and GameState.beans >= b + price * 2, "卖出作物")
	ui.shop.wear("red_cap")
	check(GameState.hat == "red_cap" and p.hat == "red_cap", "买帽子并戴上")

	GameState.add_exp(GameState.exp_for_level(6) - GameState.player_exp)
	GameState.add_beans(2000)
	check(GameState.buy_rod(1) and GameState.rod_level == 1 and not GameState.buy_rod(1), "买好鱼竿（不能重复买）")
	check(GameState.buy_sprinkler() and GameState.has_sprinkler, "买自动洒水器")

	check(not main.plots[12].visible and not main.plots[12].hit_test(main.plots[12].position), "没买温室时温室地块不可用")
	GameState.add_beans(1000)
	check(GameState.buy_greenhouse() and GameState.has_greenhouse, "买温室")
	await _frames(2)
	check(main.plots.size() == 16 and main.plots[12].visible, "温室多出 4 块地")

	var fp = main.plots[13]
	GameState.add_item("seed_carrot")
	GameState.add_item("fertilizer")
	GameState.selected_seed = "carrot"
	fp.bug = false
	fp.crop = ""
	fp.interact(p)  # 种
	fp.interact(p)  # 浇水
	fp.interact(p)  # 施肥
	check(fp.fert and GameState.count("fertilizer") == 0, "给作物施肥")
	fp.growth = 1.0
	var carrots := GameState.count("carrot")
	fp.interact(p)
	check(GameState.count("carrot") - carrots >= 2 and not fp.fert, "施过肥的作物收获至少 2 个")
	GameState.add_item("seed_carrot")
	fp.interact(p)
	fp.growth = 1.0
	fp.giant = true
	carrots = GameState.count("carrot")
	fp.interact(p)
	check(GameState.count("carrot") - carrots >= 4 and not fp.giant and "giant" in GameState.achievements, "巨型作物收获至少 4 个并解锁成就")

	print("[拉姆]")
	var lahm = get_tree().get_first_node_in_group("my_lahm")
	GameState.lahm_hunger = 30.0
	var exp0 := GameState.lahm_exp
	lahm.interact(p)
	check(GameState.lahm_hunger > 30.0 and GameState.lahm_exp > exp0, "喂拉姆加饱食度和亲密度")

	ui.shop.lahm_acc("bow")
	check(GameState.lahm_acc == "bow" and "bow" in GameState.owned_lahm_accs, "给拉姆买蝴蝶结并戴上")
	GameState.set_lahm_acc("none")

	GameState.lahm_hide_day = -1
	GameState.lahm_hunger = 100.0
	if GameState.lahm_level < 2:
		GameState.add_lahm_exp(GameState.LAHM_LEVELS[1] - GameState.lahm_exp)
	lahm.interact(p)  # 吃饱了摸摸它 → 邀请捉迷藏
	check(lahm.hiding and GameState.lahm_hide_day == GameState.day and not lahm.can_hide(), "摸摸拉姆开始捉迷藏（每天一次）")
	var hb0 := GameState.beans
	lahm.interact(p)
	check(not lahm.hiding and GameState.beans == hb0 + 30, "找到躲起来的拉姆有奖励")

	print("[任务]")
	GameState.quest = {"kind": "harvest", "item": "carrot", "need": 1, "have": 0, "reward": 30}
	GameState.report("harvest", "carrot")
	check(GameState.quest_done(), "完成任务")
	b = GameState.beans
	var r := GameState.claim_quest()
	check(GameState.beans >= b + r and not GameState.quest_done(), "领取任务奖励并刷新任务")

	GameState.quest = {"kind": "deliver", "item": "corn", "need": 2, "have": 0, "reward": 50}
	GameState.remove_item("corn", GameState.count("corn"))
	GameState.add_item("corn", 1)
	check(not GameState.quest_done(), "送货任务：东西不够时未完成")
	GameState.add_item("corn", 1)
	check(GameState.quest_done(), "送货任务：背包里够了就算完成")
	GameState.claim_quest()
	check(GameState.count("corn") == 0, "领奖时把东西交给乐乐")

	print("[等级]")
	GameState.add_exp(GameState.exp_for_level(3) - GameState.player_exp)
	check(GameState.player_level >= 3 and GameState.is_unlocked("pumpkin"), "3 级以上解锁南瓜")

	print("[小院]")
	GameState.add_item("furn_pot")
	main.start_placing("pot")
	main._try_place(Vector2(1200, 1150))
	check(GameState.home.size() == 1 and GameState.count("furn_pot") == 0, "摆放家具")
	main.store_furniture(0)
	check(GameState.home.is_empty() and GameState.count("furn_pot") == 1, "收起家具")

	print("[NPC 好感]")
	GameState.add_item("strawberry")
	var gr := GameState.gift_npc("乐乐", "strawberry")
	check(gr["ok"] and GameState.affinity("乐乐") == 15, "送乐乐喜欢的草莓 +15")
	check(not GameState.can_gift_npc("乐乐"), "同一天只能送一次")

	print("[签到]")
	GameState.last_signin = ""
	b = GameState.beans
	check(GameState.sign_in() > 0 and GameState.beans > b and not GameState.can_sign_in(), "每日签到")

	print("[键盘和传送]")
	main.teleport(Vector2(1600, 700))
	check(p.position.distance_to(Vector2(1600, 700)) < 1.0, "小地图传送")
	main.teleport(main.pond.position)
	check(not main.pond.contains(p.position), "传送到湖里会落在岸边")

	print("[表情]")
	ui.do_emote("wave")
	check(p.emote == "wave", "做表情")

	print("[接果子小游戏]")
	ui.act._start_minigame()
	check(GameState.input_locked and ui.act.game_view.active, "开始小游戏并锁定移动")
	var gv = ui.act.game_view
	gv.spawn_timer = 99.0
	gv.fruits = [{"pos": Vector2(gv.basket_x, gv.H - 70), "speed": 200.0, "kind": "gold"}]
	gv.time_left = 0.5
	await get_tree().create_timer(1.0).timeout  # 无头模式帧很快，按真实时间等
	check(not gv.active and gv.score == 5 and GameState.best_catch >= 5, "接到金果子 +5 并结算")
	ui.act._close_minigame()
	check(not GameState.input_locked, "离开小游戏解锁移动")

	print("[留言板]")
	var n0: int = GameState.board.size()
	Net.post_board("冒烟测试留言")
	check(GameState.board.size() == n0 + 1 and GameState.board[-1]["name"] == "测试员", "单机发布留言")
	ui.open_board()
	check(ui.act.board_panel.visible and ui.act.board_list.get_child_count() > 0, "打开留言板")
	ui._close_all()

	print("[节日]")
	var day0: int = GameState.day
	GameState.day = 7
	check(GameState.festival() == "fishing", "第 7 天是钓鱼大赛")
	b = GameState.beans
	for i in 5:
		GameState.contest_catch()
	check(GameState.contest_count == 5 and GameState.beans == b + 100, "钓鱼大赛钓到 5 条奖励 100 摩尔豆")
	GameState.day = 10
	check(GameState.festival() == "harvest", "第 10 天是丰收节")
	var base_price := roundi(int(GameState.CROPS["carrot"]["sell"]) * GameState.price_mult("carrot"))
	check(GameState.sell_price("carrot") > base_price, "丰收节收购价上涨")
	var c0 := GameState.count("carrot")
	plot.crop = "carrot"
	plot.growth = 1.0
	plot.bug = false
	plot.interact(p)
	check(GameState.count("carrot") >= c0 + 2, "丰收节收获至少 2 个")
	GameState.day = 8
	check(GameState.season_name() == "夏" and GameState.season_growth("corn") > 1.0, "夏天玉米当季长得快")
	GameState.day = 22
	check(GameState.season_name() == "冬" and GameState.season_growth("strawberry") < 1.0, "冬天不当季作物长得慢")
	GameState.day = day0

	print("[季节限定家具]")
	GameState.day = 22  # 冬天
	ui.open_shop()
	ui.shop.set_tab("furniture")
	await _frames(2)
	var furn_rows := []
	for row in ui.shop.list.get_children():
		if row is HBoxContainer:
			furn_rows.append(row.get_child(0).text)
	check(furn_rows.any(func(t): return "雪人" in t) and not furn_rows.any(func(t): return "南瓜灯" in t), "冬天的商店只卖雪人这件季节家具")
	ui._close_all()
	GameState.day = day0

	print("[NPC 作息]")
	var lele = null
	var shopkeeper = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.display_name == "乐乐":
			lele = n
		elif n.role == "shop":
			shopkeeper = n
	var minutes0: float = GameState.minutes
	GameState.minutes = 23.0 * 60.0
	lele.position = lele.sleep_spot
	await _frames(3)
	check(lele.sleeping and not shopkeeper.sleeping, "深夜乐乐睡觉，店长通宵营业")
	GameState.minutes = 7.0 * 60.0
	await _frames(3)
	check(not lele.sleeping, "早上乐乐醒来")
	GameState.minutes = minutes0

	print("[烹饪]")
	GameState.add_item("carrot", 2)
	var soup0 := GameState.count("carrot_soup")
	check(GameState.can_cook("carrot_soup") and GameState.cook("carrot_soup"), "用 2 个萝卜做萝卜汤")
	check(GameState.count("carrot_soup") == soup0 + 1 and GameState.sell_price("carrot_soup") > 0, "萝卜汤进背包且可以卖")
	GameState.remove_item("watermelon", GameState.count("watermelon"))
	check(not GameState.cook("watermelon_smoothie"), "食材不够时不能做")
	ui.open_kitchen()
	check(ui.kitchen.panel.visible and ui.kitchen.list.get_child_count() > 0, "打开小厨房")
	ui._close_all()

	print("[我的小屋]")
	main.home_action("home_door")
	check(main.inside and main.INTERIOR_WALK.has_point(p.position), "进入小屋")
	main.home_action("bed")
	GameState.minutes = 12.0 * 60.0
	main.home_action("bed")
	check(not GameState.input_locked and GameState.minutes < 12.5 * 60.0, "白天不能睡觉")
	var day_before := GameState.day
	GameState.minutes = 23.0 * 60.0
	main.home_action("bed")
	await get_tree().create_timer(2.5).timeout
	check(GameState.day == day_before + 1 and GameState.minutes < 6.5 * 60.0 and not GameState.input_locked, "晚上睡觉直接到第二天早上")
	main.home_action("exit_door")
	check(not main.inside and not main.INTERIOR_WALK.has_point(p.position), "走出小屋")

	print("[城堡大厅]")
	main.enter_room("castle")
	check(main.inside and main.room == "castle" and main.CastleHall.ROOM.has_point(p.position), "进入城堡大厅")
	var w: Dictionary = GameState.weekly()
	check(not GameState.weekly_done(), "每周挑战一开始没完成")
	if w["stat"] == "quests_done":
		GameState.quests_done += int(w["target"])
	else:
		GameState.stats[w["stat"]] = GameState.stat_value(w["stat"]) + int(w["target"])
	b = GameState.beans
	check(GameState.claim_weekly() and GameState.beans >= b + GameState.WEEKLY_REWARD, "完成每周挑战领奖")
	check(GameState.count("furn_trophy") == 1 and not GameState.claim_weekly(), "得到金奖杯，同一周不能重复领")
	main.exit_room()
	check(not main.inside and p.position.distance_to(main.ROOMS["castle"]["exit"]) < 1.0, "走出城堡回到大门口")

	print("[信箱]")
	var mail0: int = GameState.mail.size()
	GameState.add_mail("乐乐", "测试信件", "lahm_fruit", 2)
	check(GameState.mail.size() == mail0 + 1 and GameState.unread_mail() >= 1, "收到新信")
	var fruit0 := GameState.count("lahm_fruit")
	GameState.open_mail(GameState.mail.size() - 1)
	check(GameState.count("lahm_fruit") == fruit0 + 2 and GameState.open_mail(GameState.mail.size() - 1) == "", "拆信收礼物，不能重复领")
	ui.open_mail()
	check(ui.mailui.panel.visible, "打开信箱")
	ui._close_all()

	print("[随机事件]")
	GameState.minutes = 22.5 * 60.0
	main.events.start_shower()
	main.events.meteors.append([Vector2(400, 200), 1.0])
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(400, 200)
	main.events._unhandled_input(ev)
	check(main.events.wishes == 1, "点流星许愿")
	main.events.shower = 0.0
	GameState.minutes = 9.0 * 60.0
	main.events.spawn_lost_lahm()
	var lost = get_tree().get_first_node_in_group("lost_lahm")
	check(lost != null, "迷路的小拉姆出现")
	lost.interact(p)
	var lele_npc = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.role == "lele":
			lele_npc = n
	var aff0 := GameState.affinity("乐乐")
	main.teleport(lele_npc.position + Vector2(100, 0))
	await get_tree().create_timer(1.5).timeout
	check(get_tree().get_nodes_in_group("lost_lahm").is_empty() and GameState.affinity("乐乐") == aff0 + 10, "把小拉姆送回乐乐那里")

	print("[主线剧情]")
	GameState.story_step = 0
	GameState.story_count = 0
	for story_ev in ["talk_阿呆", "fish", "fish", "fish", "talk_摩尔国王", "cook", "talk_摩尔国王", "night_pond"]:
		GameState.story_event(story_ev)
	check(GameState.story_step == -1 and "star_pin" in GameState.owned_hats and "story" in GameState.achievements, "主线剧情走完：拿到星星发卡和成就")
	check(not GameState.story_event("fish"), "剧情完成后不再响应剧情事件")
	ui._close_all()

	print("[界面大小]")
	ui.set_ui_scale(1.3)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	check(ui.scale == Vector2(1.3, 1.3) and ui.root.size.is_equal_approx(vs / 1.3), "界面放大到 1.3 倍并铺满屏幕")
	ui.set_ui_scale(1.0)

	print("[界面]")
	# 把每个面板都打开关上一遍，界面代码里的错误会以 SCRIPT ERROR 出现在日志里
	ui.open_shop()
	for t in ["seeds", "sell", "hats", "furniture", "lahm"]:
		ui.shop.set_tab(t)
	check(ui.shop.is_open() and ui.shop.list.get_child_count() > 0, "商店各分页")
	ui.select_seed_index(1)
	check(GameState.selected_seed == "strawberry" and ui.seed_buttons["strawberry"].button_pressed, "数字键切换种子")
	ui.select_seed_index(0)
	ui._close_all()
	ui.toggle_collection()
	ui.show_signin_if_needed()
	ui.toggle_bag()
	ui.toggle_settings()
	ui.toggle_net()
	ui.toggle_emotes()
	ui.open_minigame_intro()
	ui.open_creator()
	ui.help_panel.visible = true
	await _frames(2)
	ui._close_all()
	ui.profile.creator_panel.visible = false
	check(not ui.help_panel.visible and not ui.bag_panel.visible, "所有面板都能打开和关闭")
	var xiaohuang = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.display_name == "小黄":
			xiaohuang = n
	GameState.add_item("corn")
	ui.act.open_npc_gift(xiaohuang)
	check(ui.act.gift_panel.visible, "打开给 NPC 送礼的面板")
	ui.act._give("corn", 1)
	check(GameState.affinity("小黄") == 15 and not ui.act.gift_panel.visible, "通过界面送小黄喜欢的玉米")
	var cm := GameState.roll_fish_size("big_fish")
	check(cm >= 30 and cm <= 62 and GameState.roll_fish_size("boot") == 0, "鱼的尺寸在范围内，破靴子没有尺寸")
	GameState.fish_records.erase("big_fish")
	check(not GameState.record_fish_size("big_fish", 40) and GameState.record_fish_size("big_fish", 45) \
		and not GameState.record_fish_size("big_fish", 41) and GameState.fish_records["big_fish"] == 45, "鱼的尺寸纪录")
	var leaf_day0 := GameState.day
	GameState.day = 16  # 秋天
	GameState.leaf_day = -1
	main.events.spawn_leaf_piles()
	var piles := get_tree().get_nodes_in_group("leaf_piles")
	check(piles.size() == 4, "秋天早上出现 4 堆落叶")
	var lb0 := int(GameState.stats.get("leaf_piles", 0))
	piles[0].interact(p)
	check(int(GameState.stats["leaf_piles"]) == lb0 + 1 and not piles[0].is_in_group("interactable"), "翻落叶堆找到东西")
	GameState.day = 2  # 春天：藏一棵四叶草
	GameState.leaf_day = -1
	main.events.spawn_leaf_piles()
	var clv = get_tree().get_first_node_in_group("clovers")
	check(clv != null and get_tree().get_nodes_in_group("leaf_piles").all(func(n): return n.is_queued_for_deletion()), "春天藏一棵四叶草、落叶堆清掉")
	clv.interact(p)
	check(GameState.is_lucky() and GameState.festival_text().contains("幸运日"), "找到四叶草变成幸运日")
	GameState.day = leaf_day0
	main.events.spawn_leaf_piles()  # 不是秋天了：清掉
	GameState.stats["fireflies"] = 9
	var ffly = preload("res://scripts/events/firefly.gd").new()
	main.ysort.add_child(ffly)
	var jar0 := GameState.count("furn_firefly_jar")
	ffly.interact(p)
	check(GameState.count("firefly") >= 1 and GameState.count("furn_firefly_jar") == jar0 + 1 and "fireflies" in GameState.achievements, "抓第 10 只萤火虫得到萤火虫灯和成就")
	GameState.add_beans(GameState.GACHA_PRICE)
	var gacha_r := GameState.gacha_spin()
	check(gacha_r["ok"] and int(GameState.stats["gacha"]) >= 1 and get_tree().get_first_node_in_group("gacha") != null, "扭蛋机扭一次")
	var poor := GameState.beans
	GameState.beans = 10
	check(not GameState.gacha_spin()["ok"] and GameState.beans == 10, "豆子不够不能扭蛋")
	GameState.beans = poor
	var md0 := GameState.day
	GameState.day = 6
	check(GameState.merchant_day() and not GameState.merchant_day(8), "旅行商人周末才来")
	GameState.add_beans(200)
	GameState.merchant_buy(0)
	var seeds_before := 0
	for cid in GameState.CROPS:
		seeds_before += GameState.count("seed_" + cid)
	GameState.open_mystery_seed()
	var seeds_after := 0
	for cid in GameState.CROPS:
		seeds_after += GameState.count("seed_" + cid)
	check(seeds_after == seeds_before + 2 and GameState.count("mystery_seed") == 0, "神秘种子袋开出 2 颗种子")
	GameState.day = md0
	GameState.set_title("giant")
	check(GameState.title == "giant" and p.title_label != null and p.title_label.text.contains("巨无霸"), "佩戴成就称号")
	GameState.set_title("not_done_xyz")
	check(GameState.title == "" and not p.title_label.visible, "没达成的成就不能当称号")
	GameState.day_log = {"harvest": 3, "fish": 2, "earned": 120}
	var mails0 := GameState.mail.size()
	GameState._daily_report()
	check(GameState.day_log.is_empty() and GameState.mail.size() > mails0 and str(GameState.mail[-1]["text"]).contains("收获了 3 个作物"), "每天早上收到昨日小结")
	GameState._daily_report()
	check(GameState.mail.size() == mini(mails0 + 1, 20), "什么都没做的日子不发小结")
	var bday_day0 := GameState.day
	GameState.day = 17 + 28  # 第二年嘟嘟的生日
	check(GameState.birthday_npc() == "嘟嘟" and GameState.festival_text().contains("嘟嘟的生日"), "NPC 生日按 28 天一年循环")
	GameState.add_item("small_fish")
	var bday_aff0 := GameState.affinity("嘟嘟")
	var br := GameState.gift_npc("嘟嘟", "small_fish")
	check(br["birthday"] and GameState.affinity("嘟嘟") - bday_aff0 == 30, "生日当天送礼好感翻倍")
	GameState.day = bday_day0

	print("[存档]")
	GameState.save_game()
	var snapshot := {"beans": GameState.beans, "level": GameState.player_level, "hat": GameState.hat, "name": GameState.player_name}
	GameState.beans = 0
	GameState.player_level = 1
	check(GameState.load_game(), "读取存档")
	check(GameState.beans == snapshot["beans"] and GameState.player_level == snapshot["level"] \
		and GameState.hat == snapshot["hat"] and GameState.player_name == snapshot["name"], "存档读档数据一致")
	GameState.save_game()  # 再存一次，确保有 .bak
	var bad := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	bad.store_string("{\"beans\": ")
	bad.close()
	GameState.beans = 0
	check(GameState.load_game() and GameState.beans == snapshot["beans"] and GameState.loaded_from_backup, "主存档损坏时从备份恢复")
	var SF = preload("res://scripts/data/save_fields.gd")
	GameState.save_game()
	var before_all := {}
	for k in SF.FIELDS:
		before_all[k] = JSON.stringify(GameState.get(k))
	GameState.beans = 1
	GameState.stats = {}
	GameState.home = []
	GameState.load_game()
	var diff := []
	for k in SF.FIELDS:
		if JSON.stringify(GameState.get(k)) != before_all[k]:
			diff.append(k)
	check(diff.is_empty(), "所有存档字段读写一致" + ("（不一致：%s）" % ", ".join(diff) if not diff.is_empty() else ""))
	var keep_name := GameState.player_name
	GameState.music_volume = 0.3
	GameState.best_catch = 99
	GameState.reset_game()
	check(GameState.player_name == keep_name and is_equal_approx(GameState.music_volume, 0.3) and GameState.best_catch == 0 		and GameState.beans == 100 and GameState.count("seed_carrot") == 5 and GameState.tutorial_step == 0, "重置存档：清空进度、保留名字和设置")
	GameState.music_volume = 0.6
