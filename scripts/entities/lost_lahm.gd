extends Node2D
## 随机事件「迷路的小拉姆」：白天偶尔有一只蓝色的小拉姆躲在小镇某个角落。
## 点击它后它会跟着你，带到乐乐身边就算送回家，有奖励。

const D = preload("res://scripts/util/draw_util.gd")

var main = null
var following := false
var t := 0.0


func _ready() -> void:
	add_to_group("interactable")


func hit_test(p: Vector2) -> bool:
	return visible and (p - (position + Vector2(0, -22))).length() < 22.0


func get_interact_point() -> Vector2:
	return position + Vector2(40, 4)


func interact(_pl) -> void:
	if following:
		return
	following = true
	Sfx.play("happy")
	GameState.toast.emit("找到迷路的小拉姆了！带它去广场找乐乐吧")


func _process(delta: float) -> void:
	t += delta
	if following and main != null:
		var p = main.player
		var goal: Vector2 = p.position + Vector2(50.0 * p.facing, 14.0)
		var d := goal - position
		if d.length() > 10.0:
			position += d.normalized() * minf(d.length(), 260.0 * clampf(d.length() / 120.0, 1.0, 6.0) * delta)  # 离得远就飞快点跟上
		for n in get_tree().get_nodes_in_group("npcs"):
			if n.role == "lele" and (n.position.distance_to(position) < 120.0 or n.position.distance_to(p.position) < 160.0):
				_returned(n)
				return
	queue_redraw()


func _returned(lele) -> void:
	GameState.add_beans(80)
	GameState.npc_affinity["乐乐"] = GameState.affinity("乐乐") + 10
	GameState.add_exp(15)
	GameState.toast.emit("小拉姆回到家啦！乐乐送你 80 摩尔豆，好感 +10")
	Sfx.play("gift")
	lele.play_emote("happy")
	lele.say("谢谢你帮它找到家！")
	queue_free()


func _draw() -> void:
	var hover := sin(t * 4.0) * 3.0
	var c := Vector2(0, -22 + hover)
	D.ell(self, Vector2.ZERO, Vector2(10, 3), Color(0, 0, 0, 0.2))
	var flap := sin(t * 16.0) * 3.0
	D.ell(self, c + Vector2(-13, -3), Vector2(6, 4 + flap), Color(1, 1, 1, 0.9))
	D.ell(self, c + Vector2(13, -3), Vector2(6, 4 + flap), Color(1, 1, 1, 0.9))
	draw_circle(c, 12.0, Color(0.45, 0.65, 0.95))
	draw_circle(c + Vector2(-4, -2), 3.0, Color(0.1, 0.1, 0.2))
	draw_circle(c + Vector2(4, -2), 3.0, Color(0.1, 0.1, 0.2))
	draw_line(c + Vector2(0, -12), c + Vector2(-2, -20), Color(0.3, 0.3, 0.5), 1.5)
	draw_circle(c + Vector2(-2, -21), 3.0, Color(1, 0.85, 0.2))
	if not following:
		D.text(self, c + Vector2(0, -32 + sin(t * 3.0) * 2.0), "?", 18, Color(0.95, 0.45, 0.2))
