shader_type canvas_item;
render_mode unshaded;

uniform vec4 wall_color : source_color = vec4(0.22, 0.58, 1.0, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.42;
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.70;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.035;
uniform float scan_speed : hint_range(-5.0, 5.0) = 0.06;
uniform float scan_strength : hint_range(0.0, 0.5) = 0.018;
uniform float scan_density : hint_range(0.5, 30.0) = 3.0;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.10;

void fragment() {
	float vertical_fade = mix(0.76, 1.0, smoothstep(0.0, 0.72, UV.y));
	float breath_wave = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float pulse = mix(1.0 - pulse_amount, 1.0 + pulse_amount, breath_wave);
	float scan_phase = (UV.y - TIME * scan_speed) * scan_density * 6.283185;
	float scan = pow(sin(scan_phase) * 0.5 + 0.5, 2.0) * scan_strength;
	float soft_rim = (smoothstep(0.16, 0.0, UV.y) + smoothstep(0.84, 1.0, UV.y)) * edge_strength;
	float alpha = base_alpha * vertical_fade * pulse + scan + soft_rim;
	vec3 energy_tint = vec3(0.10, 0.18, 0.30) * (scan + breath_wave * 0.008);
	COLOR = vec4(wall_color.rgb + energy_tint, alpha * COLOR.a);
}
