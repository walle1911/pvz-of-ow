shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.9, 0.92);
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * 1.5;
	float surrounding_alpha = 1.0;
	surrounding_alpha = min(surrounding_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	surrounding_alpha = min(surrounding_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
	surrounding_alpha = min(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	surrounding_alpha = min(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
	surrounding_alpha = min(surrounding_alpha, texture(TEXTURE, UV + pixel).a);
	surrounding_alpha = min(surrounding_alpha, texture(TEXTURE, UV - pixel).a);
	surrounding_alpha = min(surrounding_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	surrounding_alpha = min(surrounding_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
	// 只在实体内部、紧贴透明边缘的位置发光，不覆盖角色本身的绘制细节。
	float inner_outline = max(source.a - surrounding_alpha, 0.0);
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed);
	COLOR = vec4(glow_color.rgb * pulse, inner_outline * glow_color.a * pulse);
}
