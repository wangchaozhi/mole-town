extends Node2D
## 春天的四叶草：每天藏在小镇的某片草丛里（周围是一圈普通三叶草做掩护）。
## 找到后今天一整天都是「幸运日」：收获更容易多收、钓鱼更容易钓到宝箱和漂流瓶。

var t := 0.0
var found := -1.0  # 被摘下后的飘起动画时间
var decoys: Array = []  # 周围的三叶草 [偏移, 角度]


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("clovers")
	for i in 7:
		decoys.append([Vector2(randf_range(-38, 38), randf_range(-14, 10)), randf() * TAU])


func hit_test(p: Vector2) -> bool:
	return found < 0.0 and (p - (position + Vector2(0, -10))).length() < 20.0


func get_interact_point() -> Vector2:
	return position + Vector2(40, 8)


func interact(_pl) -> void:
	if found >= 0.0:
		return
	found = 0.0
	remove_from_group("interactable")
	GameState.lucky_day = GameState.day
	GameState.stats["clovers"] = int(GameState.stats.get("clovers", 0)) + 1
	GameState.check_achievements()
	Sfx.play("gift")
	GameState.toast.emit("找到了四叶草！今天一整天都会很幸运（收获更容易多收，钓鱼更容易钓到宝箱）")


func _process(delta: float) -> void:
	t += delta
	if found >= 0.0:
		found += delta
		if found > 1.5:
			queue_free()
	queue_redraw()


func _leaf_set(c: Vector2, n: int, ang: float, col: Color, s: float) -> void:
	draw_line(c, c + Vector2(1, 7) * s, col.darkened(0.3), 1.5)
	for k in n:
		var a := ang + TAU * k / n
		var d := Vector2(cos(a), sin(a))
		draw_circle(c + d * 3.6 * s, 3.4 * s, col)


func _draw() -> void:
	var green := Color(0.28, 0.62, 0.25)
	if found < 0.0:
		for dcy in decoys:
			_leaf_set(dcy[0], 3, dcy[1] + sin(t + dcy[1]) * 0.1, green.darkened(0.08), 1.0)
		_leaf_set(Vector2(0, -6), 4, sin(t * 1.2) * 0.1, green.lightened(0.08), 1.15)
		# 偶尔闪一下，给眼尖的玩家一点提示
		if fmod(t, 4.0) < 0.35:
			var sp := Vector2(8, -16)
			draw_line(sp + Vector2(-4, 0), sp + Vector2(4, 0), Color(1, 1, 0.75), 1.5)
			draw_line(sp + Vector2(0, -4), sp + Vector2(0, 4), Color(1, 1, 0.75), 1.5)
	else:
		var a := clampf(1.0 - found / 1.5, 0.0, 1.0)
		var col := green.lightened(0.15)
		col.a = a
		_leaf_set(Vector2(0, -6 - found * 50.0), 4, found * 4.0, col, 1.15 + found)
