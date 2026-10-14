extends Node2D
## 秋天的落叶堆 / 冬天的雪堆：点一下扑进去翻一翻，会找到摩尔豆、种子、拉姆果，偶尔还有南瓜灯 / 雪人。由 events.gd 每天早上生成。

const D = preload("res://scripts/draw_util.gd")
const LEAF_COLORS := [Color(0.92, 0.45, 0.12), Color(0.95, 0.7, 0.15), Color(0.8, 0.28, 0.12), Color(0.7, 0.45, 0.15)]
const SNOW_COLORS := [Color(1, 1, 1), Color(0.92, 0.96, 1.0), Color(0.85, 0.92, 1.0)]

var snow := false  # 冬天的雪堆

var t := 0.0
var burst := -1.0  # 翻过之后叶子飞散的动画时间
var leaves: Array = []  # [偏移, 颜色, 角度]


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("leaf_piles")
	for i in 26:
		var a := randf() * TAU
		var r := sqrt(randf())
		leaves.append([Vector2(cos(a) * 30.0 * r, -8.0 + sin(a) * 12.0 * r - (1.0 - r) * 12.0), (SNOW_COLORS if snow else LEAF_COLORS).pick_random(), randf() * TAU])


func hit_test(p: Vector2) -> bool:
	return burst < 0.0 and Rect2(position + Vector2(-34, -34), Vector2(68, 44)).has_point(p)


func get_interact_point() -> Vector2:
	return position + Vector2(48, 6)


func interact(_pl) -> void:
	if burst >= 0.0:
		return
	burst = 0.0
	remove_from_group("interactable")
	Sfx.play("harvest")
	GameState.stats["leaf_piles"] = int(GameState.stats.get("leaf_piles", 0)) + 1
	var r := randf()
	var where := "雪堆" if snow else "落叶堆"
	var rare := "furn_snowman" if snow else "furn_pumpkin_lamp"
	if r < 0.08 and GameState.count(rare) == 0:
		GameState.add_item(rare)
		GameState.toast.emit("哗啦！%s里藏着一个%s！" % [where, GameState.item_name(rare)])
	elif r < 0.45:
		var n := randi_range(10, 35)
		GameState.add_beans(n)
		GameState.toast.emit("哗啦！在%s里翻到 %d 摩尔豆" % [where, n])
	elif r < 0.75:
		var seeds: Array = GameState.CROPS.keys().filter(func(c): return GameState.is_unlocked(c))
		var sid: String = "seed_" + str(seeds.pick_random())
		GameState.add_item(sid, 2)
		GameState.toast.emit("哗啦！在%s里翻到 %s ×2" % [where, GameState.item_name(sid)])
	else:
		GameState.add_item("lahm_fruit")
		GameState.toast.emit("哗啦！在%s里翻到一个拉姆果" % where)


func _process(delta: float) -> void:
	t += delta
	if burst >= 0.0:
		burst += delta
		if burst > 1.2:
			queue_free()
	queue_redraw()


func _draw() -> void:
	if burst < 0.0:
		D.ell(self, Vector2(0, 2), Vector2(36, 9), Color(0, 0, 0, 0.15))
		D.ell(self, Vector2(0, -8), Vector2(32, 16), Color(0.86, 0.92, 1.0) if snow else Color(0.75, 0.38, 0.12))
	var fade := 1.0 - clampf(burst / 1.2, 0.0, 1.0) if burst >= 0.0 else 1.0
	for l in leaves:
		var p: Vector2 = l[0]
		var ang: float = l[2] + sin(t * 1.5 + l[2]) * 0.1
		if burst >= 0.0:
			# 扑进去之后叶子往四周飞起来再落下
			var dir := (p + Vector2(0, 10)).normalized()
			p += dir * burst * 70.0 + Vector2(0, -90.0 * burst + 80.0 * burst * burst)
			ang += burst * 6.0
		var col: Color = l[1]
		col.a = fade
		var u := Vector2(cos(ang), sin(ang))
		if snow:
			draw_circle(p, 6.0, col)  # 雪团
		else:
			draw_colored_polygon(PackedVector2Array([p + u * 7.0, p + u.orthogonal() * 3.5, p - u * 7.0, p - u.orthogonal() * 3.5]), col)
