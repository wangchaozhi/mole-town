extends Node
## 全局状态（自动加载）：摩尔豆、背包、任务、时间、存档。

const ItemData = preload("res://scripts/data/items.gd")
const ProgressData = preload("res://scripts/data/progress.gd")
const StoryData = preload("res://scripts/data/story.gd")
const SaveFields = preload("res://scripts/data/save_fields.gd")

signal beans_changed
signal inventory_changed
signal quest_changed
signal hat_changed
signal toast(text: String)
signal weather_changed

const BODY_COLORS := ["946644", "a8754f", "8a5a3c", "b38a5e", "9c6b5a", "7d5a44", "c49a6c", "6e4a3a"]
const RANDOM_NAMES := ["豆豆", "米粒", "团子", "小土豆", "布丁", "可可", "泡芙", "饭团", "糖糖", "栗子", "麻薯", "毛毛"]
const EMOTE_ORDER := ["wave", "happy", "angry", "cry", "sing", "sleep"]
const DAY_MINUTES := 1440.0
const REAL_SECONDS_PER_DAY := 300.0  # 现实 5 分钟 = 游戏 1 天

const CROPS = ItemData.CROPS

const FISH = ItemData.FISH

const HATS = ItemData.HATS

const LAHM_FRUIT_PRICE := 15
const FERTILIZER_PRICE := 25  # 肥料：作物生长 ×1.5，收获必定多 1 个
const FERTILIZER_LEVEL := 2
const GIANT_CHANCE := 0.04  # 作物成熟时长成巨型的概率（施肥 ×3）

const FURNITURE = ItemData.FURNITURE
const HOME_RECT := Rect2(1110, 1060, 360, 260)  # 小院范围

var beans: int = 100
var inventory: Dictionary = {}
var selected_seed: String = "carrot"
var hat: String = "none"
var title: String = ""  # 佩戴的称号（成就 id），显示在名字下面
var owned_hats: Array = ["none"]
var lahm_hunger: float = 80.0
var lahm_exp: int = 0
var player_exp: int = 0
var player_level: int = 1
var lahm_level: int = 1
var lucky_day: int = -1  # 找到四叶草的那天是幸运日
var leaf_day: int = -1  # 哪一天已经撒过落叶堆 / 雪堆（存档，退出重进不会再刷）
var lahm_hide_day: int = -1  # 今天是否已经和拉姆玩过捉迷藏
var day: int = 1
var minutes: float = 480.0
var quest: Dictionary = {}
var quests_done: int = 0
var plots: Dictionary = {}
var home: Array = []  # 小院里摆放的家具 [{"id", "x", "y"}]
var board: Array = []  # 留言板 [{"name", "text", "day"}]，联机时房主的留言板是大家共用的
var offline_seconds: float = 0.0
var font: Font
var ui_theme: Theme
var save_path := "user://mole_save.json"
var player_name := ""
var body_color := ""
var is_new_player := false  # 第一次进入游戏（还没有存档）
var help_today: int = 0  # 今天串门帮忙已领奖励的次数
var best_catch: int = 0  # 接果子最高分
var catch_day: int = -1
var catch_plays: int = 0  # 今天已领奖的小游戏次数
var input_locked := false  # 小游戏进行中时禁止角色移动
var collection: Dictionary = {}  # 物品 id -> 累计获得数量（图鉴）
var day_log: Dictionary = {}  # 今天的小结：harvest / fish / cook / help / earned，第二天早上写进「小镇日报」
var fish_records: Dictionary = {}  # 鱼 id -> 钓到过的最大尺寸（厘米）
var stats: Dictionary = {}  # harvest_total / fish_total / help_total / visits
var achievements: Array = []  # 已解锁的成就 id
var last_signin := ""  # 上次签到的日期（现实日期）
var signin_streak := 0
var music_volume := 0.6
var sfx_volume := 0.8
var ui_scale := 1.0  # 界面大小
var raining := false
var weather_timer := 60.0


func _ready() -> void:
	var ft: Array = preload("res://scripts/util/ui_theme.gd").build()
	font = ft[0]
	ThemeDB.fallback_font = font
	ui_theme = ft[1]
	get_tree().root.theme = ui_theme
	# 同一台电脑开多个窗口测试联机时，用 -- --profile=2 区分存档
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			save_path = "user://mole_save_%s.json" % a.substr(10).validate_filename()
	if not load_game():
		_give_starter_kit()
		new_quest()
	if player_name == "":
		player_name = "小摩尔%d" % (randi() % 900 + 100)
	if not Color.html_is_valid(body_color):
		body_color = BODY_COLORS.pick_random()
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(save_game)
	add_child(timer)


func _process(delta: float) -> void:
	minutes += delta * DAY_MINUTES / REAL_SECONDS_PER_DAY
	if minutes >= DAY_MINUTES:
		minutes -= DAY_MINUTES
		_start_new_day()
	lahm_hunger = maxf(0.0, lahm_hunger - delta * (0.2 if lahm_level >= 2 else 0.25))
	_maybe_start_story()
	_update_weather(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func time_text() -> String:
	return "%s · 第%d天  %02d:%02d" % [season_name(), day, int(minutes) / 60, int(minutes) % 60]


# ---------- 物品 ----------

func item_name(id: String) -> String:
	if id.begins_with("seed_"):
		return str(CROPS[id.substr(5)]["name"]) + "种子"
	if CROPS.has(id):
		return CROPS[id]["name"]
	if FISH.has(id):
		return FISH[id]["name"]
	if id == "lahm_fruit":
		return "拉姆果"
	if id == "fertilizer":
		return "肥料"
	if id == "firefly":
		return "萤火虫"
	if id == "mystery_seed":
		return "神秘种子袋"
	if DISHES.has(id):
		return DISHES[id]["name"]
	if id.begins_with("furn_") and FURNITURE.has(id.substr(5)):
		return FURNITURE[id.substr(5)]["name"]
	return id


func sell_price(id: String) -> int:
	if CROPS.has(id):
		var fest := 1.3 if festival() == "harvest" else 1.0
		return maxi(1, roundi(int(CROPS[id]["sell"]) * price_mult(id) * fest))
	if FISH.has(id):
		return FISH[id]["sell"]
	if DISHES.has(id):
		return DISHES[id]["sell"]
	if id == "firefly":
		return 12
	return 0


func count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, n: int = 1) -> void:
	inventory[id] = count(id) + n
	inventory_changed.emit()


