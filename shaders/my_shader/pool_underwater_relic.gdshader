shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 underwater_tint : source_color = vec4(0.04, 0.34, 0.42, 1.0);
uniform vec4 glow_tint : source_color = vec4(1.0, 0.74, 0.24, 1.0);
uniform float underwater_alpha : hint_range(0.0, 1.0) = 0.08;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.82;
uniform float ripple_strength : hint_range(0.0, 0.04) = 0.012;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float idle_alpha_variation : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	// Two very small, asynchronous offsets keep the silhouette from reading as a flat decal.
	vec2 wave_offset = vec2(
		sin((UV.y + TIME * 0.12) * 24.0) * ripple_strength,
		cos((UV.x - TIME * 0.10) * 17.0) * ripple_strength * 0.55
	);
	vec4 relic = texture(TEXTURE, UV + wave_offset);
	vec3 water_behind = texture(screen_texture, SCREEN_UV).rgb;
	vec3 submerged = mix(relic.rgb, water_behind, 0.42);
	submerged = mix(submerged, underwater_tint.rgb, tint_strength);
	float idle_pulse = 0.5 + 0.5 * sin(TIME * 0.63 + UV.y * 3.6 + sin(UV.x * 6.0) * 0.3);
	float alpha_wave = mix(1.0 - idle_alpha_variation, 1.0, idle_pulse);
	// 亮珠先保留一丝微光，再用幂曲线快速冲向峰值，避免长时间处于接近的亮度。
	float glow_curve = pow(clamp(glow_amount, 0.0, 1.0), 2.15);
	// 本体在亮珠已经出现后才显现；退场时在亮珠的微光尾巴前先完全消失。
	float body_reveal = smoothstep(0.10, 0.52, glow_amount);
	vec3 final_color = mix(submerged, glow_tint.rgb, glow_curve);
	float body_alpha_scale = mix(underwater_alpha * alpha_wave, 0.30, body_reveal) * body_reveal;

	// 只向外扩 2 个纹理像素的轮廓金光，贴着角色存在，不污染整片水面。
	vec2 halo_texel = TEXTURE_PIXEL_SIZE * 1.8;
	float dilated_alpha = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			dilated_alpha = max(dilated_alpha, texture(TEXTURE, UV + vec2(float(x), float(y)) * halo_texel).a);
		}
	}
	float close_halo = max(0.0, dilated_alpha - relic.a * 0.35);
	float body_alpha = relic.a * body_alpha_scale;
	float halo_alpha = close_halo * body_reveal * 0.10;
	vec3 halo_color = mix(glow_tint.rgb, vec3(1.0, 0.93, 0.70), 0.45);
	vec3 output_color = mix(halo_color, final_color, relic.a);
	COLOR = vec4(output_color, max(body_alpha, halo_alpha));
}
