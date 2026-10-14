extends "res://scripts/mole.gd"
## 玩家：点击地面移动，点击物体先走过去再互动。

var pending = null


func _ready() -> void:
	display_name = GameState.player_name
	body_color = Color.html(GameState.body_color)
	super._ready()
	add_to_group("player")
	speed = 240.0
	hat = GameState.hat
	GameState.hat_changed.connect(func(): hat = GameState.hat)
	arrived.connect(_on_arrived)


func go_to(p: Vector2) -> void:
	pending = null
	move_to(p)


func go_interact(n) -> void:
	pending = n
	move_to(n.get_interact_point())


func _on_arrived() -> void:
	if pending != null and is_instance_valid(pending):
		var n = pending
		pending = null
		var dx: float = n.position.x - position.x
		if absf(dx) > 2.0:
			facing = signf(dx)
		n.interact(self)
