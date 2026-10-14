extends Node
## 全局状态（自动加载）：摩尔豆、背包、任务、时间、存档。

signal beans_changed
signal inventory_changed
signal quest_changed
signal hat_changed
signal toast(text: String)

const BODY_COLORS := ["946644", "a8754f", "8a5a3c", "b38a5e", "9c6b5a", "7d5a44"]
const DAY_MINUTES := 1440.0
const REAL_SECONDS_PER_DAY := 300.0  # 现实 5 分钟 = 游戏 1 天

const CROPS := {
	"carrot": {"name": "萝卜", "seed_price": 5, "sell": 12, "grow_time": 25.0, "color": Color(1.0, 0.55, 0.15)},
	"strawberry": {"name": "草莓", "seed_price": 12, "sell": 30, "grow_time": 45.0, "color": Color(0.95, 0.2, 0.3)},
	"pumpkin": {"name": "南瓜", "seed_price": 25, "sell": 70, "grow_time": 80.0, "color": Color(1.0, 0.6, 0.1)},
	"sunflower": {"name": "向日葵", "seed_price": 40, "sell": 120, "grow_time": 120.0, "color": Color(1.0, 0.85, 0.1)},
}

const FISH := {
	"small_fish": {"name": "小鱼", "sell": 8, "weight": 50},
	"big_fish": {"name": "大鱼", "sell": 22, "weight": 28},
	"gold_fish": {"name": "金鱼", "sell": 60, "weight": 8},
	"boot": {"name": "破靴子", "sell": 1, "weight": 14},
}

const HATS := {
	"none": {"name": "不戴帽子", "price": 0},
	"red_cap": {"name": "红色小帽", "price": 80},
	"straw": {"name": "草帽", "price": 120},
	"flower": {"name": "小花发卡", "price": 150},
	"crown": {"name": "小王冠", "price": 500},
}

const LAHM_FRUIT_PRICE := 15

var beans: int = 100
var inventory: Dictionary = {}
var selected_seed: String = "carrot"
var hat: String = "none"
var owned_hats: Array = ["none"]
var lahm_hunger: float = 80.0
var day: int = 1
var minutes: float = 480.0
var quest: Dictionary = {}
var quests_done: int = 0
var plots: Dictionary = {}
var offline_seconds: float = 0.0
var font: Font
var ui_theme: Theme
var save_path := "user://mole_save.json"
var player_name := ""
var body_color := ""
var help_today: int = 0  # 今天串门帮忙已领奖励的次数


func _ready() -> void:
	_setup_theme()
	# 同一台电脑开多个窗口测试联机时，用 -- --profile=2 区分存档
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			save_path = "user://mole_save_%s.json" % a.substr(10).validate_filename()
	if not load_game():
		inventory = {"seed_carrot": 5, "lahm_fruit": 2}
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
		help_today = 0
		day += 1
		toast.emit("新的一天开始了！第 %d 天" % day)
	lahm_hunger = maxf(0.0, lahm_hunger - delta * 0.25)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func time_text() -> String:
	return "第%d天  %02d:%02d" % [day, int(minutes) / 60, int(minutes) % 60]


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
	return id


func sell_price(id: String) -> int:
	if CROPS.has(id):
		return CROPS[id]["sell"]
	if FISH.has(id):
		return FISH[id]["sell"]
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
	beans_changed.emit()


func spend_beans(n: int) -> bool:
	if beans < n:
		return false
	beans -= n
	beans_changed.emit()
	return true


# ---------- 任务 ----------

func new_quest() -> void:
	if randf() < 0.65:
		var keys: Array = CROPS.keys()
		var pool := mini(keys.size(), 2 + quests_done / 2)
		var crop: String = keys[randi() % pool]
		var need := 2 + randi() % 3
		quest = {"kind": "harvest", "item": crop, "need": need, "have": 0,
			"reward": int(CROPS[crop]["sell"]) * need + 20}
	else:
		var need := 2 + randi() % 2
		quest = {"kind": "fish", "item": "any", "need": need, "have": 0, "reward": 30 * need}
	quest_changed.emit()


