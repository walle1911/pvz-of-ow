shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.46, 0.08, 0.68, 0.30);
uniform float edge_softness : hint_range(0.01, 0.2) = 0.065;
uniform vec2 preview_size = vec2(1.0);

float hash_21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float bottom = mix(hash_21(cell), hash_21(cell + vec2(1.0, 0.0)), blend.x);
	float top = mix(hash_21(cell + vec2(0.0, 1.0)), hash_21(cell + vec2(1.0, 1.0)), blend.x);
	return mix(bottom, top, blend.y);
}

float energy_fbm(vec2 point) {
	float value = 0.0;
	float amplitude = 0.52;
	mat2 turn = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int octave = 0; octave < 4; octave++) {
		value += value_noise(point) * amplitude;
		point = turn * point * 2.03 + vec2(7.13, 3.71);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 nearest_edge = min(UV, vec2(1.0) - UV);
	float edge_distance = min(nearest_edge.x, nearest_edge.y);
	float feather = smoothstep(0.0, edge_softness, edge_distance);

	// 按实际长宽修正采样比例，避免能量云被矩形区域横向拉伸。
	float aspect = preview_size.x / max(preview_size.y, 1.0);
	vec2 energy_uv = (UV - vec2(0.5)) * vec2(aspect, 1.0) * 3.15;

	// 两组缓慢移动的噪声互相扭曲，形成无固定轮廓的紫色能量涌动。
	float broad_flow = energy_fbm(energy_uv + vec2(TIME * 0.15, -TIME * 0.09));
	vec2 warp = vec2(
		energy_fbm(energy_uv * 1.27 + vec2(4.7, 1.3) - TIME * 0.11),
		energy_fbm(energy_uv * 1.19 + vec2(-2.1, 6.2) + TIME * 0.08)
	) - vec2(0.5);
	float energy = energy_fbm(energy_uv + warp * 2.2 + vec2(-TIME * 0.12, TIME * 0.07));
	float fine_energy = energy_fbm(energy_uv * 2.35 - warp + vec2(TIME * 0.19, TIME * 0.13));

	float irregular_light = smoothstep(0.25, 0.82, energy * 0.72 + broad_flow * 0.28);
	irregular_light += (fine_energy - 0.5) * 0.16;
	irregular_light = clamp(irregular_light, 0.0, 1.0);

	// 始终使用同一个紫色色相，只让局部亮度与透明度不规则呼吸。
	float brightness = mix(0.72, 1.34, irregular_light);
	float opacity = mix(0.72, 1.18, irregular_light);
	vec3 final_color = clamp(shadow_color.rgb * brightness, vec3(0.0), vec3(1.0));

	COLOR = vec4(
		final_color,
		shadow_color.a * feather * opacity
	);
}
