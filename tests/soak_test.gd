extends Node
## 浸泡测试：机器人以 8 倍速随机玩一段时间（走路、互动、钓鱼、做菜、表情、开关面板、换季、换天气），
## 期间任何脚本错误都会出现在日志里。结束时打印统计。
## 运行：godot --headless --path . res://tests/soak_test.tscn -- --profile=soak

const DURATION := 60.0  # 真实秒数

var is_runner := false
var main = null
var ui = null
var elapsed := 0.0
var actions := {}


func _ready() -> void:
	if not is_runner:
		var runner = load("res://tests/soak_test.gd").new()
		runner.is_runner = true
		get_tree().root.add_child.call_deferred(runner)
		return
	_start()


func _start() -> void:
	GameState.reset_game()
	get_tree().change_scene_to_file("res://main.tscn")
	for i in 5:
		await get_tree().process_frame
	main = get_tree().current_scene
	ui = main.ui
	ui.profile._finish_creator()
	ui._close_all()
	GameState.add_beans(2000)
	GameState.add_exp(3000)
	for k in ["carrot", "strawberry", "corn", "pumpkin", "small_fish", "big_fish", "lahm_fruit", "seed_carrot", "seed_corn", "furn_pot", "furn_campfire"]:
		GameState.add_item(k, 10)
	Engine.time_scale = 8.0
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.ignore_time_scale = true
	timer.timeout.connect(_act)
	add_child(timer)
	timer.start()


func _process(delta: float) -> void:
	if main == null:
		return
	elapsed += delta / maxf(Engine.time_scale, 0.001)
	if elapsed >= DURATION:
		Engine.time_scale = 1.0
		print("浸泡测试结束：第 %d 天，%s，等级 %d，摩尔豆 %d，动作统计 %s" % [GameState.day, GameState.season_name(), GameState.player_level, GameState.beans, actions])
		GameState.reset_game()
		get_tree().quit()
		set_process(false)


func _count(a: String) -> void:
	actions[a] = int(actions.get(a, 0)) + 1


func _act() -> void:
	if main == null or not is_instance_valid(main):
		return
	var r := randf()
	var p = main.player
	if ui.fishing:
		if ui.fish_phase == 1:
			ui.fish_marker = ui.fish_zone.x + 0.01
			ui.fish_speed = 0.0
			ui._reel()
			_count("收杆")
		return
	if ui.dialog_panel.visible and randf() < 0.5:
		# 点对话框里的第一个选项
		var btns = ui.dialog_opts.get_children()
		if btns.size() > 0:
			btns[0].pressed.emit()
			_count("点对话选项")
			return
	if GameState.input_locked:
		ui.act._close_minigame()
	if p.moving:
		return  # 等走到目的地、完成互动再做下一件事
	if r < 0.35:
		var all := get_tree().get_nodes_in_group("interactable")
		var n = all.pick_random()
		if n != null and n.has_method("get_interact_point"):
			ui._close_all()
			p.go_interact(n)
			_count("走去互动")
	elif r < 0.5:
		p.go_to(Vector2(randf_range(100, 2300), randf_range(200, 1300)))
		_count("走路")
	elif r < 0.55:
		main.teleport(Vector2(randf_range(100, 2300), randf_range(200, 1300)))
		_count("传送")
	elif r < 0.6:
		ui.do_emote(GameState.EMOTE_ORDER.pick_random())
		_count("表情")
	elif r < 0.65:
		var d: String = GameState.DISHES.keys().pick_random()
		GameState.cook(d)
		_count("做菜")
	elif r < 0.75:
		var panel_actions := [ui.toggle_collection, ui.toggle_bag, ui.toggle_settings, ui.open_shop, ui.open_kitchen, ui.open_board, ui.toggle_emotes]
		panel_actions.pick_random().call()
		_count("开面板")
	elif r < 0.8:
		ui._close_all()
		_count("关面板")
	elif r < 0.84:
		GameState.minutes = randf_range(0, 1439)
		_count("改时间")
	elif r < 0.87:
		GameState.day += randi_range(1, 7)
		GameState.season_changed.emit()
		_count("跳日期")
	elif r < 0.9:
		GameState.set_raining(not GameState.raining)
		_count("天气")
	elif r < 0.93:
		GameState.add_item("furn_pot")
		main.start_placing("pot")
		main._try_place(Vector2(randf_range(1130, 1450), randf_range(1080, 1300)))
		main.cancel_placing()
		_count("摆家具")
	else:
		GameState.save_game()
		GameState.load_game()
		_count("存读档")