func quest_done() -> bool:
	return not quest.is_empty() and int(quest["have"]) >= int(quest["need"])


func quest_text() -> String:
	if quest.is_empty():
		return "暂无任务"
	var need := int(quest["need"])
	var have := int(quest["have"])
	var desc := ""
	if quest["kind"] == "fish":
		desc = "钓到 %d 条鱼" % need
	else:
		desc = "收获 %d 个%s" % [need, item_name(str(quest["item"]))]
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
	add_beans(reward)
	quests_done += 1
	new_quest()
	return reward


# ---------- 存档 ----------

func save_game() -> void:
	get_tree().call_group("plots", "store_state")
	var data := {
		"beans": beans, "inventory": inventory, "selected_seed": selected_seed,
		"hat": hat, "owned_hats": owned_hats, "lahm_hunger": lahm_hunger,
		"day": day, "minutes": minutes, "quest": quest, "quests_done": quests_done, "help_today": help_today,
		"player_name": player_name, "body_color": body_color,
		"plots": plots, "saved_at": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	beans = int(data.get("beans", 100))
	inventory = {}
	var inv: Dictionary = data.get("inventory", {})
	for k in inv:
		inventory[k] = int(inv[k])
	selected_seed = str(data.get("selected_seed", "carrot"))
	hat = str(data.get("hat", "none"))
	owned_hats = data.get("owned_hats", ["none"])
	lahm_hunger = float(data.get("lahm_hunger", 80.0))
	day = int(data.get("day", 1))
	minutes = float(data.get("minutes", 480.0))
	quest = data.get("quest", {})
	quests_done = int(data.get("quests_done", 0))
	help_today = int(data.get("help_today", 0))
	plots = data.get("plots", {})
	player_name = str(data.get("player_name", "")).left(10)
	body_color = str(data.get("body_color", ""))
	var now := Time.get_unix_time_from_system()
	offline_seconds = clampf(now - float(data.get("saved_at", now)), 0.0, 6.0 * 3600.0)
	if quest.is_empty():
		new_quest()
	return true


# ---------- 主题 / 字体 ----------

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _setup_theme() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC",
		"Source Han Sans SC", "WenQuanYi Micro Hei", "SimHei", "sans-serif"])
	font = sf
	ThemeDB.fallback_font = sf

	var th := Theme.new()
	th.default_font = sf
	th.default_font_size = 17
	var border := Color(0.65, 0.38, 0.12)
	var pressed := _box(Color(0.95, 0.55, 0.2), border)
	th.set_stylebox("normal", "Button", _box(Color(1.0, 0.76, 0.38), border))
	th.set_stylebox("hover", "Button", _box(Color(1.0, 0.85, 0.55), border))
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("hover_pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", _box(Color(0.86, 0.83, 0.78), Color(0.6, 0.58, 0.55)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		th.set_color(k, "Button", Color(0.35, 0.18, 0.05))
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.48, 0.45))
	th.set_color("font_color", "Label", Color(0.33, 0.2, 0.1))
	th.set_stylebox("normal", "LineEdit", _box(Color(1, 1, 1), Color(0.7, 0.5, 0.3)))
	th.set_stylebox("focus", "LineEdit", _box(Color(1, 1, 0.94), Color(1.0, 0.6, 0.2)))
	th.set_color("font_color", "LineEdit", Color(0.3, 0.2, 0.1))
	th.set_color("font_placeholder_color", "LineEdit", Color(0.6, 0.55, 0.5))
	th.set_color("caret_color", "LineEdit", Color(0.3, 0.2, 0.1))
	var bg := _box(Color(0.85, 0.8, 0.72), Color(0.6, 0.45, 0.3))
	bg.set_content_margin_all(0)
	var fill := _box(Color(0.45, 0.82, 0.35), Color(0.3, 0.6, 0.2))
	fill.set_content_margin_all(0)
	th.set_stylebox("background", "ProgressBar", bg)
	th.set_stylebox("fill", "ProgressBar", fill)
	ui_theme = th
	get_tree().root.theme = th
