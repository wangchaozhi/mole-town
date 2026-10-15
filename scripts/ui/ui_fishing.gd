extends Node
## 钓鱼：等鱼上钩 → 红色标记在绿区时收杆；稀有收获（宝箱、漂流瓶）。由 ui.gd 创建，ui 提供通用的面板 / 按钮工具。

var ui  # ui.gd
var fish_panel: PanelContainer
var fish_label: Label
var fish_bar: Control
var fishing := false
var fish_phase := 0  # 0 等待 1 上钩 2 结束
var fish_timer := 0.0
var fish_marker := 0.0
var fish_dir := 1.0
var fish_zone := Vector2(0.4, 0.2)  # 起点, 宽度
var fish_speed := 1.5


func build() -> void:
	fish_panel = ui._panel()
	ui._centered(fish_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	fish_panel.add_child(v)
	v.add_child(ui._label("钓鱼中", 22))
	fish_label = ui._label("", 16)
	fish_label.custom_minimum_size = Vector2(420, 0)
	fish_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(fish_label)
	fish_bar = Control.new()
	fish_bar.custom_minimum_size = Vector2(420, 34)
	fish_bar.draw.connect(_draw_fish_bar)
	v.add_child(fish_bar)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(ui._button("收杆！(空格)", _reel))
	hb.add_child(ui._button("不钓了", _stop_fishing))
	v.add_child(hb)
	fish_panel.visible = false


func start(pond_pos: Vector2) -> void:
	if fishing or ui.player == null:
		return
	ui.close_popups()
	fishing = true
	fish_phase = 0
	fish_timer = randf_range(1.5, 4.0)
	ui.player.fishing = true
	ui.player.bite = false
	var dx: float = pond_pos.x - ui.player.position.x
	if absf(dx) > 1.0:
		ui.player.facing = signf(dx)
	var seasonal := ""
	for id in GameState.FISH:
		if GameState.FISH[id].get("season", -1) == GameState.season():
			seasonal = GameState.item_name(id)
	fish_label.text = "等待鱼儿上钩……（太早收杆会把鱼吓跑哦）\n%s季限定：%s" % [GameState.season_name(), seasonal]
	var pal := fishing_buddy()
	if pal != "":
		fish_label.text += "\n和 %s 一起钓鱼，更容易钓到金鱼！" % pal
	Sfx.play("splash")
	fish_panel.visible = true
	fish_bar.queue_redraw()


func process(delta: float) -> void:
	match fish_phase:
		0:
			fish_timer -= delta
			if fish_timer <= 0.0:
				fish_phase = 1
				fish_timer = 3.5
				fish_marker = 0.0
				fish_dir = 1.0
				var rod := GameState.rod_level
				fish_zone = Vector2(randf_range(0.15, 0.6), randf_range(0.14, 0.24) * (1.0 + 0.4 * rod))
				fish_speed = randf_range(1.2, 2.0) * (1.0 - 0.15 * rod)
				fish_zone.x = minf(fish_zone.x, 1.0 - fish_zone.y)
				fish_label.text = "鱼上钩了！红色标记在绿色区域时按空格收杆！"
				Sfx.play("bite")
				ui.player.bite = true
		1:
			fish_marker += fish_dir * fish_speed * delta
			if fish_marker > 1.0:
				fish_marker = 1.0
				fish_dir = -1.0
			elif fish_marker < 0.0:
				fish_marker = 0.0
				fish_dir = 1.0
			fish_timer -= delta
			if fish_timer <= 0.0:
				Sfx.play("fail")
				_fish_end("鱼儿挣脱跑掉了……")
		2:
			fish_timer -= delta
			if fish_timer <= 0.0:
				_stop_fishing()
	fish_bar.queue_redraw()


func _reel() -> void:
	if not fishing:
		return
	if fish_phase == 0:
		Sfx.play("fail")
		_fish_end("拉得太早了，鱼被吓跑了！")
	elif fish_phase == 1:
		if fish_marker >= fish_zone.x and fish_marker <= fish_zone.x + fish_zone.y:
			GameState.story_event("fish")
			var lucky := randf()
			if GameState.is_lucky():
				lucky *= 0.5  # 幸运日：宝箱、漂流瓶的概率翻倍
			if lucky < 0.03:
				_fish_treasure()
				return
			if lucky < 0.09:
				_fish_bottle()
				return
			var id := _roll_fish()
			GameState.add_item(id)
			GameState.record("fish", id)
			GameState.tutorial_event("fish")
			if id != "boot":
				GameState.contest_catch()
			if id == "boot":
				Sfx.play("fail")
				_fish_end("钓上来一只……破靴子？！")
			else:
				GameState.report("fish", id)
				Sfx.play("catch")
				var cm := GameState.roll_fish_size(id)
				var rec := GameState.record_fish_size(id, cm)
				_fish_end("钓到了一条%s（%d 厘米）！%s" % [GameState.item_name(id), cm, "新纪录！" if rec else ""])
		else:
			Sfx.play("fail")
			_fish_end("没拉住，鱼跑掉了！")


## 附近（300 像素内）正在钓鱼的好友名字，没有返回 ""
func fishing_buddy() -> String:
	if ui.player == null:
		return ""
	for r in get_tree().get_nodes_in_group("remote_players"):
		if r.visible and r.fishing and r.position.distance_to(ui.player.position) < 300.0:
			return r.display_name
	return ""


func _fish_weight(id: String) -> int:
	var info: Dictionary = GameState.FISH[id]
	if info.has("season") and int(info["season"]) != GameState.season():
		return 0  # 不是这个季节的鱼
	var w := int(info["weight"])
	if id == "gold_fish":
		if GameState.festival() == "fishing":
			w *= 2
		if GameState.rod_level >= 2:
			w = roundi(w * 1.5)  # 金鱼竿更容易钓到金鱼
		if fishing_buddy() != "":
			w = roundi(w * 1.5)  # 和好友一起钓鱼运气更好
	return w


func _roll_fish() -> String:
	var total := 0
	for id in GameState.FISH:
		total += _fish_weight(id)
	var r := randi() % total
	for id in GameState.FISH:
		r -= _fish_weight(id)
		if r < 0:
			return id
	return "small_fish"


func _fish_end(msg: String) -> void:
	fish_phase = 2
	fish_timer = 1.6
	fish_label.text = msg
	ui.player.bite = false


func _stop_fishing() -> void:
	fishing = false
	fish_panel.visible = false
	if ui.player != null:
		ui.player.fishing = false
		ui.player.bite = false


func _draw_fish_bar() -> void:
	var s := fish_bar.size
	fish_bar.draw_rect(Rect2(Vector2.ZERO, s), Color(0.35, 0.6, 0.9))
	if fish_phase == 1:
		fish_bar.draw_rect(Rect2(fish_zone.x * s.x, 0, fish_zone.y * s.x, s.y), Color(0.35, 0.9, 0.45))
		var x := fish_marker * s.x
		fish_bar.draw_rect(Rect2(x - 4, -4, 8, s.y + 8), Color(0.95, 0.25, 0.2))
	fish_bar.draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.2, 0.1), false, 2.0)


