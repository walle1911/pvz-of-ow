shader_type canvas_item;
render_mode blend_add, unshaded;

// Blue flowing beam shader — soft glow edges + bright core
// UV.x = along the beam (0→1 from start to end)
// UV.y = across the beam width (0→1, 0.5 = centerline)

uniform vec4 glow_color : source_color = vec4(0.08, 0.35, 1.0, 0.7);
uniform vec4 core_color : source_color = vec4(0.3, 0.7, 1.0, 0.9);
uniform float flow_speed : hint_range(0.0, 4.0) = 1.2;
uniform float flow_density : hint_range(2.0, 20.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 8.0) = 3.5;
uniform float pulse_amount : hint_range(0.0, 0.3) = 0.12;

// Glow edge softness — LOWER = softer/fuzzier edges
uniform float glow_softness : hint_range(0.3, 3.0) = 1.0;

// Core sharpness and width
uniform float core_falloff : hint_range(1.5, 6.0) = 3.5;
uniform float core_ratio : hint_range(0.03, 0.4) = 0.15;

void fragment() {
	// Distance from beam centerline — 0 at center, 1 at edges
	float dist = abs(UV.y - 0.5) * 2.0;

	// === Soft outer glow — wide, gentle falloff to transparent edges ===
	float glow = 1.0 - smoothstep(0.0, 1.0, pow(dist, glow_softness));

	// === Sharp inner core — narrow bright centerline (Gaussian-like) ===
	float core_dist = dist / core_ratio;
	float core = exp(-core_dist * core_dist * core_falloff);

	// === Flowing streaks — bright bands traveling along the beam ===
	float wave1 = sin(UV.x * flow_density - TIME * flow_speed * 6.28318) * 0.5 + 0.5;
	float wave2 = sin(UV.x * flow_density * 2.1 + TIME * flow_speed * 1.7 * 6.28318) * 0.5 + 0.5;
	float flow = wave1 * 0.7 + wave2 * 0.3;
	float flow_brightness = 0.65 + flow * 0.35;

	// === Breathing pulse ===
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	// === Combine glow and core ===
	float glow_alpha = glow * glow_color.a;
	float core_alpha = core * core_color.a;
	float combined = glow_alpha + core_alpha;

	// Apply flow and pulse
	float alpha = combined * flow_brightness * pulse;
	alpha = clamp(alpha, 0.0, 1.0);

	// Color blends from glow-tone at edges to core-tone at center
	vec3 color_rgb = mix(glow_color.rgb, core_color.rgb, core * 0.7) * (0.85 + flow * 0.15) * pulse;

	COLOR = vec4(color_rgb, alpha);
}
