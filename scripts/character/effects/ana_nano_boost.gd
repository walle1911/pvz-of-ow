extends Node
class_name AnaNanoBoost

var target_plant:Plant000Base
var attack_component:AttackComponentBulletBase
var remaining_duration := 0.0
var glow_shader:Shader
var glow_pairs:Array[Dictionary] = []
var is_applied := false


func _ready() -> void:
	set_process(false)


func start_boost(
	new_target:Plant000Base,
	attack_speed_multiplier:float,
	damage_multiplier:float,
	duration:float
) -> void:
	_remove_gameplay_boost()
	target_plant = new_target
	attack_component = target_plant.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
	remaining_duration = maxf(duration, 0.1)

	target_plant.add_attack_damage_multiplier(self, damage_multiplier)
	if is_instance_valid(attack_component):
		attack_component.add_attack_speed_multiplier(self, attack_speed_multiplier)
	is_applied = true

	if glow_pairs.is_empty():
		_create_full_body_glow()
	set_process(true)


func _process(delta:float) -> void:
	remaining_duration -= delta
	_sync_full_body_glow()
	if remaining_duration <= 0.0:
		finish_boost()


func finish_boost() -> void:
	_remove_gameplay_boost()
	queue_free()


func _exit_tree() -> void:
	_remove_gameplay_boost()


func _remove_gameplay_boost() -> void:
	if not is_applied:
		return
	if is_instance_valid(target_plant):
		target_plant.remove_attack_damage_multiplier(self)
	if is_instance_valid(attack_component):
		attack_component.remove_attack_speed_multiplier(self)
	is_applied = false


func _create_full_body_glow() -> void:
	if not is_instance_valid(target_plant) or not is_instance_valid(target_plant.body):
		return
	var body_sprites:Array[Sprite2D] = []
	_collect_body_sprites(target_plant.body, body_sprites)
	for source_sprite:Sprite2D in body_sprites:
		var overlay := Sprite2D.new()
		overlay.name = "AnaNanoBoostOverlay"
		overlay.z_index = 1
		overlay.z_as_relative = true
		overlay.material = _create_glow_material()
		source_sprite.add_child(overlay)
		glow_pairs.append({"source": source_sprite, "overlay": overlay})
	_sync_full_body_glow()


func _collect_body_sprites(node:Node, result:Array[Sprite2D]) -> void:
	for child:Node in node.get_children():
		if child is Sprite2D and is_instance_valid((child as Sprite2D).texture):
			result.append(child as Sprite2D)
		_collect_body_sprites(child, result)


func _sync_full_body_glow() -> void:
	for pair:Dictionary in glow_pairs:
		var source := pair.get("source") as Sprite2D
		var overlay := pair.get("overlay") as Sprite2D
		if not is_instance_valid(source) or not is_instance_valid(overlay):
			continue
		overlay.texture = source.texture
		overlay.centered = source.centered
		overlay.offset = source.offset
		overlay.flip_h = source.flip_h
		overlay.flip_v = source.flip_v
		overlay.region_enabled = source.region_enabled
		overlay.region_rect = source.region_rect
		overlay.hframes = source.hframes
		overlay.vframes = source.vframes
		overlay.frame = source.frame
		overlay.position = Vector2.ZERO
		overlay.rotation = 0.0
		overlay.scale = Vector2.ONE
		overlay.skew = 0.0
		overlay.visible = source.visible and is_instance_valid(source.texture)


func _create_glow_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_glow_shader()
	return material


func _get_glow_shader() -> Shader:
	if is_instance_valid(glow_shader):
		return glow_shader
	glow_shader = Shader.new()
	glow_shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 base_color : source_color = vec4(0.0, 0.35, 0.72, 0.50);
uniform vec4 highlight_color : source_color = vec4(0.2, 0.65, 0.95, 0.58);
uniform float pulse_amount = 0.16;
uniform float pulse_speed = 2.8;
uniform float flow_speed = 1.4;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = tex.a;
	// 复用天使强化的蓝色呼吸流动方式，但整体透明度更淡。
	float flow = 0.5 + 0.5 * sin((UV.x * 13.0 + UV.y * 7.0) + TIME * flow_speed * 6.28318);
	float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed);
	// 在全身流光上保留更细、更亮的微电流纹理。
	float current_a = smoothstep(0.90, 1.0, sin(UV.x * 42.0 + sin(UV.y * 19.0 + TIME * 4.0) * 3.2 - TIME * 9.0));
	float current_b = smoothstep(0.94, 1.0, sin(UV.y * 47.0 - UV.x * 11.0 + TIME * 7.0));
	float current = max(current_a, current_b) * (0.55 + 0.45 * flow);
	vec3 color = mix(base_color.rgb, highlight_color.rgb, flow * 0.45) * pulse;
	color = mix(color, vec3(0.58, 0.90, 1.0), current * 0.38);
	float alpha = mask * (mix(base_color.a, highlight_color.a, flow) + current * 0.10);
	COLOR = vec4(color, alpha);
}
"""
	return glow_shader