func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()
	return true


func add_beans(n: int) -> void:
	beans += n
	if n > 0:
		day_log["earned"] = int(day_log.get("earned", 0)) + n
	if n > 0:
		Sfx.play("coin")
	beans_changed.emit()
	check_achievements()


func spend_beans(n: int) -> bool:
	if beans < n:
		return false
	beans -= n
	Sfx.play("buy")
	beans_changed.emit()
	return true


# ---------- 任务 ----------

func new_quest() -> void:
	var r := randf()
	if r < 0.4:
		var keys: Array = CROPS.keys().filter(func(c): return is_unlocked(c))
		var pool := mini(keys.size(), 2 + quests_done / 2)
		var crop: String = keys[randi() % pool]
		var need := 2 + randi() % 3
		quest = {"kind": "harvest", "item": crop, "need": need, "have": 0,
			"reward": int(CROPS[crop]["sell"]) * need + 20}
	elif r < 0.6:
		var need := 2 + randi() % 2
		quest = {"kind": "fish", "item": "any", "need": need, "have": 0, "reward": 30 * need}
	elif r < 0.8:
		# 做菜任务：只出现在食材已经解锁的菜里
		var dishes: Array = DISHES.keys().filter(func(d): return _dish_unlocked(d))
		var dish: String = dishes.pick_random()
		var need := 1 + randi() % 2
		quest = {"kind": "cook", "item": dish, "need": need, "have": 0, "reward": int(DISHES[dish]["sell"]) * need + 30}
	else:
		# 送货任务：把作物或鱼交给乐乐（领奖时扣掉）
		var items: Array = CROPS.keys().filter(func(c): return is_unlocked(c)) + ["small_fish", "big_fish"]
		var item: String = items.pick_random()
		var need := 2 + randi() % 3
		quest = {"kind": "deliver", "item": item, "need": need, "have": 0, "reward": roundi(sell_price(item) * need * 1.5) + 20}
	quest_changed.emit()


func quest_done() -> bool:
	return not quest.is_empty() and quest_have() >= int(quest["need"])


## 送货任务直接看背包里有多少，其它任务看累计进度
func quest_have() -> int:
	if quest.get("kind", "") == "deliver":
		return mini(count(str(quest["item"])), int(quest["need"]))
	return int(quest.get("have", 0))


func _dish_unlocked(d: String) -> bool:
	for k in DISHES[d]["needs"]:
		if CROPS.has(k) and not is_unlocked(k):
			return false
	return true


func quest_text() -> String:
	if quest.is_empty():
		return "暂无任务"
	var need := int(quest["need"])
	var have := quest_have()
	var desc := ""
	var it := item_name(str(quest["item"]))
	match quest["kind"]:
		"fish":
			desc = "钓到 %d 条鱼" % need
		"cook":
			desc = "做 %d 份%s" % [need, it]
		"deliver":
			desc = "给乐乐带 %d 个%s" % [need, it]
		_:
			desc = "收获 %d 个%s" % [need, it]
	var status := "（完成啦！去找乐乐领奖）" if have >= need else "（%d/%d）" % [have, need]
	return "%s%s  奖励%d豆" % [desc, status, int(quest["reward"])]


func report(kind: String, item: String) -> void:
	if quest.is_empty() or quest_done():
		return
	if quest["kind"] == kind and (quest["item"] == "any" or quest["item"] == item):
		quest["have"] = int(quest["have"]) + 1
		quest_changed.emit()
		if quest_done():
			toast.emit("任务完成！快去广场找乐乐领取奖励")


func claim_quest() -> int:
	var reward := int(quest["reward"])
	if quest.get("kind", "") == "deliver":
		remove_item(str(quest["item"]), int(quest["need"]))
	add_beans(reward)
	quests_done += 1
	add_exp(15)
	check_achievements()
	new_quest()
	return reward


# ---------- 存档 ----------

func save_game() -> void:
	get_tree().call_group("plots", "store_state")
	var data := {"saved_at": Time.get_unix_time_from_system()}
	for k in SaveFields.FIELDS:
		data[k] = get(k)
	_write_save(JSON.stringify(data))


func load_game() -> bool:
	var data = _read_save(save_path)
	if typeof(data) != TYPE_DICTIONARY:
		# 主存档不存在或者坏了：试试上一份备份
		data = _read_save(save_path + ".bak")
		if typeof(data) != TYPE_DICTIONARY:
			return false
		push_warning("主存档损坏，已从备份恢复")
		loaded_from_backup = true
	for k in SaveFields.FIELDS:
		set(k, SaveFields.coerce(k, data.get(k), SaveFields.FIELDS[k][0]))
	_sanitize_loaded()
	var now := Time.get_unix_time_from_system()
	offline_seconds = clampf(now - float(data.get("saved_at", now)), 0.0, 6.0 * 3600.0)
	if quest.is_empty():
		new_quest()
	return true