const BOTTLE_NOTES := [
	"今天的晚霞好美，希望捡到这个瓶子的你也开心！",
	"听说在湖边许愿很灵哦~",
	"我在湖的另一边种了好多向日葵，有空来看看！",
	"给拉姆多喂点拉姆果，它会长得更快哦。",
	"如果你看到这张纸条，说明我们有缘！",
]


## 宝箱：一大笔摩尔豆，有时还有一件家具
func _fish_treasure() -> void:
	var beans_ := randi_range(100, 200)
	GameState.add_beans(beans_)
	var extra := ""
	if randf() < 0.5:
		var shop_furn: Array = GameState.FURNITURE.keys().filter(func(k): return GameState.FURNITURE[k].get("shop", true))
		var furn: String = shop_furn.pick_random()
		GameState.add_item("furn_" + furn)
		extra = "，还有一件%s" % GameState.FURNITURE[furn]["name"]
	GameState.record("treasure")
	Sfx.play("catch")
	_fish_end("哇！钓上来一个宝箱！里面有 %d 摩尔豆%s！" % [beans_, extra])
	if ui.player != null:
		ui.player.play_emote("happy")


## 漂流瓶：一张纸条（优先用留言板上的真实留言）和一点小礼物
func _fish_bottle() -> void:
	var note: String = BOTTLE_NOTES.pick_random()
	var who := "远方的小摩尔"
	var board := Net.current_board()
	if not board.is_empty() and randf() < 0.7:
		var m: Dictionary = board.pick_random()
		note = str(m["text"])
		who = str(m["name"])
	var gift := randi_range(20, 60)
	GameState.add_beans(gift)
	Sfx.play("gift")
	_fish_end("钓到一个漂流瓶！里面的纸条写着：")
	ui.show_dialog("漂流瓶", "「%s」\n—— %s\n\n瓶子里还有 %d 摩尔豆。" % [note, who, gift], [["收好", ui._noop]])
