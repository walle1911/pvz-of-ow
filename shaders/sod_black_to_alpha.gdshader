shader_type canvas_item;

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float brightness = max(texel.r, max(texel.g, texel.b));
	float matte_alpha = smoothstep(0.01, 0.075, brightness);
	COLOR = vec4(texel.rgb, texel.a * matte_alpha);
}
