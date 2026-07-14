shader_type canvas_item;

uniform float clip_y;
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	if (local_y > clip_y) {
		discard;
	}
	COLOR = texture(TEXTURE, UV);
}
