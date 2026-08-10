shader_type canvas_item;
render_mode blend_add, unshaded;

const float TAU_VALUE = 6.28318530718;

uniform int path_mode = 0; // 0: helix, 1: fire head tongue, 2: nozzle tongue
uniform float effect_length = 720.0;
uniform float visible_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float turns = 5.2;
uniform float spin_speed = 8.0;
uniform float amplitude_start = 18.0;
uniform float amplitude_end = 58.0;
uniform float turbulence = 7.0;
uniform float layer_width = 28.0;
uniform float layer_alpha : hint_range(0.0, 1.0) = 0.8;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float elapsed_time = 0.0;
uniform float phase_offset = 0.0;

uniform float head_radius = 120.0;
uniform float head_base_angle = 0.0;
uniform float head_angular_speed = 1.0;
uniform float head_drag = 80.0;

uniform vec4 edge_color : source_color = vec4(1.0, 0.08, 0.01, 0.7);
uniform vec4 middle_color : source_color = vec4(1.0, 0.34, 0.04, 0.85);
uniform vec4 hot_color : source_color = vec4(1.0, 0.82, 0.42, 0.95);

varying float ribbon_front;
varying float ribbon_reveal;
varying float ribbon_width_noise;
varying float ribbon_progress;


float hash_1d(float value) {
	return fract(sin(value * 127.1) * 43758.5453123);
}


float value_noise_1d(float value) {
	float cell = floor(value);
	float fraction = fract(value);
	float blend = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(hash_1d(cell), hash_1d(cell + 1.0), blend) * 2.0 - 1.0;
}


float hash_2d(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}


