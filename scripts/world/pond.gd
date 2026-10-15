extends Node2D
## 钓鱼湖：点击湖面开始钓鱼。

const D = preload("res://scripts/util/draw_util.gd")

var radius := Vector2(250, 140)
var t := 0.0
var player = null
var water: Polygon2D  # 水面：着色器画渐变、水纹、高光
var water_mat: ShaderMaterial

const WATER_SHADER := """
shader_type canvas_item;
uniform vec2 radius = vec2(250.0, 140.0);
uniform vec4 deep : source_color = vec4(0.18, 0.42, 0.78, 1.0);
uniform vec4 shallow : source_color = vec4(0.42, 0.74, 0.93, 1.0);
uniform float frozen = 0.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX / radius;
}

void fragment() {
	float t = TIME;
	vec2 p = lp;
	float r = length(p);
	float depth = length(p - vec2(0.04, 0.06));
	vec3 col = mix(deep.rgb, shallow.rgb, smoothstep(0.35, 1.0, depth));
	// 流动的水纹光影
	float w = sin(p.x * 9.0 + t * 1.1 + sin(p.y * 7.0 + t * 0.8) * 1.6) * sin(p.y * 13.0 - t * 0.9 + sin(p.x * 5.0 + t * 0.5) * 1.3);
	col += vec3(0.07, 0.09, 0.1) * smoothstep(0.45, 1.0, w) * (1.0 - frozen);
	col -= vec3(0.03, 0.03, 0.02) * smoothstep(0.5, 1.0, -w) * (1.0 - frozen);
	// 闪烁的高光
	float g = sin(p.x * 37.0 + t * 1.9 + sin(p.y * 9.0)) * sin(p.y * 29.0 - t * 1.5 + sin(p.x * 7.0));
	float patch = smoothstep(0.2, 0.9, sin(p.x * 3.0 + t * 0.4) * sin(p.y * 4.0 - t * 0.3));
	col += vec3(0.6) * smoothstep(0.97, 1.0, g) * patch * (1.0 - frozen) * (1.0 - smoothstep(0.6, 0.95, r));
	// 冰面：冷白色、一道道斜向反光
	vec3 ice = mix(vec3(0.72, 0.86, 0.97), vec3(0.88, 0.95, 1.0), smoothstep(0.2, 1.0, depth));
	ice += vec3(0.08) * smoothstep(0.85, 1.0, sin((p.x + p.y) * 8.0));
	col = mix(col, ice, frozen);
	// 岸边一圈浅色水花
	col = mix(col, vec3(0.86, 0.95, 1.0), smoothstep(0.9, 1.0, r) * 0.55);
	COLOR = vec4(col, 1.0);
}
"""


func _ready() -> void:
	z_index = -5
	add_to_group("interactable")
	add_to_group("pond")
	# 沙岸画在水面下面，荷叶、涟漪由 _draw 画在水面上面
	var shore := Node2D.new()
	shore.show_behind_parent = true
	shore.draw.connect(func():
		D.ell(shore, Vector2.ZERO, radius + Vector2(26, 18), Color(0.93, 0.85, 0.6), 48)
		D.ell(shore, Vector2.ZERO, radius + Vector2(8, 5), Color(0.45, 0.72, 0.9), 48))
	add_child(shore)
	water = Polygon2D.new()
	water.show_behind_parent = true
	var pts := PackedVector2Array()
	for i in 64:
		var a := TAU * i / 64.0
		pts.append(Vector2(cos(a) * radius.x, sin(a) * radius.y))
	water.polygon = pts
	var sh := Shader.new()
	sh.code = WATER_SHADER
	water_mat = ShaderMaterial.new()
	water_mat.shader = sh
	water_mat.set_shader_parameter("radius", radius)
	water.material = water_mat
	add_child(water)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func contains(p: Vector2) -> bool:
	var v := p - position
	return Vector2(v.x / radius.x, v.y / radius.y).length() < 1.0


func hit_test(p: Vector2) -> bool:
	return contains(p)


func edge_point(from: Vector2, margin: float = 30.0) -> Vector2:
	var v := from - position
	var a := atan2(v.y / radius.y, v.x / radius.x)
	return position + Vector2(cos(a) * (radius.x + margin), sin(a) * (radius.y + margin))


func get_interact_point() -> Vector2:
	return edge_point(player.position)


func interact(_pl) -> void:
	if GameState.minutes >= 21.0 * 60.0 or GameState.minutes < 5.0 * 60.0:
		GameState.story_event("night_pond")
	get_tree().call_group("ui", "start_fishing", position)


func _draw() -> void:
	var winter := GameState.season() == 3
	water_mat.set_shader_parameter("frozen", 1.0 if winter else 0.0)
	if winter:
		for cr in [[Vector2(-120, -20), Vector2(-60, 10), Vector2(-20, -5)], [Vector2(40, 30), Vector2(90, 0), Vector2(150, 20)], [Vector2(-40, 60), Vector2(10, 80)]]:
			draw_polyline(PackedVector2Array(cr), Color(1, 1, 1, 0.7), 1.5)
	for i in 4:
		if winter:
			break  # 结冰了没有涟漪
		var ph := fmod(t * 0.35 + i / 4.0, 1.0)
		var centers := [Vector2(-90, -30), Vector2(80, 20), Vector2(-20, 50), Vector2(120, -50)]
		var c: Vector2 = centers[i]
		D.ring(self, c, Vector2(10 + ph * 50, 4 + ph * 20), Color(1, 1, 1, 0.5 * (1.0 - ph)), 2.0)
	for lp in [Vector2(-170, 40), Vector2(160, -30), Vector2(-60, -95)]:
		if winter:
			break  # 冬天湖面结霜，看不到荷叶
		var lc: Vector2 = lp + Vector2(0, sin(t + lp.x) * 1.5)
		D.ell(self, lc, Vector2(20, 11), Color(0.3, 0.65, 0.3))
		draw_colored_polygon(PackedVector2Array([lc, lc + Vector2(20, -3), lc + Vector2(20, 4)]), Color(0.3, 0.6, 0.88))
		draw_circle(lc + Vector2(-5, -3), 5.0, Color(1, 0.65, 0.8))
		draw_circle(lc + Vector2(-5, -3), 2.0, Color(1, 0.95, 0.5))
