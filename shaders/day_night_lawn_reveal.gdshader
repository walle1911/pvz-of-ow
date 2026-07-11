shader_type canvas_item;

uniform sampler2D night_texture : source_color, filter_linear_mipmap;
uniform sampler2D reveal_mask : filter_linear;
uniform sampler2D press_mask : filter_linear;
uniform float press_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 day_color = texture(TEXTURE, UV);
	vec4 night_color = texture(night_texture, UV);
	float reveal = texture(reveal_mask, UV).r;
	vec4 lawn_color = mix(day_color, night_color, smoothstep(0.08, 0.92, reveal));
	float pressed = texture(press_mask, UV).r * press_strength;
	COLOR = mix(lawn_color, lawn_color * vec4(0.62, 0.72, 0.58, 1.0), pressed);
}
