extends Node
## 音效与背景音乐（自动加载）：全部用代码合成成 AudioStreamWAV，不需要音频文件。
## 用法：Sfx.play("coin")

const RATE := 22050

var sounds := {}
var players: Array = []
var music: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var _next := 0


func _ready() -> void:
	_setup_buses()
	sounds = {
		"click": _make(_note(1046.5, 0.04, "square", 0.18, 0.002, 40.0)),
		"pop": _make(_cat([_note(660, 0.04, "sine", 0.35), _note(990, 0.06, "sine", 0.3)])),
		"plant": _make(_cat([_note(196, 0.06, "triangle", 0.5, 0.002, 18.0), _note(392, 0.08, "triangle", 0.35)])),
		"water": _make(_noise_burst(0.35, 0.25, 0.85)),
		"harvest": _make(_cat([_note(523.3, 0.07, "square", 0.2), _note(659.3, 0.07, "square", 0.2), _note(784, 0.07, "square", 0.2), _note(1046.5, 0.16, "square", 0.2)])),
		"coin": _make(_cat([_note(987.8, 0.06, "square", 0.18), _note(1318.5, 0.22, "square", 0.18, 0.002, 9.0)])),
		"buy": _make(_cat([_note(784, 0.05, "square", 0.16), _note(1046.5, 0.12, "square", 0.16)])),
		"bug": _make(_sweep(1400, 2400, 0.12, 0.25)),
		"splash": _make(_noise_burst(0.4, 0.35, 0.6)),
		"bite": _make(_cat([_note(300, 0.05, "sine", 0.5), _silence(0.05), _note(300, 0.05, "sine", 0.5)])),
		"catch": _make(_cat([_note(523.3, 0.08, "triangle", 0.4), _note(659.3, 0.08, "triangle", 0.4), _note(784, 0.08, "triangle", 0.4), _note(1046.5, 0.08, "triangle", 0.4), _note(1318.5, 0.25, "triangle", 0.4)])),
		"fail": _make(_cat([_note(392, 0.1, "triangle", 0.4), _note(311.1, 0.1, "triangle", 0.4), _note(261.6, 0.25, "triangle", 0.4)])),
		"happy": _make(_cat([_note(1174.7, 0.05, "sine", 0.35), _note(1568, 0.05, "sine", 0.35), _note(2093, 0.12, "sine", 0.3)])),
		"gift": _make(_cat([_note(1568, 0.08, "sine", 0.35), _note(2093, 0.08, "sine", 0.3), _note(2637, 0.25, "sine", 0.25)])),
		"door": _make(_cat([_note(440, 0.06, "triangle", 0.3), _note(554.4, 0.06, "triangle", 0.3), _note(659.3, 0.14, "triangle", 0.3)])),
	}
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)

	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.stream = _make_music()
	add_child(music)
	music.play()

	rain_player = AudioStreamPlayer.new()
	rain_player.bus = "SFX"
	var rain := _make(_rain_loop())
	rain.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rain.loop_end = int(RATE * 2.0)
	rain_player.stream = rain
	rain_player.volume_db = -60.0
	add_child(rain_player)
	rain_player.play()

	apply_volumes()


func _process(delta: float) -> void:
	# 雨声随天气淡入淡出
	var target := -14.0 if GameState.raining else -60.0
	rain_player.volume_db = move_toward(rain_player.volume_db, target, delta * 20.0)


func play(name: String, pitch: float = 1.0) -> void:
	if not sounds.has(name):
		return
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = sounds[name]
	p.pitch_scale = pitch
	p.play()


func _setup_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func apply_volumes() -> void:
	_set_bus("Music", GameState.music_volume)
	_set_bus("SFX", GameState.sfx_volume)


func _set_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


# ---------- 合成 ----------

func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"triangle":
			var x := fmod(phase, 1.0)
			return 4.0 * x - 1.0 if x < 0.5 else 3.0 - 4.0 * x
		_:
			return sin(phase * TAU)


## 一个音符：起音 attack 秒，之后按 decay 指数衰减，结尾 10ms 淡出防爆音
func _note(freq: float, dur: float, kind: String = "square", vol: float = 0.3, attack: float = 0.005, decay: float = 6.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / attack) * exp(-t * decay) * minf(1.0, (dur - t) / 0.01)
		out[i] = _wave(kind, freq * t) * env * vol
	return out


func _sweep(f0: float, f1: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += lerpf(f0, f1, k) / RATE
		out[i] = _wave("square", phase) * vol * (1.0 - k)
	return out


## 滤波噪声：smooth 越大越闷（像水声）
func _noise_burst(dur: float, vol: float, smooth: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		y = lerpf(randf_range(-1, 1), y, smooth)
		out[i] = y * vol * minf(1.0, t * 30.0) * (1.0 - t) * (1.0 - t)
	return out


func _rain_loop() -> PackedFloat32Array:
	var n := int(RATE * 2.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		y = lerpf(randf_range(-1, 1), y, 0.7)
		out[i] = y * 0.5
	# 首尾交叉淡化，循环更顺滑
	var fade := int(RATE * 0.1)
	for i in fade:
		var k := float(i) / fade
		out[i] = out[i] * k + out[n - fade + i] * (1.0 - k)
	return out


func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## 轻快的背景音乐：五声音阶旋律 + 低音，8 小节循环
func _make_music() -> AudioStreamWAV:
	var bpm := 104.0
	var beat := 60.0 / bpm
	# [MIDI 音高(0 = 休止), 拍数]
	var melody := [
		[72, 1], [76, 0.5], [79, 0.5], [81, 1], [79, 1],
		[76, 1], [74, 0.5], [72, 0.5], [74, 2],
		[72, 1], [76, 0.5], [79, 0.5], [84, 1], [81, 1],
		[79, 1], [76, 1], [79, 2],
		[81, 1], [79, 0.5], [81, 0.5], [84, 1], [81, 1],
		[79, 1], [76, 0.5], [74, 0.5], [76, 2],
		[74, 1], [72, 0.5], [74, 0.5], [76, 1], [79, 1],
		[74, 1], [72, 1], [72, 1], [0, 1],
	]
	var bass_roots := [48, 45, 41, 43, 48, 45, 41, 43]  # C Am F G
	var total := int(32 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var pos := 0
	for m in melody:
		var dur: float = float(m[1]) * beat
		if int(m[0]) > 0:
			var tone := _note(_midi(int(m[0])), dur, "triangle", 0.16, 0.01, 2.5)
			for i in tone.size():
				if pos + i < total:
					out[pos + i] += tone[i]
		pos += int(dur * RATE)
	for bar in 8:
		for b in 4:
			var root: int = bass_roots[bar] + (12 if b % 2 == 1 else 0)
			var tone := _note(_midi(root), beat * 0.9, "sine", 0.14, 0.01, 4.0)
			var start := int((bar * 4 + b) * beat * RATE)
			for i in tone.size():
				if start + i < total:
					out[start + i] += tone[i]
	var w := _make(out)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = total
	return w


func _midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)


func _exit_tree() -> void:
	# 退出前停掉循环播放的音乐和雨声，避免引擎退出时报资源泄漏
	for p in [music, rain_player] + players:
		p.stop()
		p.stream = null