## 读档后的校验：数值范围、已经不存在的物品 / 家具、列表里每一项的格式（防止老存档或改坏的存档）
func _sanitize_loaded() -> void:
	rod_level = clampi(rod_level, 0, 2)
	player_level = clampi(player_level, 1, MAX_LEVEL)
	lahm_level = clampi(lahm_level, 1, LAHM_LEVELS.size())
	music_volume = clampf(music_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	ui_scale = clampf(ui_scale, 0.8, 1.4)
	player_name = player_name.left(10)
	if not LAHM_ACCS.has(lahm_acc):
		lahm_acc = "none"
	for k in fish_records.keys():
		if not FISH.has(k):
			fish_records.erase(k)
	var clean_mail := []
	for mm in mail:
		if typeof(mm) == TYPE_DICTIONARY:
			clean_mail.append({"from": str(mm.get("from", "")), "text": str(mm.get("text", "")), "gift": str(mm.get("gift", "")),
				"n": int(mm.get("n", 0)), "read": bool(mm.get("read", true)), "day": int(mm.get("day", 1))})
	mail = clean_mail
	var clean_board := []
	for m in board:
		if typeof(m) == TYPE_DICTIONARY:
			clean_board.append({"name": str(m.get("name", "")).left(10), "text": str(m.get("text", "")).left(40), "day": int(m.get("day", 1))})
	board = clean_board
	var clean_home := []
	for fe in home:
		if typeof(fe) == TYPE_DICTIONARY and FURNITURE.has(str(fe.get("id", ""))):
			clean_home.append({"id": str(fe["id"]), "x": float(fe.get("x", 0)), "y": float(fe.get("y", 0))})
	home = clean_home


# ---------- 天气 / 昼夜 ----------

func is_night() -> bool:
	var h := minutes / 60.0
	return h < 5.5 or h >= 19.0


func _update_weather(delta: float) -> void:
	weather_timer -= delta
	if weather_timer > 0.0 or not Net.controls_weather():
		return
	if raining or sky != "":
		set_raining(false)
		set_sky("")
		weather_timer = randf_range(90.0, 180.0)
		return
	var r := randf()
	if r < 0.45:
		set_raining(true)
		weather_timer = randf_range(30.0, 60.0)
	elif r < 0.6:
		set_sky("wind")
		weather_timer = randf_range(40.0, 80.0)
	elif r < 0.72 and minutes < 11.0 * 60.0:
		set_sky("fog")
		weather_timer = randf_range(40.0, 80.0)
	else:
		weather_timer = 60.0


## 联机时由房主决定天气，客户端收到同步后 broadcast = false
func set_raining(r: bool, broadcast: bool = true) -> void:
	if r == raining:
		return
	raining = r
	weather_changed.emit()
	if season() == 3:
		toast.emit("下雪啦！雪水会自动浇灌农田" if r else "雪停了~")
	else:
		toast.emit("下雨啦！雨水会自动浇灌农田" if r else "雨停了，天晴啦~")
	if broadcast:
		Net.send_weather(r)


## 清空存档重新开始（保留名字、毛色和音量设置）
func reset_game() -> void:
	for p in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	for k in SaveFields.FIELDS:
		var f: Array = SaveFields.FIELDS[k]
		if not f[1]:
			set(k, SaveFields.coerce(k, null, f[0]))
	_give_starter_kit()
	offline_seconds = 0.0
	raining = false
	weather_timer = 60.0
	sky = ""
	new_quest()
	beans_changed.emit()
	inventory_changed.emit()
	hat_changed.emit()


## 新玩家（第一次进游戏 / 重置存档）：开新手引导，送几颗萝卜种子和拉姆果
func _give_starter_kit() -> void:
	is_new_player = true
	tutorial_step = 0
	inventory = {"seed_carrot": 5, "lahm_fruit": 2}


# ---------- 图鉴 / 成就 ----------

const ACHIEVEMENTS = ProgressData.ACHIEVEMENTS

const SIGNIN_REWARDS := [20, 30, 40, 50, 60, 80, 150]  # 连续签到第 1~7 天的摩尔豆，第 7 天另送 3 颗向日葵种子

signal achievement_unlocked(a: Dictionary)


## 记录图鉴 / 统计：kind = harvest / fish / help / visit
## 随机一条鱼的尺寸（厘米），小的多、大的少；破靴子没有尺寸返回 0
func roll_fish_size(id: String) -> int:
	if not FISH.has(id) or not FISH[id].has("size"):
		return 0
	var rg: Array = FISH[id]["size"]
	return int(rg[0]) + roundi((int(rg[1]) - int(rg[0])) * pow(randf(), 1.6))


## 记录尺寸，打破纪录返回 true（第一次钓到不算破纪录）
func record_fish_size(id: String, cm: int) -> bool:
	if cm <= 0:
		return false
	var old := int(fish_records.get(id, 0))
	if cm > old:
		fish_records[id] = cm
		return old > 0
	return false


func record(kind: String, item: String = "", n: int = 1) -> void:
	if kind in ["harvest", "fish", "help", "cook"] and not (kind == "fish" and item == "boot"):
		day_log[kind] = int(day_log.get(kind, 0)) + n
	match kind:
		"harvest":
			collection[item] = int(collection.get(item, 0)) + n
			stats["harvest_total"] = int(stats.get("harvest_total", 0)) + n
			if CROPS.has(item):
				add_exp(int(CROPS[item]["exp"]) * n)
		"fish":
			collection[item] = int(collection.get(item, 0)) + n
			if item != "boot":
				stats["fish_total"] = int(stats.get("fish_total", 0)) + n
			add_exp({"gold_fish": 10, "big_fish": 5, "small_fish": 3}.get(item, 1))
		"help":
			stats["help_total"] = int(stats.get("help_total", 0)) + n
			add_exp(2)
		"visit":
			stats["visits"] = int(stats.get("visits", 0)) + n
			add_exp(5)
		"treasure":
			stats["treasures"] = int(stats.get("treasures", 0)) + n
			add_exp(20)
		"cook":
			collection[item] = int(collection.get(item, 0)) + n
			stats["cook_total"] = int(stats.get("cook_total", 0)) + n
	check_achievements()


## 称号文字：成就 id -> 成就名；没戴或无效返回 ""
static func title_text(id: String) -> String:
	for a in ACHIEVEMENTS:
		if a["id"] == id:
			return str(a["name"])
	return ""


func set_title(id: String) -> void:
	title = id if id in achievements else ""
	hat_changed.emit()  # 和换帽子一样，触发联机同步


func stat_value(stat: String) -> int:
	match stat:
		"beans":
			return beans
		"quests_done":
			return quests_done
		"lahm_level":
			return lahm_level
		"player_level":
			return player_level
		"best_catch":
			return best_catch
		"max_affinity":
			var best := 0
			for k in npc_affinity:
				best = maxi(best, int(npc_affinity[k]))
			return best
		"hats":
			return owned_hats.filter(func(h): return h != "none" and HATS.has(h) and HATS[h].get("shop", true)).size()
		"crop_kinds":
			var k := 0
			for c in CROPS:
				if int(collection.get(c, 0)) > 0:
					k += 1
			return k
		"dish_kinds":
			var k := 0
			for d in DISHES:
				if int(collection.get(d, 0)) > 0:
					k += 1
			return k
		"fish_kinds":
			var k := 0
			for f in FISH:
				if int(collection.get(f, 0)) > 0:
					k += 1
			return k
	if stat.begins_with("c:"):
		return int(collection.get(stat.substr(2), 0))
	return int(stats.get(stat, 0))


func check_achievements() -> void:
	for a in ACHIEVEMENTS:
		if a["id"] in achievements:
			continue
		if stat_value(a["stat"]) >= int(a["target"]):
			achievements.append(a["id"])
			Sfx.play("catch")
			achievement_unlocked.emit(a)
			add_beans(int(a["reward"]))


# ---------- 每日签到（按现实日期） ----------

func today() -> String:
	return Time.get_date_string_from_system()


func can_sign_in() -> bool:
	return last_signin != today()


## 今天签到的话是连续第几天（1~7 循环）
func next_signin_day() -> int:
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	var streak := signin_streak + 1 if last_signin == yesterday else 1
	return (streak - 1) % 7 + 1


func sign_in() -> int:
	if not can_sign_in():
		return 0
	var d := next_signin_day()
	signin_streak = signin_streak + 1 if d > 1 else 1
	last_signin = today()
	add_exp(5)
	var reward: int = SIGNIN_REWARDS[d - 1]
	add_beans(reward)
	if d == 7:
		add_item("seed_sunflower", 3)
	save_game()
	return reward


# ---------- 拉姆成长 ----------

const LAHM_LEVELS := [0, 30, 80, 160, 300]  # 升到第 N+1 级需要的累计亲密度
const LAHM_PERKS := ["", "饿得更慢了", "会帮你抓农场里的害虫", "偶尔能找到宝物", "会帮你给缺水的作物浇水"]


func add_lahm_exp(n: int) -> void:
	lahm_exp += n
	while lahm_level < LAHM_LEVELS.size() and lahm_exp >= LAHM_LEVELS[lahm_level]:
		lahm_level += 1
		toast.emit("拉姆升到了 %d 级！它%s" % [lahm_level, LAHM_PERKS[lahm_level - 1]])
		Sfx.play("catch")
		Net.send_info()
		check_achievements()


## 下一级还差多少亲密度；满级返回 -1
func lahm_exp_to_next() -> int:
	if lahm_level >= LAHM_LEVELS.size():
		return -1
	return LAHM_LEVELS[lahm_level] - lahm_exp


# ---------- 玩家等级 ----------

const MAX_LEVEL := 10

signal level_changed


## 升到第 level 级需要的累计经验：Lv2=50, Lv3=150, Lv4=300 ……
func exp_for_level(level: int) -> int:
	return 25 * level * (level - 1)


func add_exp(n: int) -> void:
	if player_level >= MAX_LEVEL:
		return
	player_exp += n
	var ups := false
	while player_level < MAX_LEVEL and player_exp >= exp_for_level(player_level + 1):
		player_level += 1
		ups = true
		var unlocks := PackedStringArray()
		for c in CROPS:
			if int(CROPS[c]["level"]) == player_level:
				unlocks.append(str(CROPS[c]["name"]) + "种子")
		for h in HATS:
			if int(HATS[h].get("level", 1)) == player_level:
				unlocks.append(str(HATS[h]["name"]))
		var extra := "，解锁了" + "、".join(unlocks) if unlocks.size() > 0 else ""
		toast.emit("升级啦！你现在是 Lv%d%s" % [player_level, extra])
	if ups:
		Sfx.play("catch")
		Net.send_info()
		check_achievements()
	level_changed.emit()


func is_unlocked(crop: String) -> bool:
	return player_level >= int(CROPS[crop]["level"])


func hat_unlocked(id: String) -> bool:
	return player_level >= int(HATS[id].get("level", 1))


# ---------- 每日行情（按游戏天数，每天不同） ----------

var _market_day := -1
var _market := {}


## {"mult": {作物: 收购价倍率}, "hot": 今日热门收购作物, "sale": 今日特价种子}
func market() -> Dictionary:
	if _market_day == day:
		return _market
	var r := RandomNumberGenerator.new()
	r.seed = hash(day * 7919 + 13)
	var mult := {}
	for c in CROPS:
		mult[c] = snappedf(r.randf_range(0.8, 1.25), 0.05)
	var keys: Array = CROPS.keys()
	var hot: String = keys[r.randi() % keys.size()]
	mult[hot] = 1.5
	var unlocked: Array = keys.filter(func(c): return is_unlocked(c) and c != hot)
	var sale: String = unlocked[r.randi() % unlocked.size()] if unlocked.size() > 0 else keys[0]
	_market = {"mult": mult, "hot": hot, "sale": sale}
	_market_day = day
	return _market


func price_mult(crop: String) -> float:
	return float(market()["mult"].get(crop, 1.0))


func seed_price(crop: String) -> int:
	var base := int(CROPS[crop]["seed_price"])
	return maxi(1, roundi(base * 0.6)) if market()["sale"] == crop else base


## 可以送给好友的物品（也用来校验收到的礼物）
func is_giftable(id: String) -> bool:
	if CROPS.has(id) or FISH.has(id) or DISHES.has(id) or id == "lahm_fruit":
		return true
	if id.begins_with("seed_"):
		return CROPS.has(id.substr(5))
	if id.begins_with("furn_"):
		return FURNITURE.has(id.substr(5))
	return false


# ---------- NPC 好感度 ----------

const NPC_INFO = StoryData.NPC_INFO

var npc_affinity: Dictionary = {}  # NPC 名字 -> 好感度


## 场景里某个组还能互动的节点数（落叶堆被翻过后会离开 interactable 组）
func _count_group(g: String) -> int:
	if not is_inside_tree():
		return 0
	return get_tree().get_nodes_in_group(g).filter(func(n): return n.is_in_group("interactable")).size()


func is_lucky() -> bool:
	return lucky_day == day


# ---------- 周末的旅行商人 ----------

const MERCHANT_STOCK = ItemData.MERCHANT_STOCK


func merchant_day(d: int = -1) -> bool:
	if d < 0:
		d = day
	return (d - 1) % 7 >= 5


func merchant_here() -> bool:
	var h := minutes / 60.0
	return merchant_day() and h >= 8.0 and h < 20.0


func merchant_buy(i: int) -> String:
	var it: Dictionary = MERCHANT_STOCK[i]
	if not spend_beans(int(it["price"])):
		return "摩尔豆不够啦！"
	add_item(str(it["id"]), int(it["n"]))
	return "买到了 %s ×%d！" % [item_name(str(it["id"])), int(it["n"])]


## 打开神秘种子袋：随机 2 颗种子（任何作物都可能，包括还没解锁的）
func open_mystery_seed() -> String:
	if not remove_item("mystery_seed"):
		return ""
	var cid: String = CROPS.keys().pick_random()
	add_item("seed_" + cid, 2)
	return "打开神秘种子袋：得到 %s ×2！" % item_name("seed_" + cid)


# ---------- 扭蛋机 ----------

const GACHA_PRICE := 50


## 扭一次：扣 50 豆，返回 {"ok", "text"}。限定帽子重复时换成 150 豆
func gacha_spin() -> Dictionary:
	if not spend_beans(GACHA_PRICE):
		return {"ok": false, "text": "摩尔豆不够啦！扭一次要 %d 豆" % GACHA_PRICE}
	stats["gacha"] = int(stats.get("gacha", 0)) + 1
	var r := randf()
	var text := ""
	if r < 0.06:
		var hid := "bunny" if r < 0.03 else "chick"
		if hid in owned_hats:
			add_beans(150)
			text = "扭到了%s！不过你已经有了，换成 150 摩尔豆" % HATS[hid]["name"]
		else:
			owned_hats.append(hid)
			text = "大奖！扭到了扭蛋限定帽子「%s」！去小屋衣柜或商店帽子页戴上吧" % HATS[hid]["name"]
	elif r < 0.16:
		var furn: Array = FURNITURE.keys().filter(func(f): return FURNITURE[f].get("shop", true) and not FURNITURE[f].has("season"))
		var fid: String = furn.pick_random()
		add_item("furn_" + fid)
		text = "扭到了家具「%s」！" % FURNITURE[fid]["name"]
	elif r < 0.36:
		add_item("lahm_fruit", 3)
		text = "扭到了拉姆果 ×3"
	elif r < 0.66:
		var seeds: Array = CROPS.keys().filter(func(c): return is_unlocked(c))
		var sid: String = "seed_" + str(seeds.pick_random())
		add_item(sid, 3)
		text = "扭到了%s ×3" % item_name(sid)
	else:
		var n := randi_range(20, 80)
		add_beans(n)
		text = "扭到了 %d 摩尔豆" % n
	check_achievements()
	return {"ok": true, "text": text}


## 今天过生日的 NPC（一年 4 季 × 7 天 = 28 天，每个 NPC 有一天生日），没有则返回 ""
func birthday_npc(d: int = -1) -> String:
	if d < 0:
		d = day
	var yd := (d - 1) % (DAYS_PER_SEASON * 4) + 1
	for n in NPC_INFO:
		if int(NPC_INFO[n]["birthday"]) == yd:
			return n
	return ""


## 某个 NPC 的生日是「X季第 N 天」
func birthday_text(npc: String) -> String:
	var yd := int(NPC_INFO[npc]["birthday"]) - 1
	return "%s季第 %d 天" % [["春", "夏", "秋", "冬"][yd / DAYS_PER_SEASON], yd % DAYS_PER_SEASON + 1]
var npc_gift_day: Dictionary = {}  # NPC 名字 -> 上次送礼的游戏日


func affinity(npc: String) -> int:
	return int(npc_affinity.get(npc, 0))


func affinity_tier(npc: String) -> String:
	var a := affinity(npc)
	if a >= 100:
		return "好朋友"
	if a >= 50:
		return "朋友"
	if a >= 20:
		return "熟人"
	return "陌生"


func can_gift_npc(npc: String) -> bool:
	return NPC_INFO.has(npc) and int(npc_gift_day.get(npc, -1)) != day


## 给 NPC 送礼：每个 NPC 每个游戏日 1 次，喜欢的东西好感 +15，其它作物 / 鱼 +5
func gift_npc(npc: String, item: String) -> Dictionary:
	if not can_gift_npc(npc):
		return {"ok": false, "msg": "%s今天已经收过你的礼物啦，明天再来吧" % npc}
	if not remove_item(item):
		return {"ok": false, "msg": "背包里没有这个东西"}
	var liked: bool = item in NPC_INFO[npc]["likes"]
	var gain := 15 if liked else (5 if CROPS.has(item) or FISH.has(item) else 3)
	if item == "boot":
		gain = 1
	var bday := birthday_npc() == npc
	if bday:
		gain *= 2  # 生日当天收到礼物格外开心
	var before := affinity(npc)
	npc_affinity[npc] = before + gain
	npc_gift_day[npc] = day
	var rewards := PackedStringArray()
	var table: Dictionary = NPC_INFO[npc]["rewards"]
	for th in table:
		if before < int(th) and before + gain >= int(th):
			var r: Array = table[th]
			if r[0] == "beans":
				add_beans(int(r[1]))
				rewards.append("%d 摩尔豆" % int(r[1]))
			else:
				add_item(str(r[0]), int(r[1]))
				rewards.append("%s ×%d" % [item_name(str(r[0])), int(r[1])])
	add_exp(3)
	check_achievements()
	return {"ok": true, "liked": liked, "gain": gain, "rewards": rewards, "birthday": bday}


# ---------- 接果子小游戏 ----------

const CATCH_REWARD_PLAYS := 3  # 每个游戏日前 3 次有奖励


func catch_plays_left() -> int:
	return CATCH_REWARD_PLAYS - (catch_plays if catch_day == day else 0)


## 小游戏结束：返回 [摩尔豆, 经验, 是否新纪录]
func finish_catch(score: int) -> Array:
	var record := score > best_catch
	best_catch = maxi(best_catch, score)
	var beans_ := 0
	var exp_ := 0
	if catch_plays_left() > 0:
		if catch_day != day:
			catch_day = day
			catch_plays = 0
		catch_plays += 1
		beans_ = mini(score * 2, 120)
		exp_ = score / 4
		add_beans(beans_)
		add_exp(exp_)
	check_achievements()
	return [beans_, exp_, record]


const BOARD_MAX := 30


func add_board_message(who: String, text: String, d: int) -> void:
	board.append({"name": who.left(10), "text": text.strip_edges().left(40), "day": d})
	while board.size() > BOARD_MAX:
		board.pop_front()


# ---------- 节日 ----------
# 每 7 天一个循环：第 7、14…天是「钓鱼大赛」，第 3、10…天是「丰收节」

const CONTEST_PRIZES := {5: ["beans", 100], 10: ["beans", 200], 15: ["gold_fish", 1]}

var contest_day := -1
var contest_count := 0


func festival() -> String:
	if day % 7 == 0:
		return "fishing"
	if day % 7 == 3:
		return "harvest"
	return ""


func festival_name() -> String:
	return {"fishing": "钓鱼大赛", "harvest": "丰收节"}.get(festival(), "")


func festival_text() -> String:
	var lines := PackedStringArray()
	var f := _festival_line()
	if f != "":
		lines.append(f)
	var b := birthday_npc()
	if b != "":
		lines.append("今天是%s的生日，送礼好感翻倍！" % b)
	if is_lucky():
		lines.append("【幸运日】收获容易多收，钓鱼容易钓到宝箱")
	if merchant_here():
		lines.append("旅行商人阿布在湖边摆摊（周末限定）")
	var h := minutes / 60.0
	match season():
		0:
			if lucky_day != day and _count_group("clovers") > 0:
				lines.append("春天的草丛里藏着一棵四叶草，找找看？")
		1:
			if h >= 19.0 or h < 3.0:
				lines.append("夏夜的湖边和树林里有萤火虫")
		2, 3:
			var left := _count_group("leaf_piles")
			if left > 0:
				lines.append("小镇里还有 %d 堆%s，扑进去翻翻看" % [left, "雪" if season() == 3 else "落叶"])
	return "\n".join(lines)


func _festival_line() -> String:
	match festival():
		"fishing":
			var n := contest_count if contest_day == day else 0
			var next := 0
			for th in CONTEST_PRIZES:
				if n < int(th):
					next = int(th)
					break
			return "今天是【钓鱼大赛】已钓 %d 条%s" % [n, "，钓到 %d 条有奖" % next if next > 0 else "，全部奖励已领取！"]
		"harvest":
			return "今天是【丰收节】作物收购价 +30%，每次收获多 1 个"
	return ""


## 钓鱼大赛：每钓到一条鱼调用一次，达到 5 / 10 / 15 条时发奖
func contest_catch() -> void:
	if festival() != "fishing":
		return
	if contest_day != day:
		contest_day = day
		contest_count = 0
	contest_count += 1
	if CONTEST_PRIZES.has(contest_count):
		var prize: Array = CONTEST_PRIZES[contest_count]
		if prize[0] == "beans":
			add_beans(int(prize[1]))
			toast.emit("钓鱼大赛：钓到 %d 条，获得 %d 摩尔豆！" % [contest_count, int(prize[1])])
		else:
			add_item(str(prize[0]), int(prize[1]))
			toast.emit("钓鱼大赛：钓到 %d 条，获得冠军奖品 %s！" % [contest_count, item_name(str(prize[0]))])
		add_exp(20)
		Sfx.play("catch")


# ---------- 季节 ----------
# 每个季节 7 个游戏日：第 1~7 天春，8~14 夏，15~21 秋，22~28 冬，然后循环

const SEASON_NAMES := ["春", "夏", "秋", "冬"]
const DAYS_PER_SEASON := 7

signal season_changed


func season(d: int = -1) -> int:
	if d < 0:
		d = day
	return ((d - 1) / DAYS_PER_SEASON) % 4


func season_name() -> String:
	return SEASON_NAMES[season()]


func in_season(crop: String) -> bool:
	return season() in CROPS[crop].get("seasons", [])


## 作物在当前季节的生长速度倍率：当季 ×1.3，冬天不当季 ×0.7
func season_growth(crop: String) -> float:
	if in_season(crop):
		return 1.3
	if season() == 3:
		return 0.7
	return 1.0


# ---------- 烹饪 ----------

const DISHES = ItemData.DISHES


func can_cook(dish: String) -> bool:
	var needs: Dictionary = DISHES[dish]["needs"]
	for k in needs:
		if count(k) < int(needs[k]):
			return false
	return true


func cook(dish: String) -> bool:
	if not DISHES.has(dish) or not can_cook(dish):
		return false
	var needs: Dictionary = DISHES[dish]["needs"]
	for k in needs:
		remove_item(k, int(needs[k]))
	add_item(dish)
	record("cook", dish)
	story_event("cook")
	report("cook", dish)
	add_exp(int(DISHES[dish]["exp"]))
	return true


func _start_new_day() -> void:
	var old_season := season()
	help_today = 0
	day += 1
	_sync_week()
	_daily_report()
	_daily_mail()
	if season() != old_season:
		season_changed.emit()
		toast.emit(["春天来了，萝卜和草莓长得最快！", "夏天到了，玉米、向日葵和西瓜长得最快！", "秋天来了，南瓜和萝卜长得最快！", "冬天到了，下雪啦，作物长得慢一些~"][season()])
	var m := market()
	toast.emit("新的一天开始了！第 %d 天 · 今日热门收购：%s · 特价种子：%s" % [day, item_name(m["hot"]), item_name(m["sale"])])
	if festival() != "":
		toast.emit(_festival_line() + "！")
	var bn := birthday_npc()
	if bn != "":
		toast.emit("今天是%s的生日！去送份礼物吧（好感翻倍）" % bn)


## 晚上（20 点以后或 6 点以前）在床上睡觉，直接到第二天早上 6 点。返回跳过的现实秒数（用来让作物继续生长）
func sleep_until_morning() -> float:
	var target := 6.0 * 60.0
	var skipped := 0.0
	if minutes >= 20.0 * 60.0:
		skipped = DAY_MINUTES - minutes + target
		minutes = target
		_start_new_day()
	elif minutes < target:
		skipped = target - minutes
		minutes = target
	return skipped * REAL_SECONDS_PER_DAY / DAY_MINUTES


func can_sleep() -> bool:
	return minutes >= 20.0 * 60.0 or minutes < 6.0 * 60.0


# ---------- 新手引导 ----------

const TUTORIAL = ProgressData.TUTORIAL

signal tutorial_changed

var tutorial_step := -1  # -1 = 已完成或跳过


func tutorial_active() -> bool:
	return tutorial_step >= 0 and tutorial_step < TUTORIAL.size()


func tutorial_event(ev: String) -> void:
	if not tutorial_active() or TUTORIAL[tutorial_step]["event"] != ev:
		return
	tutorial_step += 1
	add_beans(10)
	if tutorial_step >= TUTORIAL.size():
		tutorial_step = -1
		add_beans(100)
		add_item("lahm_fruit", 3)
		toast.emit("新手引导完成！奖励 100 摩尔豆和 3 个拉姆果，接下来自由探索吧~")
	else:
		toast.emit("做得好！+10 摩尔豆  下一步：" + str(TUTORIAL[tutorial_step]["text"]))
	tutorial_changed.emit()


func skip_tutorial() -> void:
	tutorial_step = -1
	tutorial_changed.emit()


# ---------- 拉姆饰品 ----------

const LAHM_ACCS = ItemData.LAHM_ACCS

signal lahm_acc_changed

var lahm_acc := "none"
var owned_lahm_accs: Array = ["none"]


func set_lahm_acc(id: String) -> void:
	lahm_acc = id
	lahm_acc_changed.emit()
	Net.send_info()


# ---------- 国王的每周挑战 ----------
# 每 7 个游戏日一周，挑战内容按周轮换；进度 = 这一周里对应统计增加了多少

const WEEKLY = ProgressData.WEEKLY
const WEEKLY_REWARD := 300

var weekly_week := -1
var weekly_base := 0
var weekly_claimed := false


func week() -> int:
	return (day - 1) / 7


func weekly() -> Dictionary:
	_sync_week()
	return WEEKLY[week() % WEEKLY.size()]


func _sync_week() -> void:
	if weekly_week != week():
		weekly_week = week()
		weekly_base = stat_value(WEEKLY[week() % WEEKLY.size()]["stat"])
		weekly_claimed = false


func weekly_progress() -> int:
	var w := weekly()
	return clampi(stat_value(w["stat"]) - weekly_base, 0, int(w["target"]))


func weekly_done() -> bool:
	return weekly_progress() >= int(weekly()["target"])


## 领取每周挑战奖励：摩尔豆 + 经验，第一次还会得到「金奖杯」家具
func claim_weekly() -> bool:
	if weekly_claimed or not weekly_done():
		return false
	weekly_claimed = true
	add_beans(WEEKLY_REWARD)
	add_exp(50)
	var has_trophy := count("furn_trophy") > 0
	for f in home:
		if f["id"] == "trophy":
			has_trophy = true
	if not has_trophy:
		add_item("furn_trophy")
	return true


# ---------- 存档读写（防损坏） ----------

var loaded_from_backup := false


## 先写到临时文件，确认写完整了再把旧存档挪成 .bak、新存档换上来。
## 这样就算写到一半游戏崩溃 / 断电，原来的存档也还在。
func _write_save(text: String) -> void:
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("无法写入存档：%s" % tmp)
		return
	f.store_string(text)
	f.close()
	if _read_save(tmp) == null:
		push_warning("临时存档校验失败，保留原存档")
		return
	var main_file := ProjectSettings.globalize_path(save_path)
	var bak := main_file + ".bak"
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(save_path + ".bak"):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(main_file, bak)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), main_file)


