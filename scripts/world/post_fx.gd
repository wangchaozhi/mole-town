extends CanvasLayer
## 画面后期：暗角 + 轻微提高饱和度 / 对比度 + 按时段调色（清晨偏暖、傍晚偏橙、夜里偏蓝）。
## 盖在世界画面上、界面下面（界面在第 5 层），不挡鼠标。

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.25;
uniform float saturation = 1.1;
uniform float contrast = 1.05;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint.rgb;
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(0.62, 0.22, length(d));
	c *= mix(1.0 - vignette, 1.0, v);
	COLOR = vec4(c, 1.0);
}
"""

## 一天里几个时间点的 [色调, 暗角]，中间平滑过渡
const KEYS := [
	[0.0, Color(0.92, 0.95, 1.08), 0.42],
	[5.0, Color(0.95, 0.96, 1.05), 0.38],
	[7.0, Color(1.06, 1.0, 0.92), 0.26],   # 清晨偏暖
	[10.0, Color(1.0, 1.0, 1.0), 0.22],
	[16.0, Color(1.0, 1.0, 1.0), 0.22],
	[18.0, Color(1.03, 0.99, 0.95), 0.3],  # 傍晚（昼夜色调已经偏橙，这里只加一点暖）
	[20.0, Color(0.95, 0.95, 1.06), 0.4],
	[24.0, Color(0.92, 0.95, 1.08), 0.42],
]

var rect: ColorRect
var mat: ShaderMaterial


func _ready() -> void:
	layer = 3
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	add_child(rect)


func _process(_delta: float) -> void:
	var h := GameState.minutes / 60.0
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var k := (h - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			mat.set_shader_parameter("tint", (a[1] as Color).lerp(b[1], k))
			mat.set_shader_parameter("vignette", lerpf(a[2], b[2], k))
			return
