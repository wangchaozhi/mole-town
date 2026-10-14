extends Node2D
## 新手引导箭头：在当前步骤的目标上方画一个上下跳动的箭头；目标离得远时，在玩家身边画一个指向目标的小箭头。

var main = null
var t := 0.0


func _ready() -> void:
	z_index = 10


func _process(delta: float) -> void:
	t += delta
	visible = GameState.tutorial_active() and main != null and not main.inside
	if visible:
		queue_redraw()


func target_position() -> Vector2:
	var key: String = GameState.TUTORIAL[GameState.tutorial_step]["target"]
	match key:
		"farm":
			# 优先指向第一块空地（第一步）或者刚种下的作物（第二步）
			for p in main.plots:
				if (key == "farm" and GameState.tutorial_step == 0 and p.crop == "") or (GameState.tutorial_step == 1 and p.crop != "" and p.water_time <= 0.0):
					return p.position
			return main.plots[0].position
		"pond":
			return main.pond.edge_point(main.player.position, -40.0)
		"shop", "lele":
			for n in get_tree().get_nodes_in_group("npcs"):
				if (key == "shop" and n.role == "shop") or (key == "lele" and n.role == "lele"):
					return n.position
		"lahm":
			var lahm = get_tree().get_first_node_in_group("my_lahm")
			if lahm != null:
				return lahm.position
	return main.player.position


func _draw() -> void:
	var tp := target_position()
	var bob := sin(t * 5.0) * 8.0
	var tip := tp + Vector2(0, -78 + bob)
	var col := Color(1, 0.55, 0.1)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-16, -20), tip + Vector2(-6, -20), tip + Vector2(-6, -40), tip + Vector2(6, -40), tip + Vector2(6, -20), tip + Vector2(16, -20)]), col)
	draw_polyline(PackedVector2Array([tip, tip + Vector2(-16, -20), tip + Vector2(-6, -20), tip + Vector2(-6, -40), tip + Vector2(6, -40), tip + Vector2(6, -20), tip + Vector2(16, -20), tip]), Color.WHITE, 2.0)
	# 目标较远时，玩家身边的方向指示
	var pp: Vector2 = main.player.position + Vector2(0, -30)
	var d := tp - pp
	if d.length() > 320.0:
		var dir := d.normalized()
		var c := pp + dir * 70.0
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([c + dir * 14.0, c - dir * 6.0 + side * 10.0, c - dir * 6.0 - side * 10.0]), Color(1, 0.55, 0.1, 0.9))
