extends Node2D
class_name TallNutSigmaGravityWellEffect

signal finished

var _duration:float = 1.5
var _elapsed:float = 0.0
var _vortex_sprite:Sprite2D
var _vortex_material:ShaderMaterial


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 5
	_create_vortex_surface()
	set_process(false)


func play(center_position:Vector2, radii:Vector2, duration:float) -> void:
	global_position = center_position
	_duration = maxf(0.01, duration)
	_elapsed = 0.0
	_vortex_sprite.scale = Vector2(maxf(1.0, radii.x), maxf(1.0, radii.y))
	_vortex_material.set_shader_parameter(&"appear", 0.0)
	_vortex_material.set_shader_parameter(&"breath", 0.0)
	_vortex_material.set_shader_parameter(&"growth", 0.0)
	_vortex_material.set_shader_parameter(&"effect_time", 0.0)
	set_process(true)


func _process(delta:float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		finished.emit()
		queue_free()
		return
	var progress:float = clampf(_elapsed / _duration, 0.0, 1.0)
	var appear:float = smoothstep(0.0, 0.18, progress)
	## 三段各占约 0.5 秒：能量增强、减弱、再次增强；与黑核的单向生长解耦。
	var breath:float
	if progress < 0.3333:
		breath = smoothstep(0.0, 1.0, progress / 0.3333)
	elif progress < 0.6667:
		breath = 1.0 - smoothstep(0.0, 1.0, (progress - 0.3333) / 0.3334)
	else:
		breath = smoothstep(0.0, 1.0, (progress - 0.6667) / 0.3333)
	_vortex_material.set_shader_parameter(&"appear", appear)
	_vortex_material.set_shader_parameter(&"breath", breath)
	## 黑核只做一次很小的单向外扩，达到最大尺寸后保持，绝不回缩。
	_vortex_material.set_shader_parameter(&"growth", smoothstep(0.0, 0.92, progress))
	_vortex_material.set_shader_parameter(&"effect_time", _elapsed)


func _create_vortex_surface() -> void:
	var image:= Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_vortex_sprite = Sprite2D.new()
	_vortex_sprite.name = "PerspectiveGravityWell"
	_vortex_sprite.texture = ImageTexture.create_from_image(image)
	_vortex_material = ShaderMaterial.new()
	_vortex_material.shader = _create_vortex_shader()
	_vortex_sprite.material = _vortex_material
	add_child(_vortex_sprite)


func _create_vortex_shader() -> Shader:
	var shader:= Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float appear : hint_range(0.0, 1.0) = 0.0;
uniform float breath : hint_range(0.0, 1.0) = 0.0;
uniform float growth : hint_range(0.0, 1.0) = 0.0;
uniform float effect_time = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.52;
	for (int octave = 0; octave < 4; octave++) {
		value += value_noise(p) * amplitude;
		p = mat2(vec2(1.62, 1.18), vec2(-1.18, 1.62)) * p + 7.13;
		amplitude *= 0.48;
	}
	return value;
}

float staged_progress(float progress, float start_at) {
	return clamp((progress - start_at) / max(0.001, 1.0 - start_at), 0.0, 1.0);
}

float arc_life(float progress) {
	return smoothstep(0.0, 0.10, progress) * (1.0 - smoothstep(0.76, 1.0, progress));
}

