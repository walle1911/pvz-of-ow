extends Node2D
class_name ReaperShadowStepEffect
## 死神小丑暗影步表现：影池扩散、暗影触须缠绕、黑雾吞没身体，再于目标点反向重构。
## 视觉逐帧参考用户提供的暴雪原版截图，不使用额外受版权保护的贴图。

enum EffectMode {
	DEPARTURE,
	DESTINATION,
	ARRIVAL,
	COUNTDOWN,
}

const VOID_BLACK := Color(0.003, 0.004, 0.012, 0.96)
const SMOKE_BLACK := Color(0.012, 0.014, 0.032, 0.88)
const SHADOW_INDIGO := Color(0.055, 0.045, 0.23, 0.78)
const VEIL_VIOLET := Color(0.15, 0.11, 0.42, 0.58)
const WISP_VIOLET := Color(0.27, 0.18, 0.62, 0.68)

static var _shared_smoke_texture:GradientTexture2D

var effect_mode := EffectMode.DEPARTURE
var effect_duration := 0.8
var elapsed := 0.0
var _countdown_label:Label
var _smoke_particles:Array[Dictionary] = []
var _shards:Array[Dictionary] = []
var _tendrils:Array[Dictionary] = []


func configure(mode:EffectMode, duration:float) -> void:
	effect_mode = mode
	effect_duration = maxf(duration, 0.01)
	elapsed = 0.0
	_ensure_smoke_texture()
	_build_particles()
	if effect_mode == EffectMode.COUNTDOWN:
		_create_countdown_label()
	queue_redraw()

func _process(delta:float) -> void:
	elapsed += delta
	if effect_mode == EffectMode.COUNTDOWN and is_instance_valid(_countdown_label):
		var seconds_left := maxf(effect_duration - elapsed, 0.0)
		_countdown_label.text = str(int(ceil(seconds_left)))
		var urgency := 1.0 - seconds_left / effect_duration
		var beat := 1.0 + sin(elapsed * TAU * lerpf(1.5, 4.2, urgency)) * 0.07
		_countdown_label.scale = Vector2.ONE * beat
		_countdown_label.pivot_offset = _countdown_label.size * 0.5
	queue_redraw()
	if elapsed >= effect_duration:
		queue_free()


func _draw() -> void:
	var progress := clampf(elapsed / effect_duration, 0.0, 1.0)
	match effect_mode:
		EffectMode.DEPARTURE:
			_draw_shadow_step(progress, false)
		EffectMode.DESTINATION:
			_draw_destination(progress)
		EffectMode.ARRIVAL:
			_draw_shadow_step(progress, true)
		EffectMode.COUNTDOWN:
			_draw_countdown(progress)


func _draw_shadow_step(progress:float, arriving:bool) -> void:
	var shadow_phase := 1.0 - progress if arriving else progress
	var envelope:float
	if arriving:
		## 出现时烟量严格随“尚未出地”的比例递减。
		envelope = pow(1.0 - progress, 1.18)
	else:
		## 传送发生在离场效果约 80% 处：此前烟量始终随入地比例增长，
		## 剩余时间只负责让原地残留的烟旋散去。
		const TELEPORT_PHASE := 0.805
		if progress <= TELEPORT_PHASE:
			envelope = pow(progress / TELEPORT_PHASE, 1.42)
		else:
			envelope = pow((1.0 - progress) / (1.0 - TELEPORT_PHASE), 0.72)
	_draw_ground_stain(31.0 + shadow_phase * 17.0, envelope * 0.68)
	_draw_vortex(shadow_phase, envelope)
	_draw_tendrils(shadow_phase, envelope * 0.26)
	_draw_smoke(progress, envelope, arriving, 1.0)
	_draw_shadow_shards(progress, envelope * 0.74, arriving)


func _draw_destination(progress:float) -> void:
	var appear := clampf(progress * 5.0, 0.0, 1.0)
	var disappear := clampf((1.0 - progress) * 4.0, 0.0, 1.0)
	var envelope := appear * disappear
	_draw_ground_stain(29.0, 0.13 * envelope)
	## 传送前目的地只显示贴地暗影，不绘制任何可能被看成人形的纵向烟雾。


func _draw_countdown(_progress:float) -> void:
	## 暗影步在重构完成后立即散去。五秒阶段仅由数字表达爆炸倒计时，
	## 不让一团持续跟随角色的烟雾破坏原版“出现后恢复实体”的节奏。
	pass


func _draw_smoke(progress:float, envelope:float, reverse:bool, amount_scale:float) -> void:
	var motion_phase := 1.0 - progress if reverse else progress
	var draw_count := mini(int(_smoke_particles.size() * amount_scale), _smoke_particles.size())
	for i in range(draw_count):
		var particle := _smoke_particles[i]
		var height:float = float(particle[&"height"])
		var profile := sin(height * PI)
		var radius := lerpf(18.0, 46.0, profile) * (0.78 + envelope * 0.22)
		var angle := float(particle[&"phase"]) + elapsed * float(particle[&"spin"]) + motion_phase * 4.2
		var pos := Vector2(
			cos(angle) * radius,
			lerpf(-8.0, -132.0, height) + sin(angle) * (5.0 + profile * 5.0) - motion_phase * float(particle[&"rise"])
		)
		var puff_scale:float = float(particle[&"size"]) * (0.84 + profile * 0.18)
		var particle_alpha := envelope * float(particle[&"alpha"])
		_draw_smoke_puff(pos, puff_scale, particle_alpha, float(particle[&"rotation"]) + elapsed * 0.22)


