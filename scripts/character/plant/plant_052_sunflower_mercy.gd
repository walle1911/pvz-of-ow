extends Plant000Base
class_name Plant052SunflowerMercy

@onready var create_sun_component: CreateSunComponent = $CreateSunComponent

@export_group("蓝线增伤")
@export var damage_boost_multiplier := 1.25
@export var target_check_interval := 0.15
@export var target_cell_offset := 1
@export var source_anchor_path:NodePath = ^"Body/BodyCorrect/Stalk_bottom"
@export var source_anchor_offset := Vector2(2, 4)
@export var target_anchor_offset := Vector2(2, 4)
@export var rope_segment_count := 24
@export var rope_sag_amount := 6.0
@export var rope_swing_amount := 3.0
@export var rope_swing_speed := 1.8
@export var rope_core_width := 4.5
@export var rope_glow_width := 10.0
@export var rope_outer_glow_width := 15.0
@export var rope_core_color := Color(0.68, 0.9, 1.0, 0.8)
@export var rope_glow_color := Color(0.48, 0.38, 1.0, 0.58)
@export var rope_outer_glow_color := Color(0.18, 0.72, 1.0, 0.24)
@export var rope_spark_count := 6
@export var rope_spark_flow_speed := 0.07
@export var rope_spark_color := Color(0.62, 0.8, 1.0, 0.38)
@export var rope_spark_scale_min := 0.22
@export var rope_spark_scale_max := 0.42
@export var mouth_glow_inner_scale := 2.2
@export var mouth_glow_outer_scale := 5.8
@export var mouth_glow_inner_color := Color(0.25, 0.75, 1.0, 0.9)
@export var mouth_glow_outer_color := Color(0.15, 0.45, 1.0, 0.48)
@export var mouth_glow_pulse_amount := 0.12
@export var mouth_glow_pulse_speed := 2.5
@export var damage_boost_target_plant_types:Array[CharacterRegistry.PlantType] = [
	CharacterRegistry.PlantType.P001PeaShooterSingle,
	CharacterRegistry.PlantType.P006SnowPea,
	CharacterRegistry.PlantType.P008PeaShooterDouble,
	CharacterRegistry.PlantType.P019ThreePeater,
	CharacterRegistry.PlantType.P029SplitPea,
	CharacterRegistry.PlantType.P041GatlingPea,
	CharacterRegistry.PlantType.P049PeaShooterDoubleReverse,
	CharacterRegistry.PlantType.P050PeaShooterSoldier76,
	CharacterRegistry.PlantType.P051PeaShooterMccree,
	CharacterRegistry.PlantType.P055SnowPeaMei,
	CharacterRegistry.PlantType.P056GatlingPeaBastion,
]

var damage_boost_target:Plant000Base
var target_check_time := 0.0
var rope_time := 0.0
var damage_boost_line_root:Node2D
var damage_boost_outer_glow_line:Line2D
var damage_boost_glow_line:Line2D
var damage_boost_core_line:Line2D
var source_anchor_node:Node2D
var target_anchor_node:Node2D
var damage_boost_mouth_glow_containers:Array[Node2D] = []
var damage_boost_rope_sparks:Array[Sprite2D] = []
var mouth_glow_texture:Texture2D
var mouth_particle_texture:Texture2D

const TARGET_ANCHOR_PATHS:Array[NodePath] = [
	^"Body/BodyCorrect/Stalk_bottom",
	^"Body/BodyCorrect/Stalk_top",
	^"Body/BodyCorrect/Anim_idle/HeadCorrect",
	^"Body/BodyCorrect/Anim_stem/stem_correct",
	^"Body/BodyCorrect",
]


func ready_norm() -> void:
	super()
	if is_zombie_mode:
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)
		return
	_create_damage_boost_line()
	source_anchor_node = get_node_or_null(source_anchor_path)
	set_process(true)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(create_sun_component.owner_update_speed)


func _process(delta:float) -> void:
	if character_init_type != E_CharacterInitType.IsNorm or is_zombie_mode:
		return

	rope_time += delta
	target_check_time -= delta
	if target_check_time <= 0:
		target_check_time = target_check_interval
		_update_damage_boost_target()

	_update_damage_boost_line()
	_update_damage_boost_mouth_glow()


