shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_tint : source_color = vec4(1.0, 0.82, 0.56, 1.0);
uniform float glow_amount : hint_range(0.0, 1.0) = 0.0;

float orb(vec2 uv, vec2 center, float radius) {
	float distance_to_center = length(uv - center);
	return 1.0 - smoothstep(radius * 0.45, radius, distance_to_center);
}

void fragment() {
	// 这层比原图四周多 16 像素余量，让光珠能组成完整的纵向椭圆环。
	const float ORB_RADIUS = 0.0584;
	float raw_glow = clamp(glow_amount, 0.0, 1.0);
	float glow_phase = smoothstep(0.02, 0.58, raw_glow);
	float orb_radius = ORB_RADIUS * mix(0.55, 1.30, glow_phase);
	float orbs = 0.0;
	float cores = 0.0;
	// 手掌优先：按原图八只手掌的上缘锚定，整体再保持纵向椭圆的节奏。
	vec2 left_top = vec2(0.252, 0.114);
	vec2 left_upper = vec2(0.110, 0.306);
	vec2 left_lower = vec2(0.092, 0.602);
	vec2 left_bottom = vec2(0.182, 0.745);
	vec2 bottom_center = vec2(0.500, 0.900);
	orbs += orb(UV, left_top, orb_radius);
	orbs += orb(UV, vec2(1.0 - left_top.x, left_top.y), orb_radius);
	orbs += orb(UV, left_upper, orb_radius);
	orbs += orb(UV, vec2(1.0 - left_upper.x, left_upper.y), orb_radius);
	orbs += orb(UV, left_lower, orb_radius);
	orbs += orb(UV, vec2(1.0 - left_lower.x, left_lower.y), orb_radius);
	orbs += orb(UV, left_bottom, orb_radius);
	orbs += orb(UV, vec2(1.0 - left_bottom.x, left_bottom.y), orb_radius);
	orbs += orb(UV, bottom_center, orb_radius);
	cores += orb(UV, left_top, orb_radius * 0.44);
	cores += orb(UV, vec2(1.0 - left_top.x, left_top.y), orb_radius * 0.44);
	cores += orb(UV, left_upper, orb_radius * 0.44);
	cores += orb(UV, vec2(1.0 - left_upper.x, left_upper.y), orb_radius * 0.44);
	cores += orb(UV, left_lower, orb_radius * 0.44);
	cores += orb(UV, vec2(1.0 - left_lower.x, left_lower.y), orb_radius * 0.44);
	cores += orb(UV, left_bottom, orb_radius * 0.44);
	cores += orb(UV, vec2(1.0 - left_bottom.x, left_bottom.y), orb_radius * 0.44);
	cores += orb(UV, bottom_center, orb_radius * 0.44);
	float water_flicker = 0.98 + 0.02 * sin(TIME * 0.75);
	vec3 warm_white_core = vec3(1.0, 0.96, 0.82);
	vec3 orb_color = mix(glow_tint.rgb, warm_white_core, clamp(cores, 0.0, 1.0));
	// 低亮度阶段只留一丝引子，高亮阶段陡峭冲顶；退场时保留微光尾巴。
	float faint_glow = smoothstep(0.0, 0.12, raw_glow) * 0.10;
	float bright_glow = pow(raw_glow, 2.25);
	float glow_intensity = max(faint_glow, bright_glow);
	COLOR = vec4(orb_color, clamp(orbs, 0.0, 1.0) * glow_intensity * water_flicker * 0.95);
}