float soft_arc(
	vec2 p,
	vec2 center,
	float radius,
	float width,
	float facing_angle,
	float half_span
) {
	vec2 q = p - center;
	float distance_to_center = length(q);
	float shell = 1.0 - smoothstep(width * 0.32, width, abs(distance_to_center - radius));
	vec2 direction = q / max(0.0001, distance_to_center);
	vec2 facing = vec2(cos(facing_angle), sin(facing_angle));
	float angular = smoothstep(cos(half_span), cos(half_span * 0.70), dot(direction, facing));
	return shell * angular;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float raw_radius = length(p);
	// 外围引力场尺寸固定；黑核的微量单向生长在下方独立计算。
	float radius = raw_radius;
	float angle = atan(p.y, p.x);
	// 外沿固定表示实际判定范围，内部密度和透镜层在范围内呼吸。
	float disc_mask = 1.0 - smoothstep(0.965, 1.0, raw_radius);

	// 径向位置固定；呼吸只改变扰动强度和能量明暗，不产生任何收缩。
	float sampled_radius = radius;
	// 扭曲量固定，角度只随时间单向累计；breath 不再驱动角度，因此不会反转。
	float twist = (1.0 - smoothstep(0.06, 1.0, radius)) * 3.55;
	float sample_angle = angle - twist - effect_time * 0.48;
	vec2 warped = vec2(cos(sample_angle), sin(sample_angle)) * sampled_radius;
	float broad_noise = fbm(warped * 3.1 + vec2(effect_time * 0.13, -effect_time * 0.08));
	float fine_noise = fbm(warped * 6.4 - vec2(effect_time * 0.19, effect_time * 0.11));
	float density = clamp(broad_noise * 0.72 + fine_noise * 0.28, 0.0, 1.0);

	// 多层错心宽弧依次向外推进。它们不是完整圆环，也不靠旋转制造运动。
	float inner_p1 = staged_progress(growth, 0.00);
	float inner_p2 = staged_progress(growth, 0.10);
	float inner_p3 = staged_progress(growth, 0.22);
	float inner_p4 = staged_progress(growth, 0.34);
	float inner_arcs = 0.0;
	inner_arcs += soft_arc(p, vec2(0.025, -0.018), mix(0.13, 0.39, inner_p1), 0.075, -0.55, 1.42) * arc_life(inner_p1);
	inner_arcs += soft_arc(p, vec2(-0.036, 0.020), mix(0.15, 0.43, inner_p2), 0.082, 2.34, 1.18) * arc_life(inner_p2);
	inner_arcs += soft_arc(p, vec2(0.012, 0.037), mix(0.18, 0.47, inner_p3), 0.088, 0.88, 1.30) * arc_life(inner_p3);
	inner_arcs += soft_arc(p, vec2(-0.018, -0.032), mix(0.20, 0.50, inner_p4), 0.094, -2.10, 1.06) * arc_life(inner_p4);

	float outer_p1 = staged_progress(growth, 0.02);
	float outer_p2 = staged_progress(growth, 0.12);
	float outer_p3 = staged_progress(growth, 0.20);
	float outer_p4 = staged_progress(growth, 0.29);
	float outer_p5 = staged_progress(growth, 0.38);
	float outer_arcs = 0.0;
	outer_arcs += soft_arc(p, vec2(0.055, -0.026), mix(0.30, 0.91, outer_p1), 0.125, -0.28, 1.30) * arc_life(outer_p1);
	outer_arcs += soft_arc(p, vec2(-0.070, 0.034), mix(0.32, 0.94, outer_p2), 0.145, 2.72, 1.04) * arc_life(outer_p2);
	outer_arcs += soft_arc(p, vec2(0.018, 0.072), mix(0.37, 0.97, outer_p3), 0.155, 1.22, 1.38) * arc_life(outer_p3);
	outer_arcs += soft_arc(p, vec2(-0.042, -0.064), mix(0.40, 1.00, outer_p4), 0.165, -1.82, 1.16) * arc_life(outer_p4);
	outer_arcs += soft_arc(p, vec2(0.082, 0.018), mix(0.44, 1.03, outer_p5), 0.175, 0.38, 0.96) * arc_life(outer_p5);
	inner_arcs *= mix(0.72, 1.08, fine_noise);
	outer_arcs *= mix(0.64, 1.04, broad_noise);

	float field_breath = mix(0.56, 1.0, breath);
	float radial_falloff = 1.0 - smoothstep(0.16, 1.0, radius);
	float funnel = pow(max(0.0, 1.0 - radius), 1.42);
	float soft_clouds = smoothstep(0.31, 0.79, density + funnel * 0.21);

	vec3 deep_indigo = vec3(0.055, 0.035, 0.16);
	vec3 gravity_violet = vec3(0.24, 0.16, 0.52);
	vec3 sigma_blue = vec3(0.34, 0.48, 0.92);
	vec3 field_color = mix(deep_indigo, gravity_violet, density);
	field_color = mix(field_color, sigma_blue, soft_clouds * 0.24 * radial_falloff);
	field_color = mix(field_color, vec3(0.17, 0.11, 0.42), clamp(inner_arcs * 0.38, 0.0, 0.62));
	field_color += sigma_blue * outer_arcs * mix(0.12, 0.29, breath);

	// 软透镜位置固定，只做能量脉动。
	float outer_lens_center = 0.88;
	float outer_lens = 1.0 - smoothstep(0.035, 0.115, abs(radius - outer_lens_center));
	float inner_lens_center = 0.47;
	float inner_lens = 1.0 - smoothstep(0.09, 0.25, abs(radius - inner_lens_center));
	field_color += sigma_blue * outer_lens * mix(0.15, 0.52, breath);
	field_color += gravity_violet * inner_lens * density * mix(0.12, 0.38, breath);

	// 事件视界只随蓄力进度缓慢外扩约 18%，growth 单调递增，呼吸值不参与半径。
	float core_radius = mix(0.125, 0.148, growth);
	float core = 1.0 - smoothstep(core_radius, core_radius + 0.012, radius);
	float accretion_inner = smoothstep(core_radius - 0.009, core_radius + 0.012, radius);
	float accretion_width = 0.205;
	float accretion_outer = 1.0 - smoothstep(core_radius + 0.025, core_radius + accretion_width, radius);
	float accretion = accretion_inner * accretion_outer;
	float accretion_texture = mix(0.52, 1.18, density);
	vec3 accretion_color = mix(vec3(0.30, 0.22, 0.72), vec3(0.48, 0.66, 1.0), fine_noise);
	field_color = mix(field_color, accretion_color * accretion_texture, accretion * mix(0.50, 0.96, breath));
	float horizon_glow = 1.0 - smoothstep(0.018, 0.085, abs(radius - core_radius - 0.018));
	horizon_glow *= 1.0 - core;
	field_color = mix(field_color, vec3(0.38, 0.30, 0.86), horizon_glow * mix(0.58, 0.88, breath));

	// 黑洞内部单独着色：多层错心弧在黑核内持续向外推进，而不是被纯黑覆盖。
	vec2 core_uv = p / max(0.001, core_radius);
	float core_phase1 = fract(effect_time * 0.58 + 0.02);
	float core_phase2 = fract(effect_time * 0.58 + 0.24);
	float core_phase3 = fract(effect_time * 0.58 + 0.47);
	float core_phase4 = fract(effect_time * 0.58 + 0.69);
	float core_phase5 = fract(effect_time * 0.58 + 0.86);
	float core_arcs = 0.0;
	core_arcs += soft_arc(core_uv, vec2(0.08, -0.05), mix(0.14, 0.93, core_phase1), 0.20, -0.48, 1.28) * arc_life(core_phase1);
	core_arcs += soft_arc(core_uv, vec2(-0.11, 0.06), mix(0.17, 0.98, core_phase2), 0.23, 2.48, 1.08) * arc_life(core_phase2);
	core_arcs += soft_arc(core_uv, vec2(0.04, 0.12), mix(0.12, 0.90, core_phase3), 0.18, 0.92, 1.36) * arc_life(core_phase3);
	core_arcs += soft_arc(core_uv, vec2(-0.06, -0.10), mix(0.20, 1.02, core_phase4), 0.25, -2.02, 1.14) * arc_life(core_phase4);
	core_arcs += soft_arc(core_uv, vec2(0.12, 0.03), mix(0.16, 0.96, core_phase5), 0.21, 0.18, 0.94) * arc_life(core_phase5);
	core_arcs = clamp(core_arcs, 0.0, 1.0);
	float core_noise = fbm(core_uv * 2.15 + vec2(effect_time * 0.12, -effect_time * 0.08));
	float core_depth = 1.0 - smoothstep(0.08, 0.82, length(core_uv));
	vec3 core_color = mix(vec3(0.006, 0.004, 0.020), vec3(0.045, 0.028, 0.105), core_noise);
	core_color += mix(vec3(0.075, 0.045, 0.18), vec3(0.16, 0.13, 0.34), fine_noise) * core_arcs;
	core_color = mix(core_color, vec3(0.003, 0.002, 0.012), core_depth * 0.46);
	field_color = mix(field_color, core_color, core);

	float base_alpha = (
		0.16
		+ soft_clouds * 0.22
		+ outer_lens * 0.24
		+ inner_lens * 0.08
		+ accretion * 0.52
		+ horizon_glow * 0.24
		+ inner_arcs * 0.14
		+ outer_arcs * 0.18
	) * field_breath;
	float alpha = max(base_alpha, core * 0.96) * disc_mask * appear;
	COLOR = vec4(field_color, alpha);
}
"""
	return shader
