shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(0.08, 0.48, 1.0, 0.85);
uniform float pulse_speed = 3.2;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.001) {
		discard;
	}

	// 法老之鹰横向武器在原始方形贴图中的区域；软边只发生在贴图内部。
	float horizontal_mask = smoothstep(0.01, 0.06, UV.x) * (1.0 - smoothstep(0.94, 0.985, UV.x));
	float upper_mask = smoothstep(0.405, 0.445, UV.y);
	float lower_mask = 1.0 - smoothstep(0.585, 0.625, UV.y);
	float weapon_mask = horizontal_mask * upper_mask * lower_mask;
	if (weapon_mask <= 0.001) {
		discard;
	}

	float pulse = 0.78 + 0.22 * sin(TIME * pulse_speed);
	COLOR = vec4(glow_color.rgb * pulse, tex.a * glow_color.a * weapon_mask);
}
