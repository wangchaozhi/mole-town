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

	print("[钓鱼]")
	ui.start_fishing(main.pond.position)
	check(ui.fishing and p.fishing, "开始钓鱼")
	ui.fish_timer = 0.0
	await _frames(2)
	check(ui.fish_phase == 1, "鱼上钩")
	ui.fish_marker = ui.fish_zone.x + ui.fish_zone.y / 2.0
	ui.fish_speed = 0.0
	var caught := 0
	for f in GameState.FISH:
		caught += GameState.count(f)
	ui._reel()
	var caught2 := 0
	for f in GameState.FISH:
		caught2 += GameState.count(f)
	check(caught2 == caught + 1, "在绿区收杆钓到东西")
	ui._stop_fishing()
	check(not p.fishing, "结束钓鱼")

	b = GameState.beans
	ui.start_fishing(main.pond.position)
	ui._fish_treasure()
	check(GameState.beans >= b + 100 and "lucky" in GameState.achievements, "钓到宝箱（摩尔豆 + 成就）")
	ui._stop_fishing()

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

	print("[拉姆]")
	var lahm = get_tree().get_first_node_in_group("my_lahm")
	GameState.lahm_hunger = 30.0
	var exp0 := GameState.lahm_exp
	lahm.interact(p)
	check(GameState.lahm_hunger > 30.0 and GameState.lahm_exp > exp0, "喂拉姆加饱食度和亲密度")

	ui.shop.lahm_acc("bow")
	check(GameState.lahm_acc == "bow" and "bow" in GameState.owned_lahm_accs, "给拉姆买蝴蝶结并戴上")
	GameState.set_lahm_acc("none")

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