func _draw_smoke_puff(pos:Vector2, puff_scale:float, alpha:float, puff_rotation:float) -> void:
	if _shared_smoke_texture == null:
		return
	## 原版是黑色主体、暗靛紫边缘的厚重烟团，不是红雾或发光粒子。
	draw_set_transform(pos, puff_rotation, Vector2.ONE * puff_scale * 1.28)
	draw_texture(_shared_smoke_texture, Vector2(-32, -32), SHADOW_INDIGO * Color(1, 1, 1, alpha * 0.48))
	draw_set_transform(pos, -puff_rotation * 0.7, Vector2.ONE * puff_scale)
	draw_texture(_shared_smoke_texture, Vector2(-32, -32), SMOKE_BLACK * Color(1, 1, 1, alpha * 0.74))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_vortex(phase:float, alpha:float) -> void:
	## 不再用固定高度的圆弧堆成“弹簧”。三股烟流从影池连续向上绕轴，
	## 每股只转约一圈、宽度不等且中途断开，形态接近图四的卷吸黑雾。
	var phase_offsets := [0.15, 2.35, 4.8]
	var turn_counts := [1.08, 0.86, 1.22]
	var visible_height := clampf(0.16 + phase * 0.84, 0.0, 1.0)
	for ribbon in range(3):
		var previous := Vector2.ZERO
		var previous_valid := false
		for segment in range(32):
			var normalized := float(segment) / 31.0
			var t := normalized * visible_height
			var profile := pow(maxf(sin(t * PI), 0.0), 0.72)
			var angle := (
				float(phase_offsets[ribbon])
				+ elapsed * (1.55 + ribbon * 0.16)
				+ phase * 1.9
				+ t * TAU * float(turn_counts[ribbon])
			)
			var radius := lerpf(15.0 + ribbon * 2.0, 50.0 - ribbon * 3.0, profile)
			var current := Vector2(
				cos(angle) * radius,
				-5.0 - t * 142.0 + sin(angle) * (4.0 + profile * 5.5)
			)
			## 不同位置断开一两节，让烟流像被卷散的烟瓣，而不是连续塑料管。
			var gap_index := (segment + ribbon * 4) % 13
			var is_gap := gap_index == 8 or gap_index == 9
			if previous_valid and not is_gap:
				var taper := pow(1.0 - t * 0.72, 0.8)
				var core_width := (5.6 + profile * 6.2 - ribbon * 0.7) * taper
				draw_line(previous, current, VEIL_VIOLET * Color(1, 1, 1, alpha * 0.14), core_width + 5.0, true)
				draw_line(previous, current, SMOKE_BLACK * Color(1, 1, 1, alpha * 0.36), core_width, true)
			previous = current
			previous_valid = not is_gap


func _draw_tendrils(phase:float, alpha:float) -> void:
	## 每根触须是一条带弯曲控制点的渐细曲线：暗靛外缘、近黑色内芯。
	## 逐段绘制宽度，避免再次出现第一版那种等宽竖线。
	for tendril in _tendrils:
		var delay:float = float(tendril[&"delay"])
		var length_phase := clampf((phase - delay) / maxf(1.0 - delay, 0.01), 0.0, 1.0)
		if length_phase <= 0.0:
			continue
		var base_x:float = float(tendril[&"base_x"])
		var height:float = float(tendril[&"height"])
		var lean:float = float(tendril[&"lean"])
		var curl:float = float(tendril[&"curl"])
		var sway := sin(elapsed * float(tendril[&"speed"]) + float(tendril[&"phase"])) * 7.0
		var p0 := Vector2(base_x, -2.0)
		var p1 := Vector2(base_x - lean * 0.25 + sway, -height * 0.30)
		var p2 := Vector2(base_x + lean + curl + sway * 0.6, -height * 0.72)
		var p3 := Vector2(base_x + lean + sway, -height)
		var previous := p0
		var segments := 13
		for segment in range(1, segments + 1):
			var t := length_phase * float(segment) / float(segments)
			var current := p0.bezier_interpolate(p1, p2, p3, t)
			var taper := pow(1.0 - t, 0.72)
			var core_width := 1.1 + taper * float(tendril[&"width"])
			draw_line(previous, current, VEIL_VIOLET * Color(1, 1, 1, alpha * 0.66), core_width + 4.2, true)
			draw_line(previous, current, VOID_BLACK * Color(1, 1, 1, alpha * 0.94), core_width, true)
			previous = current


