shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_seed = 0.0;

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7)) + noise_seed) * 43758.5453);
}

float noise_1d(float value) {
	float cell = floor(value);
	float fraction = fract(value);
	float blend = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(hash(vec2(cell, 19.0)), hash(vec2(cell + 1.0, 19.0)), blend);
}

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float wind_scroll = dissolve_progress * 4.0;
	// 连续噪声只扰动外围，并随消散向前漂移，形成不规则气流轮廓。
	float broad_flow = noise_1d(UV.x * 34.0 + wind_scroll);
	float fine_flow = noise_1d(UV.x * 91.0 - wind_scroll * 1.7 + 37.0);
	float edge_noise = (broad_flow - 0.5) * 0.25 + (fine_flow - 0.5) * 0.1;
	float turbulence_growth = mix(0.65, 1.45, dissolve_progress);
	float disturbed_across = across + edge_noise * turbulence_growth * smoothstep(0.08, 1.0, across);
	// 从中心到受扰动的边缘全程羽化，避免产生新的锯齿硬边。
	float soft_edge = pow(max(1.0 - disturbed_across, 0.0), 2.15);
	float coarse_noise = noise_1d((UV.x + dissolve_progress * 0.08) * 72.0 + floor(UV.y * 5.0) * 13.0);
	float streak_noise = noise_1d((UV.x - dissolve_progress * 0.1) * 28.0 + floor(UV.y * 2.0) * 17.0 + 51.0);
	float breakup = coarse_noise * 0.54 + streak_noise * 0.24 + UV.x * 0.22;
	float dissolve_mask = smoothstep(dissolve_progress - 0.08, dissolve_progress + 0.08, breakup);
	float late_fade = 1.0 - smoothstep(0.55, 1.0, dissolve_progress);
	COLOR.a *= soft_edge * dissolve_mask * late_fade;
}
