shader_type canvas_item;

uniform vec4 target_color : source_color = vec4(1.0, 0.95, 0.0, 1.0);
uniform float alpha_scale = 1.45;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(target_color.rgb, min(tex.a * COLOR.a * target_color.a * alpha_scale, 1.0));
}
