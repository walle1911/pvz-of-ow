shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.68, 0.16, 1.0, 0.72);

void fragment() {
	COLOR = texture(TEXTURE, UV) * tint_color;
}