## 被僵尸啃食一次特殊效果,魅惑\大蒜\我是僵尸生产阳光
func _be_zombie_eat_once_special(_attack_zombie:Zombie000Base):
	if is_zombie_mode:
		create_sun_component._on_be_eat_once()

## 植物死亡
func character_death():
	_clear_damage_boost_target()
	if is_zombie_mode:
		create_sun_component._on_character_death()
	super()


func _exit_tree() -> void:
	_clear_damage_boost_target()


func _create_damage_boost_line():
	damage_boost_line_root = Node2D.new()
	damage_boost_line_root.name = "DamageBoostLine"
	damage_boost_line_root.z_index = 200
	damage_boost_line_root.visible = false
	add_child(damage_boost_line_root)

	damage_boost_outer_glow_line = _create_one_damage_boost_line("OuterGlowLine", rope_outer_glow_width, rope_outer_glow_color)
	damage_boost_glow_line = _create_one_damage_boost_line("GlowLine", rope_glow_width, rope_glow_color)
	damage_boost_core_line = _create_one_damage_boost_line("CoreLine", rope_core_width, rope_core_color)
	_create_damage_boost_rope_sparks()


func _create_one_damage_boost_line(line_name:StringName, line_width:float, line_color:Color) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.width = line_width
	line.default_color = line_color
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	if line_name != &"CoreLine":
		line.material = _create_glow_line_material(line_color)
	damage_boost_line_root.add_child(line)
	return line


