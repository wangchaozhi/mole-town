extends "res://scripts/mole.gd"
## NPC 摩尔：乐乐（任务）、店长（商店）、闲逛的小摩尔（聊天/提示）。

var role := "wander"
var lines: Array = []
var home := Vector2.ZERO
var wander_radius := 220.0
var idle_timer := 2.0
var chat_timer := 8.0


func _ready() -> void:
	super._ready()
	add_to_group("interactable")
	add_to_group("npcs")
	home = position
	speed = 80.0
	idle_timer = randf_range(1.0, 4.0)
	chat_timer = randf_range(4.0, 14.0)
	arrived.connect(func(): idle_timer = randf_range(2.0, 6.0))


func _process(delta: float) -> void:
	super._process(delta)
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
	chat_timer -= delta
	if chat_timer <= 0.0:
		chat_timer = randf_range(12.0, 28.0)
		if randf() < 0.3:
			play_emote(EMOTES.keys().pick_random())
		elif not lines.is_empty() and not bubble.visible:
			say(lines.pick_random())


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
	get_tree().call_group("ui", "on_npc_interact", self)
