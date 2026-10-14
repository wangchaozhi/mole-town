extends Control
## 小地图：显示小镇各区域和所有人的位置，点击地图上的位置可以直接传送过去。

const World = preload("res://scripts/world.gd")
const WORLD_SIZE := Vector2(2400, 1400)
const SCALE := 1.0 / 11.0

var main = null  # 主场景，用来读取玩家 / 远程玩家位置


func _ready() -> void:
	custom_minimum_size = WORLD_SIZE * SCALE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "点击传送"
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	timer.timeout.connect(queue_redraw)
	add_child(timer)


func _m(p: Vector2) -> Vector2:
	return p * SCALE


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or main == null:
		return
	accept_event()
	main.teleport(mb.position / SCALE)


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.47, 0.75, 0.35))
	for path in World.PATHS:
		var pts := PackedVector2Array()
		for p in path:
			pts.append(_m(p))
		draw_polyline(pts, Color(0.94, 0.85, 0.62), 4.0)
	draw_circle(_m(World.PLAZA), 210.0 * SCALE, Color(0.9, 0.87, 0.82))
	draw_rect(Rect2(_m(Vector2(1590, 870)), Vector2(520, 325) * SCALE), Color(0.6, 0.46, 0.3))
	draw_rect(Rect2(_m(GameState.HOME_RECT.position), GameState.HOME_RECT.size * SCALE), Color(0.6, 0.85, 0.46))
	var pond := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pond.append(_m(Vector2(520, 1030) + Vector2(cos(a) * 250, sin(a) * 140)))
	draw_colored_polygon(pond, Color(0.3, 0.6, 0.9))
	# 建筑
	draw_rect(Rect2(_m(Vector2(940, 110)), Vector2(520, 220) * SCALE), Color(0.88, 0.85, 0.95))
	draw_rect(Rect2(_m(Vector2(530, 330)), Vector2(240, 150) * SCALE), Color(0.95, 0.55, 0.6))
	draw_rect(Rect2(_m(Vector2(1630, 330)), Vector2(240, 150) * SCALE), Color(0.4, 0.65, 0.9))
	if main != null:
		for n in get_tree().get_nodes_in_group("npcs"):
			draw_circle(_m(n.position), 2.5, Color(1, 0.95, 0.6))
		for r in main.remotes.values():
			if r.visible:
				draw_circle(_m(r.position), 3.5, Color(0.25, 0.55, 1.0))
		var lahm = get_tree().get_first_node_in_group("my_lahm")
		if lahm != null:
			draw_circle(_m(lahm.position), 2.5, Color(1, 0.6, 0.75))
		var pp: Vector2 = _m(main.player.position)
		draw_circle(pp, 5.0, Color.WHITE)
		draw_circle(pp, 3.8, Color(0.9, 0.1, 0.15))
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.45, 0.3, 0.15), false, 2.0)