func _create_glow_line_material(glow_color:Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(0.15, 0.75, 1.0, 0.42);

void fragment() {
	float edge_distance = abs(UV.y - 0.5) * 2.0;
	float edge_alpha = 1.0 - smoothstep(0.35, 1.0, edge_distance);
	COLOR = vec4(glow_color.rgb, glow_color.a * edge_alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glow_color", glow_color)
	return material


func _update_damage_boost_target():
	var new_target := _get_damage_boost_target()
	if new_target == damage_boost_target:
		return

	_clear_damage_boost_target()
	damage_boost_target = new_target
	if is_instance_valid(damage_boost_target):
		target_anchor_node = _get_target_anchor_node(damage_boost_target)
		damage_boost_target.add_attack_damage_multiplier(self, damage_boost_multiplier)
		_create_damage_boost_mouth_glow_sprites(damage_boost_target)


func _clear_damage_boost_target():
	_clear_damage_boost_mouth_glow()
	if is_instance_valid(damage_boost_target):
		damage_boost_target.remove_attack_damage_multiplier(self)
	damage_boost_target = null
	target_anchor_node = null
	_set_damage_boost_line_visible(false)


func _get_damage_boost_target() -> Plant000Base:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.plant_cell_manager):
		return null
	if not is_instance_valid(plant_cell):
		return null
	if plant_cell.row_col.x < 0 or plant_cell.row_col.x >= Global.main_game.plant_cell_manager.all_plant_cells.size():
		return null

	var lane_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[plant_cell.row_col.x]
	var current_index := lane_cells.find(plant_cell)
	if current_index == -1:
		return null
	var target_index := current_index + target_cell_offset
	if target_index < 0 or target_index >= lane_cells.size():
		return null

	var target_cell:PlantCell = lane_cells[target_index]
	var target_plant:Plant000Base = target_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm]
	if not is_instance_valid(target_plant):
		return null
	if not damage_boost_target_plant_types.has(target_plant.plant_type):
		return null
	return target_plant


func _update_damage_boost_line():
	if not is_instance_valid(damage_boost_line_root):
		return
	if not is_instance_valid(damage_boost_target) or not is_instance_valid(source_anchor_node) or not is_instance_valid(target_anchor_node):
		_set_damage_boost_line_visible(false)
		return

	var start_pos := damage_boost_line_root.to_local(source_anchor_node.to_global(source_anchor_offset))
	var end_pos := damage_boost_line_root.to_local(target_anchor_node.to_global(target_anchor_offset))
	var points := _get_rope_points(start_pos, end_pos)

	_update_line_points(damage_boost_outer_glow_line, points)
	_update_line_points(damage_boost_glow_line, points)
	_update_line_points(damage_boost_core_line, points)
	_update_damage_boost_rope_sparks(points)
	_set_damage_boost_line_visible(true)


func _get_rope_points(start_pos:Vector2, end_pos:Vector2) -> PackedVector2Array:
	var dir := end_pos - start_pos
	if dir.length() < 1.0:
		return PackedVector2Array([start_pos, end_pos])

	var normal := Vector2(-dir.y, dir.x).normalized()
	var points := PackedVector2Array()
	var segment_count:int = maxi(1, rope_segment_count)
	var rotation_angle := rope_time * rope_swing_speed

	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		var point := start_pos.lerp(end_pos, t)
		var fixed_end_falloff := sin(PI * t)
		var sag := fixed_end_falloff * rope_sag_amount * sin(rotation_angle)
		var swing := fixed_end_falloff * rope_swing_amount * cos(rotation_angle)

		point.y += sag
		point += normal * swing
		points.append(point)

	return points


func _update_line_points(line:Line2D, points:PackedVector2Array):
	if not is_instance_valid(line):
		return
	line.points = points


func _set_damage_boost_line_visible(is_visible:bool):
	if is_instance_valid(damage_boost_line_root):
		damage_boost_line_root.visible = is_visible


func _get_target_anchor_node(target_plant:Plant000Base) -> Node2D:
	for target_anchor_path:NodePath in TARGET_ANCHOR_PATHS:
		var node := target_plant.get_node_or_null(target_anchor_path)
		if node is Node2D:
			return node
	return target_plant.body


func _create_damage_boost_mouth_glow_sprites(target_plant:Plant000Base):
	var attack_component := target_plant.get_node_or_null(^"AttackComponent")
	if not attack_component is AttackComponentBulletBase:
		return

	for marker:Marker2D in attack_component.markers_2d_bullet:
		if not is_instance_valid(marker):
			continue
		var container := Node2D.new()
		container.name = "MercyDamageBoostMouthGlow"
		container.z_index = 210
		marker.add_child(container)

		var inner_glow := Sprite2D.new()
		inner_glow.name = "InnerGlow"
		inner_glow.texture = _get_mouth_glow_texture()
		inner_glow.material = _create_mouth_particle_canvas_material()
		inner_glow.self_modulate = mouth_glow_inner_color
		inner_glow.scale = Vector2.ONE * mouth_glow_inner_scale
		container.add_child(inner_glow)

		var outer_glow := Sprite2D.new()
		outer_glow.name = "OuterGlow"
		outer_glow.texture = _get_mouth_glow_texture()
		outer_glow.material = _create_mouth_particle_canvas_material()
		outer_glow.self_modulate = mouth_glow_outer_color
		outer_glow.scale = Vector2.ONE * mouth_glow_outer_scale
		container.add_child(outer_glow)

		damage_boost_mouth_glow_containers.append(container)


func _update_damage_boost_mouth_glow():
	var pulse:float = 1.0 + mouth_glow_pulse_amount * sin(rope_time * mouth_glow_pulse_speed)
	var alpha_pulse:float = 0.85 + 0.15 * sin(rope_time * mouth_glow_pulse_speed * 1.3)

	for container:Node2D in damage_boost_mouth_glow_containers:
		if not is_instance_valid(container):
			continue
		var inner_glow := container.get_node_or_null(^"InnerGlow") as Sprite2D
		if is_instance_valid(inner_glow):
			inner_glow.scale = Vector2.ONE * mouth_glow_inner_scale * pulse
			inner_glow.self_modulate = Color(
				mouth_glow_inner_color.r,
				mouth_glow_inner_color.g,
				mouth_glow_inner_color.b,
				mouth_glow_inner_color.a * alpha_pulse
			)

		var outer_glow := container.get_node_or_null(^"OuterGlow") as Sprite2D
		if is_instance_valid(outer_glow):
			outer_glow.scale = Vector2.ONE * mouth_glow_outer_scale * pulse
			outer_glow.self_modulate = Color(
				mouth_glow_outer_color.r,
				mouth_glow_outer_color.g,
				mouth_glow_outer_color.b,
				mouth_glow_outer_color.a * alpha_pulse
			)


func _clear_damage_boost_mouth_glow():
	for container:Node2D in damage_boost_mouth_glow_containers:
		if is_instance_valid(container):
			container.queue_free()
	damage_boost_mouth_glow_containers.clear()


func _get_mouth_glow_texture() -> Texture2D:
	if is_instance_valid(mouth_glow_texture):
		return mouth_glow_texture

	var image_size := 64
	var image := Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(image_size - 1) * 0.5, float(image_size - 1) * 0.5)
	var radius := float(image_size) * 0.5

	for x in range(image_size):
		for y in range(image_size):
			var distance := Vector2(float(x), float(y)).distance_to(center)
			var t:float = clamp(1.0 - distance / radius, 0.0, 1.0)
			# 中心亮蓝 → 边缘透明的蓝色渐变
			var r:float = lerpf(0.2, 0.0, 1.0 - t)
			var g:float = lerpf(0.65, 0.0, 1.0 - t)
			var b:float = lerpf(1.0, 0.05, 1.0 - t)
			var alpha:float = t * t * t
			image.set_pixel(x, y, Color(r, g, b, alpha))

	mouth_glow_texture = ImageTexture.create_from_image(image)
	return mouth_glow_texture


