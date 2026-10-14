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
	set_title_text(GameState.title_text(GameState.title))
	GameState.hat_changed.connect(func():
		hat = GameState.hat
		set_title_text(GameState.title_text(GameState.title)))
	rod_color_gold = GameState.rod_level >= 2
	GameState.tools_changed.connect(func(): rod_color_gold = GameState.rod_level >= 2)
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


# ---------- 键盘操作：WASD / 方向键走路，F 互动 ----------

const INTERACT_RANGE := 110.0

var kb_walk_t := 0.0
var kb_recent := 0.0  # 最近用过键盘的话，显示「F」互动提示
var focus_target = null
var focus_scan := 0.0


func _keyboard_dir() -> Vector2:
	if fishing or GameState.input_locked or get_viewport().gui_get_focus_owner() is LineEdit:
		return Vector2.ZERO
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1
	return d.normalized()


func _process(delta: float) -> void:
	super._process(delta)
	var d := _keyboard_dir()
	if d != Vector2.ZERO:
		moving = false
		pending = null
		var np := position + d * speed * delta
		np.x = clampf(np.x, world_rect.position.x, world_rect.end.x)
		np.y = clampf(np.y, world_rect.position.y, world_rect.end.y)
		var pond = get_tree().get_first_node_in_group("pond")
		if pond == null or not pond.contains(np):
			position = np
		elif not pond.contains(Vector2(np.x, position.y)):
			position.x = np.x  # 沿着湖岸滑动
		elif not pond.contains(Vector2(position.x, np.y)):
			position.y = np.y
		target = position
		if absf(d.x) > 0.1:
			facing = signf(d.x)
		kb_walk_t += delta * 12.0
		walk_t = kb_walk_t
		kb_recent = 4.0
	kb_recent = maxf(0.0, kb_recent - delta)
	focus_scan -= delta
	if focus_scan <= 0.0:
		focus_scan = 0.15
		focus_target = nearest_interactable() if kb_recent > 0.0 else null


func nearest_interactable():
	var best = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.has_method("is_visible_in_tree") and not n.is_visible_in_tree():
			continue
		var p: Vector2 = n.get_interact_point()
		var dd := position.distance_to(p)
		if dd < best_d:
			best_d = dd
			best = n
	return best


func interact_nearest() -> void:
	kb_recent = 4.0
	var n = nearest_interactable()
	if n == null:
		GameState.toast.emit("附近没有可以互动的东西")
		return
	var dx: float = n.position.x - position.x
	if absf(dx) > 2.0:
		facing = signf(dx)
	n.interact(self)


func _draw() -> void:
	super._draw()
	if focus_target != null and is_instance_valid(focus_target):
		var p: Vector2 = focus_target.position - position + Vector2(0, -78 + sin(anim_t * 5.0) * 3.0)
		if focus_target.is_in_group("pond"):
			p = focus_target.get_interact_point() - position + Vector2(0, -20)
		draw_circle(p, 13.0, Color(1, 0.95, 0.8))
		draw_arc(p, 13.0, 0.0, TAU, 20, Color(0.6, 0.38, 0.15), 2.0)
		D.text(self, p + Vector2(0, -1), "F", 15, Color(0.45, 0.25, 0.08))
