extends "res://scripts/mole.gd"
## 其他联机玩家在本地的化身：根据网络消息走路、钓鱼、说话。

var peer_id := 0
var farm := 0  # 这位玩家此刻所在的是谁家的农场
var lahm = null


func _ready() -> void:
	super._ready()
	add_to_group("interactable")
	speed = 240.0


func apply_info(info: Dictionary) -> void:
	set_display_name(str(info["name"]))
	hat = str(info["hat"])
	body_color = Color.html(str(info["color"]))
	name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	name_label.text = "%s Lv%d" % [display_name, int(info["level"])]


func net_move(pos: Vector2, to: Vector2, is_fishing: bool) -> void:
	if position.distance_to(pos) > 200.0:
		position = pos
	move_to(to)
	fishing = is_fishing


func hit_test(p: Vector2) -> bool:
	return visible and super.hit_test(p)


func get_interact_point() -> Vector2:
	var pl = get_tree().get_first_node_in_group("player")
	var side := 1.0
	if pl != null and pl.position.x < position.x:
		side = -1.0
	return position + Vector2(side * 55.0, 6.0)


func interact(_pl) -> void:
	get_tree().call_group("ui", "on_remote_interact", self)