func _create_damage_boost_rope_sparks():
	for i in range(rope_spark_count):
		var spark := Sprite2D.new()
		spark.name = "RopeSpark"
		spark.texture = _get_mouth_particle_texture()
		spark.material = _create_mouth_particle_canvas_material()
		spark.self_modulate = rope_spark_color
		spark.z_index = 60
		spark.visible = false
		damage_boost_line_root.add_child(spark)
		damage_boost_rope_sparks.append(spark)


func _update_damage_boost_rope_sparks(points:PackedVector2Array):
	if points.size() < 2:
		_set_damage_boost_rope_sparks_visible(false)
		return

	var spark_count:int = damage_boost_rope_sparks.size()
	if spark_count == 0:
		return

	for i in range(spark_count):
		var spark := damage_boost_rope_sparks[i]
		if not is_instance_valid(spark):
			continue
		var base_t := float(i + 1) / float(spark_count + 1)
		var drift:float = fposmod(base_t + rope_time * rope_spark_flow_speed, 1.0)
		var alpha_wave:float = 0.65 + 0.35 * sin(rope_time * 2.6 + float(i) * 1.7)
		var scale_wave:float = 0.5 + 0.5 * sin(rope_time * 3.1 + float(i) * 2.3)
		var spark_scale:float = lerpf(rope_spark_scale_min, rope_spark_scale_max, scale_wave)

		spark.position = _sample_rope_points(points, drift)
		spark.scale = Vector2.ONE * spark_scale
		spark.self_modulate = Color(rope_spark_color.r, rope_spark_color.g, rope_spark_color.b, rope_spark_color.a * alpha_wave)
		spark.visible = true


func _set_damage_boost_rope_sparks_visible(is_visible:bool):
	for spark:Sprite2D in damage_boost_rope_sparks:
		if is_instance_valid(spark):
			spark.visible = is_visible


func _sample_rope_points(points:PackedVector2Array, t:float) -> Vector2:
	var segment_count:int = maxi(1, points.size() - 1)
	var scaled_t:float = clamp(t, 0.0, 1.0) * float(segment_count)
	var index:int = mini(int(floor(scaled_t)), segment_count - 1)
	var local_t:float = scaled_t - float(index)
	return points[index].lerp(points[index + 1], local_t)


func _create_mouth_particle_canvas_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _get_mouth_particle_texture() -> Texture2D:
	if is_instance_valid(mouth_particle_texture):
		return mouth_particle_texture

	var image_size := 8
	var image := Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(image_size - 1) * 0.5, float(image_size - 1) * 0.5)
	var radius := float(image_size) * 0.5

	for x in range(image_size):
		for y in range(image_size):
			var distance := Vector2(float(x), float(y)).distance_to(center)
			var alpha:float = clamp(1.0 - distance / radius, 0.0, 1.0)
			alpha *= alpha
			image.set_pixel(x, y, Color(0.45, 0.82, 1.0, alpha))

	mouth_particle_texture = ImageTexture.create_from_image(image)
	return mouth_particle_texture
