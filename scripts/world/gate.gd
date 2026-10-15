extends Node2D
## 城堡大门：点击（或按 F）进入「接果子」小游戏。城堡本身由 prop.gd 绘制，这里只负责互动。


func _ready() -> void:
	add_to_group("interactable")


func hit_test(p: Vector2) -> bool:
	return Rect2(position + Vector2(-58, -175), Vector2(116, 178)).has_point(p)


func get_interact_point() -> Vector2:
	return position + Vector2(0, 34)


func interact(_pl) -> void:
	get_tree().current_scene.castle_gate()
