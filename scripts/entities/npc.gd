extends "res://scripts/entities/mole.gd"
## NPC 摩尔：乐乐（任务）、店长（商店）、闲逛的小摩尔（聊天/提示）。
## 作息：22:00~6:00 回家睡觉（店长通宵营业），早上醒来回到原来的地方。

var role := "wander"
var lines: Array = []
var home := Vector2.ZERO  # 白天待的地方 / 闲逛中心
var sleep_spot := Vector2.ZERO  # 晚上睡觉的地方（默认就是 home）
var sleeping := false
var wander_radius := 220.0
var idle_timer := 2.0
var chat_timer := 8.0


func _ready() -> void:
	super._ready()
	add_to_group("interactable")
	add_to_group("npcs")
	home = position
	if sleep_spot == Vector2.ZERO:
		sleep_spot = home
	speed = 80.0
	idle_timer = randf_range(1.0, 4.0)
	chat_timer = randf_range(4.0, 14.0)
	arrived.connect(func(): idle_timer = randf_range(2.0, 6.0))


static func is_bedtime() -> bool:
	var h: float = GameState.minutes / 60.0
	return h >= 22.0 or h < 6.0


func _process(delta: float) -> void:
	super._process(delta)
	if role == "merchant":
		visible = GameState.merchant_here()  # 只在周末白天出摊
	if not role in ["shop", "king", "merchant"] and is_bedtime():
		_night()
		return
	if sleeping:
		# 天亮了：醒来回去
		sleeping = false
		play_emote("wave")
		move_to(home)
		idle_timer = 99.0
	if role == "wander" and not moving:
		idle_timer -= delta
		if idle_timer <= 0.0:
			var p := home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * wander_radius
			var pond = get_tree().get_first_node_in_group("pond")
			if pond != null and pond.contains(p):
				idle_timer = 0.5
			else:
				move_to(p)
				idle_timer = 99.0
	elif role != "wander" and not moving and position.distance_to(home) > 4.0:
		move_to(home)
	chat_timer -= delta
	if chat_timer <= 0.0:
		chat_timer = randf_range(12.0, 28.0)
		if randf() < 0.3:
			play_emote(EMOTES.keys().pick_random())
		elif not lines.is_empty() and not bubble.visible:
			say(lines.pick_random())


func _night() -> void:
	if position.distance_to(sleep_spot) > 4.0:
		if not moving or target.distance_to(sleep_spot) > 1.0:
			move_to(sleep_spot)
		return
	sleeping = true
	if emote != "sleep" or emote_t < 0.3:
		play_emote("sleep")


func _draw() -> void:
	super._draw()
	if GameState.birthday_npc() == display_name:
		# 生日当天身边飘着一个气球
		var sway := sin(Time.get_ticks_msec() / 600.0) * 4.0
		var bp := Vector2(30 + sway, -92)
		draw_line(Vector2(18, -40), bp + Vector2(0, 16), Color(0.4, 0.4, 0.4), 1.2)
		D.ell(self, bp, Vector2(11, 14), Color(1, 0.4, 0.55))
		D.ell(self, bp + Vector2(-4, -5), Vector2(3, 4), Color(1, 1, 1, 0.5))
		draw_colored_polygon(PackedVector2Array([bp + Vector2(-3, 16), bp + Vector2(3, 16), bp + Vector2(0, 12)]), Color(1, 0.4, 0.55))


func hit_test(p: Vector2) -> bool:
	return visible and super.hit_test(p)


func get_interact_point() -> Vector2:
	var pl = get_tree().get_first_node_in_group("player")
	var side := 1.0
	if pl != null and pl.position.x < position.x:
		side = -1.0
	return position + Vector2(side * 55.0, 6.0)


func interact(pl) -> void:
	moving = false
	idle_timer = 6.0
	var dx: float = pl.position.x - position.x
	if absf(dx) > 2.0:
		facing = signf(dx)
	if sleeping:
		say("唔……好困……谁呀？")
	if GameState.story_event("talk_" + display_name):
		play_emote("happy")
		return  # 剧情对话代替平常的对话
	get_tree().call_group("ui", "on_npc_interact", self)