## 读出存档里的字典；文件不存在或内容不是合法 JSON 字典时返回 null
func _read_save(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var json := JSON.new()  # 用实例解析：坏文件不会在控制台刷错误
	if json.parse(f.get_as_text()) != OK:
		return null
	return json.data if typeof(json.data) == TYPE_DICTIONARY else null


# ---------- 工具升级 ----------

const RODS = ItemData.RODS
const SPRINKLER_PRICE := 600
const SPRINKLER_LEVEL := 5

signal tools_changed

var rod_level := 0  # 0 普通 / 1 好鱼竿 / 2 金鱼竿
var has_sprinkler := false
var has_greenhouse := false


func buy_rod(lv: int) -> bool:
	if lv <= rod_level or lv >= RODS.size() or player_level < int(RODS[lv]["level"]):
		return false
	if not spend_beans(int(RODS[lv]["price"])):
		return false
	rod_level = lv
	tools_changed.emit()
	return true


func buy_sprinkler() -> bool:
	if has_sprinkler or player_level < SPRINKLER_LEVEL or not spend_beans(SPRINKLER_PRICE):
		return false
	has_sprinkler = true
	tools_changed.emit()
	return true


# ---------- 信箱 ----------

const MAIL_LINES = StoryData.MAIL_LINES

signal mail_changed

var mail: Array = []  # [{"from", "text", "gift", "n", "read", "day"}]，最新的在最后


func add_mail(from: String, text: String, gift: String = "", n: int = 0) -> void:
	mail.append({"from": from, "text": text, "gift": gift, "n": n, "read": false, "day": day})
	while mail.size() > 20:
		mail.pop_front()
	mail_changed.emit()
	toast.emit("信箱里有一封来自%s的新信件！" % from)


func unread_mail() -> int:
	var n := 0
	for m in mail:
		if not m["read"]:
			n += 1
	return n


## 打开信件：标记已读，收下附带的礼物。返回礼物描述（没有礼物返回空字符串）
func open_mail(i: int) -> String:
	if i < 0 or i >= mail.size():
		return ""
	var m: Dictionary = mail[i]
	var got := ""
	if not m["read"] and str(m["gift"]) != "" and int(m["n"]) > 0:
		if m["gift"] == "beans":
			add_beans(int(m["n"]))
			got = "%d 摩尔豆" % int(m["n"])
		else:
			add_item(str(m["gift"]), int(m["n"]))
			got = "%s ×%d" % [item_name(str(m["gift"])), int(m["n"])]
	m["read"] = true
	mail_changed.emit()
	return got


## 每天早上：一半概率收到某位 NPC 的信（好感越高礼物越好）；新的一周国王会来信
## 好友来串门帮了一次忙（浇水 / 抓虫 / 摘菜）
func record_guest(who: String) -> void:
	var k := "guest:" + who.left(10)
	day_log[k] = int(day_log.get(k, 0)) + 1


## 新的一天早上：把昨天的小结写成一封「小镇日报」放进信箱（昨天什么都没做就不发）
func _daily_report() -> void:
	var parts := PackedStringArray()
	for k in [["harvest", "收获了 %d 个作物"], ["fish", "钓到 %d 条鱼"], ["cook", "做了 %d 道菜"], ["help", "帮好友干了 %d 次活"], ["earned", "一共赚了 %d 摩尔豆"]]:
		var v := int(day_log.get(k[0], 0))
		if v > 0:
			parts.append(str(k[1]) % v)
	var guests := PackedStringArray()
	for k in day_log:
		if str(k).begins_with("guest:"):
			guests.append("%s（%d 次）" % [str(k).substr(6), int(day_log[k])])
	day_log = {}
	if parts.is_empty() and guests.is_empty():
		return
	var text := "第 %d 天小结：" % (day - 1)
	if not parts.is_empty():
		text += "你%s。%s" % ["，".join(parts), "真是勤劳的一天！" if parts.size() >= 3 else "今天也要加油哦~"]
	if not guests.is_empty():
		text += "\n来你家农场帮忙的好友：%s，记得去谢谢他们哦~" % "、".join(guests)
	add_mail("小镇日报", text)


func _daily_mail() -> void:
	var tomorrow := birthday_npc(day + 1)
	if tomorrow != "":
		add_mail("乐乐" if tomorrow != "乐乐" else "米米", "悄悄告诉你：明天是%s的生日哦！记得准备一份礼物~" % tomorrow)
	if (day - 1) % 7 == 0 and day > 1:
		add_mail("摩尔国王", "新的一周开始了！本周挑战：%s。完成后来城堡找我领奖！" % weekly()["text"])
	if randf() < 0.5:
		var who: String = MAIL_LINES.keys().pick_random()
		var a := affinity(who)
		var gift := "lahm_fruit"
		var n := 1
		if a >= 50:
			gift = ["beans", "furn_pot", "strawberry_cake"].pick_random()
			n = 60 if gift == "beans" else 1
		elif a >= 20:
			gift = ["seed_" + CROPS.keys().filter(func(c): return is_unlocked(c)).pick_random(), "carrot_soup"].pick_random()
			n = 3 if str(gift).begins_with("seed_") else 1
		add_mail(who, MAIL_LINES[who].pick_random(), gift, n)


# ---------- 大风 / 雾 ----------

var sky := ""  # "" 普通 / "wind" 大风 / "fog" 起雾（和下雨互斥）


func set_sky(s: String, broadcast: bool = true) -> void:
	if s == sky:
		return
	sky = s
	weather_changed.emit()
	match s:
		"wind":
			toast.emit("起风啦！%s被吹得满天飞~" % ["花瓣", "蒲公英", "落叶", "雪花"][season()])
		"fog":
			toast.emit("清晨起雾了，小镇朦朦胧胧的")
	if broadcast:
		Net.send_sky(s)


const GREENHOUSE_PRICE := 800
const GREENHOUSE_LEVEL := 4


func buy_greenhouse() -> bool:
	if has_greenhouse or player_level < GREENHOUSE_LEVEL or not spend_beans(GREENHOUSE_PRICE):
		return false
	has_greenhouse = true
	tools_changed.emit()
	return true


# ---------- 主线剧情「城堡的秘密」 ----------

const STORY = StoryData.STORY

signal story_changed
signal story_beat(title: String, text: String)

var story_step := -2  # -2 还没开始，0~5 进行中，-1 已完成
var story_count := 0


func story_active() -> bool:
	return story_step >= 0 and story_step < STORY.size()


## 新手引导完成并且升到 2 级后，主线自动开始
func _maybe_start_story() -> void:
	if story_step == -2 and not tutorial_active() and player_level >= 2:
		story_step = 0
		story_count = 0
		toast.emit("新的故事开始了：「城堡的秘密」（看左上角）")
		story_changed.emit()


func story_text() -> String:
	if not story_active():
		return ""
	var s: Dictionary = STORY[story_step]
	var extra := "（%d/%d）" % [story_count, int(s["count"])] if s.has("count") else ""
	return "主线「城堡的秘密」第%d章：%s%s" % [story_step + 1, s["text"], extra]


## 剧情事件；推进了剧情（显示了剧情对话）时返回 true
func story_event(ev: String) -> bool:
	if not story_active():
		return false
	var s: Dictionary = STORY[story_step]
	if s["event"] != ev:
		return false
	if s.has("count"):
		story_count += 1
		if story_count < int(s["count"]):
			story_changed.emit()
			return false
	story_beat.emit(s["beat"][0], s["beat"][1])
	story_step += 1
	story_count = 0
	if story_step >= STORY.size():
		story_step = -1
		if not "star_pin" in owned_hats:
			owned_hats.append("star_pin")
		hat = "star_pin"
		hat_changed.emit()
		add_beans(300)
		add_exp(100)
		stats["story_done"] = 1
		toast.emit("主线「城堡的秘密」完成！获得星星发卡、300 摩尔豆和 100 经验")
		check_achievements()
	story_changed.emit()
	return true