float value_noise_2d(vec2 value) {
	vec2 cell = floor(value);
	vec2 fraction = fract(value);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	float a = hash_2d(cell);
	float b = hash_2d(cell + vec2(1.0, 0.0));
	float c = hash_2d(cell + vec2(0.0, 1.0));
	float d = hash_2d(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}


void vertex() {
	float u = UV.x;
	float side = UV.y * 2.0 - 1.0;
	float time = elapsed_time + phase_offset;
	vec2 center_position = vec2(0.0);
	vec2 tangent_derivative = vec2(1.0, 0.0);
	float width_envelope = 1.0;
	float front = 1.0;
	float reveal = 1.0;
	float progress = u;

	if (path_mode == 0) {
		float safe_visible = max(visible_ratio, 0.001);
		progress = clamp(u / safe_visible, 0.0, 1.0);
		reveal = 1.0 - smoothstep(max(safe_visible - 0.035, 0.0), safe_visible, u);

		float amplitude_mix = smoothstep(0.0, 0.8, progress);
		float amplitude = mix(amplitude_start, amplitude_end, amplitude_mix);
		float phase = TAU_VALUE * turns * progress - time * spin_speed;
		float depth = cos(phase);
		front = smoothstep(-0.2, 0.8, depth);

		float slow_noise = value_noise_1d(progress * 8.0 + time * 1.5);
		float fast_noise = value_noise_1d(progress * 23.0 - time * 3.0);
		float center_y = sin(phase) * amplitude;
		center_y += slow_noise * turbulence * smoothstep(0.0, 0.4, progress);
		center_y += fast_noise * turbulence * 0.42;
		center_position = vec2(effect_length * u, center_y);

		float dprogress_du = 1.0 / safe_visible;
		float phase_du = TAU_VALUE * turns * dprogress_du;
		float smooth_t = clamp(progress / 0.8, 0.0, 1.0);
		float amplitude_du = (amplitude_end - amplitude_start) * 6.0 * smooth_t * (1.0 - smooth_t) / 0.8 * dprogress_du;
		float dy_du = cos(phase) * phase_du * amplitude + sin(phase) * amplitude_du;
		tangent_derivative = vec2(effect_length, dy_du);

		width_envelope = smoothstep(0.0, 0.075, progress);
		width_envelope *= mix(1.0, 1.34, smoothstep(0.68, 1.0, progress));
	} else if (path_mode == 1) {
		float theta = head_base_angle + u * TAU_VALUE * 0.82 + time * head_angular_speed;
		float remaining = max(1.0 - u, 0.001);
		float radius = head_radius * pow(remaining, 0.65);
		float radius_du = -head_radius * 0.65 * pow(remaining, -0.35);
		float theta_du = TAU_VALUE * 0.82;
		center_position = vec2(
			cos(theta) * radius - remaining * head_drag,
			sin(theta) * radius * 0.78
		);
		center_position.y += value_noise_1d(u * 9.0 + time * 2.1 + phase_offset) * turbulence * 0.55;
		tangent_derivative = vec2(
			cos(theta) * radius_du - sin(theta) * radius * theta_du + head_drag,
			(sin(theta) * radius_du + cos(theta) * radius * theta_du) * 0.78
		);
		front = smoothstep(-0.35, 0.75, cos(theta));
		width_envelope = smoothstep(0.0, 0.18, u) * mix(0.62, 1.0, u);
		width_envelope *= 1.0 - 0.22 * smoothstep(0.9, 1.0, u);
	} else {
		float nozzle_phase = u * TAU_VALUE * 0.72 - time * spin_speed * 0.55 + phase_offset;
		float nozzle_amp = mix(1.0, amplitude_start * 0.62, smoothstep(0.0, 0.72, u));
		center_position = vec2(effect_length * u, sin(nozzle_phase) * nozzle_amp);
		center_position.y += value_noise_1d(u * 11.0 - time * 3.4 + phase_offset) * turbulence * 0.32;
		float dy_du = cos(nozzle_phase) * TAU_VALUE * 0.72 * nozzle_amp;
		tangent_derivative = vec2(effect_length, dy_du);
		front = smoothstep(-0.25, 0.75, cos(nozzle_phase));
		width_envelope = smoothstep(0.0, 0.14, u) * (1.0 - 0.32 * smoothstep(0.76, 1.0, u));
	}

	float width_noise = mix(0.68, 1.17, value_noise_1d(u * 14.0 - time * 5.8 + phase_offset) * 0.5 + 0.5);
	float depth_width = mix(0.72, 1.18, front);
	float final_width = layer_width * width_envelope * width_noise * depth_width * reveal * intensity;
	vec2 tangent = normalize(tangent_derivative);
	vec2 normal = vec2(-tangent.y, tangent.x);
	VERTEX = center_position + normal * side * final_width * 0.5;

	ribbon_front = front;
	ribbon_reveal = reveal;
	ribbon_width_noise = width_noise;
	ribbon_progress = progress;
}


void fragment() {
	float distance_from_center = abs(UV.y * 2.0 - 1.0);
	float time = elapsed_time + phase_offset;
	float flow = value_noise_2d(vec2(UV.x * 12.0 - time * 2.5, UV.y * 4.0 + phase_offset));
	float fine_flicker = value_noise_2d(vec2(UV.x * 31.0 + time * 6.8, UV.y * 9.0 - time * 3.7));
	float torn_distance = distance_from_center + (flow - 0.5) * 0.22 + (fine_flicker - 0.5) * 0.08;
	float soft_edge = 1.0 - smoothstep(0.22, 1.0, torn_distance);
	float core = pow(max(1.0 - distance_from_center, 0.0), 2.2);
	float broken_edge = mix(0.56, 1.0, smoothstep(0.18, 0.82, flow));
	float depth_brightness = mix(0.46, 1.0, ribbon_front);
	float flow_brightness = mix(0.72, 1.16, flow);
	float alpha = soft_edge * broken_edge * layer_alpha * ribbon_reveal * intensity;
	alpha *= mix(0.75, 1.0, ribbon_width_noise);

	vec3 color = mix(edge_color.rgb, middle_color.rgb, smoothstep(0.05, 0.72, core));
	color = mix(color, hot_color.rgb, pow(core, 2.4));
	color *= depth_brightness * flow_brightness;
	COLOR = vec4(color, alpha * mix(edge_color.a, hot_color.a, core));
}