func _draw_shadow_shards(progress:float, envelope:float, reverse:bool) -> void:
	var motion_phase := 1.0 - progress if reverse else progress
	for shard in _shards:
		var origin:Vector2 = shard[&"origin"]
		var velocity:Vector2 = shard[&"velocity"]
		var center := origin + velocity * motion_phase
		var size:float = float(shard[&"size"]) * (0.7 + motion_phase * 0.6)
		var angle:float = float(shard[&"angle"]) + motion_phase * float(shard[&"spin"])
		var forward := Vector2(cos(angle), sin(angle)) * size
		var side := forward.orthogonal() * 0.34
		var wisp := PackedVector2Array([
			center + forward * 1.7,
			center + side,
			center - forward * 0.85,
			center - side * 0.58,
		])
		draw_colored_polygon(wisp, VOID_BLACK * Color(1, 1, 1, envelope * 0.9))
		draw_polyline(PackedVector2Array([wisp[0], wisp[1], wisp[2], wisp[3], wisp[0]]), SHADOW_INDIGO * Color(1, 1, 1, envelope * 0.42), 1.2, true)


func _draw_ground_stain(radius:float, alpha:float) -> void:
	## 多层不规则影池从脚底向外晕开，中心近乎纯黑，边缘带暗靛色烟晕。
	for layer in range(3):
		var points := PackedVector2Array()
		var layer_scale := 1.0 + float(layer) * 0.22
		for i in range(40):
			var angle := float(i) / 40.0 * TAU
			var uneven := 1.0 + sin(angle * (5.0 + layer) + elapsed * (1.7 + layer * 0.2)) * (0.09 + layer * 0.025)
			points.append(Vector2(cos(angle) * radius * layer_scale * uneven, sin(angle) * radius * 0.23 * layer_scale * uneven))
		var layer_color := VOID_BLACK if layer == 0 else SHADOW_INDIGO
		var layer_alpha := alpha * (0.88 if layer == 0 else 0.22 / float(layer))
		draw_colored_polygon(points, layer_color * Color(1, 1, 1, layer_alpha))


func _build_particles() -> void:
	_smoke_particles.clear()
	_shards.clear()
	_tendrils.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(get_instance_id()) * 7919 + int(effect_mode) * 104729
	var smoke_count := 26 if effect_mode != EffectMode.COUNTDOWN else 0
	for i in range(smoke_count):
		_smoke_particles.append({
			&"height": rng.randf_range(0.0, 1.0),
			&"size": rng.randf_range(0.38, 0.82),
			&"alpha": rng.randf_range(0.18, 0.42),
			&"rotation": rng.randf_range(-PI, PI),
			&"spin": rng.randf_range(1.8, 3.8),
			&"rise": rng.randf_range(4.0, 22.0),
			&"phase": rng.randf_range(0.0, TAU),
		})
	for i in range(14):
		_shards.append({
			&"origin": Vector2(rng.randf_range(-31.0, 31.0), rng.randf_range(-118.0, -8.0)),
			&"velocity": Vector2(rng.randf_range(-74.0, 74.0), rng.randf_range(-38.0, -110.0)),
			&"size": rng.randf_range(3.0, 9.5),
			&"angle": rng.randf_range(-PI, PI),
			&"spin": rng.randf_range(-3.5, 3.5),
		})
	for i in range(3):
		_tendrils.append({
			&"base_x": rng.randf_range(-43.0, 43.0),
			&"height": rng.randf_range(88.0, 158.0),
			&"lean": rng.randf_range(-44.0, 44.0),
			&"curl": rng.randf_range(-38.0, 38.0),
			&"width": rng.randf_range(2.4, 4.8),
			&"delay": rng.randf_range(0.0, 0.24),
			&"speed": rng.randf_range(2.2, 4.8),
			&"phase": rng.randf_range(0.0, TAU),
		})


func _ensure_smoke_texture() -> void:
	if _shared_smoke_texture != null:
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.72),
		Color(1, 1, 1, 0.52),
		Color(1, 1, 1, 0.14),
		Color(1, 1, 1, 0.0),
	])
	_shared_smoke_texture = GradientTexture2D.new()
	_shared_smoke_texture.width = 64
	_shared_smoke_texture.height = 64
	_shared_smoke_texture.gradient = gradient
	_shared_smoke_texture.fill = GradientTexture2D.FILL_RADIAL
	_shared_smoke_texture.fill_from = Vector2(0.5, 0.5)
	_shared_smoke_texture.fill_to = Vector2(1.0, 0.5)


func _create_countdown_label() -> void:
	_countdown_label = Label.new()
	_countdown_label.position = Vector2(-28, -184)
	_countdown_label.size = Vector2(56, 42)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override(&"font_size", 27)
	_countdown_label.add_theme_color_override(&"font_color", WISP_VIOLET * Color(1, 1, 1, 0.94))
	_countdown_label.add_theme_color_override(&"font_shadow_color", Color(0.01, 0.0, 0.0, 0.98))
	_countdown_label.add_theme_constant_override(&"shadow_offset_x", 2)
	_countdown_label.add_theme_constant_override(&"shadow_offset_y", 2)
	add_child(_countdown_label)
