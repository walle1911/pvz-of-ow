shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.53, 0.10, 0.78, 0.36);
uniform vec4 glow_color : source_color = vec4(0.88, 0.34, 1.0, 1.0);
uniform float edge_softness : hint_range(0.01, 0.2) = 0.075;
uniform vec2 preview_size = vec2(1.0);
uniform float clear_progress : hint_range(0.0, 1.1) = 0.0;

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

float energy_ridge(float value, float width) {
	return 1.0 - smoothstep(0.0, width, abs(value - 0.5));
}

float energy_spark(vec2 point, float time) {
	vec2 cell = floor(point);
	vec2 local = fract(point) - vec2(0.5);
	float seed = hash_21(cell);
	vec2 offset = vec2(hash_21(cell + 13.7), hash_21(cell + 29.3)) - vec2(0.5);
	float radius = length(local - offset * 0.56);
	float pulse = pow(max(0.0, sin(time * (2.1 + seed * 1.8) + seed * 18.0)), 8.0);
	return (1.0 - smoothstep(0.015, 0.115, radius)) * pulse * step(0.72, seed);
}

void fragment() {
	vec2 nearest_edge = min(UV, vec2(1.0) - UV);
	float edge_distance = min(nearest_edge.x, nearest_edge.y);
	float feather = smoothstep(0.0, edge_softness, edge_distance);

	// 按实际长宽修正采样比例，避免能量云被矩形区域横向拉伸。
	float aspect = preview_size.x / max(preview_size.y, 1.0);
	vec2 energy_uv = (UV - vec2(0.5)) * vec2(aspect, 1.0) * 3.15;

	// 多组不同速度的噪声互相扭曲：底层是厚重紫雾，上层是快速游动的能量云。
	float broad_flow = energy_fbm(energy_uv * 0.58 + vec2(TIME * 0.19, -TIME * 0.12));
	vec2 warp = vec2(
		energy_fbm(energy_uv * 0.91 + vec2(4.7, 1.3) - TIME * 0.17),
		energy_fbm(energy_uv * 0.84 + vec2(-2.1, 6.2) + TIME * 0.13)
	) - vec2(0.5);
	vec2 warped_uv = energy_uv + warp * 2.75;
	float energy = energy_fbm(warped_uv + vec2(-TIME * 0.22, TIME * 0.10));
	float counter_flow = energy_fbm(warped_uv * 1.46 + vec2(TIME * 0.31, -TIME * 0.18));
	float fine_energy = energy_fbm(warped_uv * 2.72 - warp * 1.4 + vec2(TIME * 0.38, TIME * 0.21));

	// 大片不规则高亮云团，模拟原版地面上不断掠过的明亮紫色能量。
	float cloud = smoothstep(0.43, 0.76, energy * 0.62 + broad_flow * 0.30 + counter_flow * 0.16);
	float cloud_core = smoothstep(0.61, 0.86, energy * 0.58 + counter_flow * 0.42);

	// 细窄能量脉络被同一组扭曲场推动，不会形成规则矩形或等距波纹。
	float vein_a = energy_ridge(fine_energy, 0.21) * smoothstep(0.44, 0.78, energy);
	float vein_b = energy_ridge(counter_flow, 0.13) * smoothstep(0.48, 0.82, broad_flow);
	float veins = clamp(vein_a * 0.72 + vein_b * 0.48, 0.0, 1.0);
	float sparks = energy_spark(warped_uv * 2.1 + vec2(TIME * 0.42, -TIME * 0.24), TIME);

	float energy_light = clamp(cloud * 0.66 + cloud_core * 0.52 + veins * 0.36 + sparks * 0.72, 0.0, 1.0);
	vec3 final_color = mix(shadow_color.rgb * 0.78, glow_color.rgb, energy_light * 0.78);
	float opacity = mix(0.72, 1.38, clamp(cloud * 0.74 + veins * 0.34 + sparks, 0.0, 1.0));

	// 尖刺从左向右落地时，同步以扰动过的柔软前沿擦除已经结算的区域。
	float clear_noise = (energy_fbm(vec2(UV.y * 5.7, TIME * 0.34)) - 0.5) * 0.055;
	float remaining = smoothstep(clear_progress - 0.035, clear_progress + 0.035, UV.x + clear_noise);

	COLOR = vec4(
		clamp(final_color, vec3(0.0), vec3(1.0)),
		shadow_color.a * feather * opacity * remaining
	);
}
