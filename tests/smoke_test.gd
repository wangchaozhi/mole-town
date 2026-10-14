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
	ui.creator_name.text = "测试员"
	ui._pick_color(GameState.BODY_COLORS[2])
	ui._finish_creator()
	ui._close_all()
	check(GameState.player_name == "测试员", "名字已保存")
	check(p.display_name == "测试员", "玩家头顶名字更新")

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
	check(GameState.count("pumpkin") == 0 and GameState.beans == b + price * 2, "卖出作物")
	ui.shop.wear("red_cap")
	check(GameState.hat == "red_cap" and p.hat == "red_cap", "买帽子并戴上")

	print("[拉姆]")
	var lahm = get_tree().get_first_node_in_group("my_lahm")
	GameState.lahm_hunger = 30.0
	var exp0 := GameState.lahm_exp
	lahm.interact(p)
	check(GameState.lahm_hunger > 30.0 and GameState.lahm_exp > exp0, "喂拉姆加饱食度和亲密度")

	print("[任务]")
	GameState.quest = {"kind": "harvest", "item": "carrot", "need": 1, "have": 0, "reward": 30}
	GameState.report("harvest", "carrot")
	check(GameState.quest_done(), "完成任务")
	b = GameState.beans
	var r := GameState.claim_quest()
	check(GameState.beans >= b + r and not GameState.quest_done(), "领取任务奖励并刷新任务")

	print("[等级]")
	GameState.add_exp(GameState.exp_for_level(3) - GameState.player_exp)
	check(GameState.player_level == 3 and GameState.is_unlocked("pumpkin"), "升到 3 级解锁南瓜")

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
	ui._start_minigame()
	check(GameState.input_locked and ui.game_view.active, "开始小游戏并锁定移动")
	var gv = ui.game_view
	gv.spawn_timer = 99.0
	gv.fruits = [{"pos": Vector2(gv.basket_x, gv.H - 70), "speed": 200.0, "kind": "gold"}]
	gv.time_left = 0.5
	await get_tree().create_timer(1.0).timeout  # 无头模式帧很快，按真实时间等
	check(not gv.active and gv.score == 5 and GameState.best_catch >= 5, "接到金果子 +5 并结算")
	ui._close_minigame()
	check(not GameState.input_locked, "离开小游戏解锁移动")

	print("[留言板]")
	var n0: int = GameState.board.size()
	Net.post_board("冒烟测试留言")
	check(GameState.board.size() == n0 + 1 and GameState.board[-1]["name"] == "测试员", "单机发布留言")
	ui.open_board()
	check(ui.board_panel.visible and ui.board_list.get_child_count() > 0, "打开留言板")
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

	print("[存档]")
	GameState.save_game()
	var snapshot := {"beans": GameState.beans, "level": GameState.player_level, "hat": GameState.hat, "name": GameState.player_name}
	GameState.beans = 0
	GameState.player_level = 1
	check(GameState.load_game(), "读取存档")
	check(GameState.beans == snapshot["beans"] and GameState.player_level == snapshot["level"] \
		and GameState.hat == snapshot["hat"] and GameState.player_name == snapshot["name"], "存档读档数据一致")
