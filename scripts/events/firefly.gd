extends Node2D
## 萤火虫：夏天的夜里在湖边、树林里慢慢飞，自己会发光。点一下就抓住（背包里多一只萤火虫）。
## 由 events.gd 生成，天亮就飞走。

var t := 0.0
var home := Vector2.ZERO  # 在这附近飘
var vel := Vector2.ZERO
var light: PointLight2D
var leaving := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("fireflies")
	t = randf() * 10.0
	home = position
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	light = PointLight2D.new()
	light.texture = tex
	light.texture_scale = 1.2
	light.color = Color(0.8, 1.0, 0.45)
	light.position = Vector2(0, -30)
	add_child(light)


func hit_test(p: Vector2) -> bool:
	return visible and (p - (position + Vector2(0, -30))).length() < 22.0


func get_interact_point() -> Vector2:
	return position + Vector2(36, 6)


func interact(_pl) -> void:
	if leaving:
		return
	GameState.add_item("firefly")
	GameState.stats["fireflies"] = int(GameState.stats.get("fireflies", 0)) + 1
	Sfx.play("happy")
	var total := int(GameState.stats["fireflies"])
	if total == 10:
		GameState.add_item("furn_firefly_jar")
		GameState.toast.emit("抓到第 10 只萤火虫！得到了一盏「萤火虫灯」，可以摆在小院里")
	else:
		GameState.toast.emit("抓到一只萤火虫！（累计 %d 只）" % total)
	GameState.check_achievements()
	queue_free()


func _process(delta: float) -> void:
	t += delta
	if leaving:
		position += Vector2(0, -60) * delta
		modulate.a -= delta * 0.6
		if modulate.a <= 0.0:
			queue_free()
	else:
		# 慢慢地绕着 home 乱飘
		vel += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 90.0 * delta
		vel += (home - position) * 0.25 * delta
		vel = vel.limit_length(45.0)
		position += vel * delta
	var glow := 0.55 + 0.45 * sin(t * 3.0)
	light.energy = glow * 0.8
	queue_redraw()


func fly_away() -> void:
	leaving = true
	remove_from_group("interactable")


func _draw() -> void:
	var glow := 0.55 + 0.45 * sin(t * 3.0)
	var c := Vector2(0, -30 + sin(t * 2.0) * 4.0)
	draw_circle(c, 9.0, Color(0.85, 1.0, 0.4, 0.18 * glow))
	draw_circle(c, 5.0, Color(0.9, 1.0, 0.5, 0.45 * glow))
	draw_circle(c, 2.6, Color(1, 1, 0.75, 0.6 + 0.4 * glow))
	var flap := sin(t * 20.0) * 1.5
	draw_circle(c + Vector2(-3, -3 - flap), 2.0, Color(1, 1, 1, 0.5))
	draw_circle(c + Vector2(3, -3 + flap), 2.0, Color(1, 1, 1, 0.5))
