extends Plant000Base
class_name Plant052SunflowerMercy

@onready var create_sun_component: CreateSunComponent = $CreateSunComponent

@export_group("蓝线增伤")
@export var damage_boost_multiplier := 1.25
@export var damage_boost_target_check_interval := 0.15
@export var damage_boost_target_cell_max_range := 2
@export var damage_boost_source_anchor_path:NodePath = ^"Body/BodyCorrect/Stalk_bottom"
@export var damage_boost_source_anchor_offset := Vector2(2, 4)
@export var damage_boost_target_anchor_offset := Vector2(2, 4)

@export_subgroup("蓝线增伤 | 目标植物类型")
## 可以被增伤的目标植物类型列表——在编辑器中手动增删
@export var damage_boost_target_plant_types:Array[CharacterRegistry.PlantType] = [
	CharacterRegistry.PlantType.P500PeaShooterSingle,
	CharacterRegistry.PlantType.P505SnowPea,
	CharacterRegistry.PlantType.P507PeaShooterDouble,
	CharacterRegistry.PlantType.P518ThreePeater,
	CharacterRegistry.PlantType.P528SplitPea,
	CharacterRegistry.PlantType.P540GatlingPea,
	CharacterRegistry.PlantType.P549PeaShooterDoubleReverse,
	CharacterRegistry.PlantType.P001PeaShooterSoldier76,
	CharacterRegistry.PlantType.P006SnowPeaMei,
	CharacterRegistry.PlantType.P041GatlingPeaBastion,
]

@export_subgroup("蓝线增伤 | 自定义目标配置")
## 非豌豆射手植物的自定义配置——蓝线连接锚点 + 发光精灵路径
## 豌豆射手类型无需配置（默认自动搜索 mouth 精灵）
@export var damage_boost_target_configs: Array[DamageBoostTargetConfig] = []

@export_subgroup("蓝线增伤 | 光束外观")
@export var beam_glow_width := 12.0
@export var beam_curve_height := -4.0
@export var beam_z_index := 200

@export_subgroup("蓝线增伤 | 发光效果")
@export var glow_overlay_base_color := Color(0.0, 0.35, 0.72, 0.82)
@export var glow_overlay_highlight_color := Color(0.2, 0.65, 0.95, 0.88)
@export var glow_overlay_pulse_amount := 0.18
@export var glow_overlay_pulse_speed := 2.8
@export var glow_overlay_flow_speed := 1.4

var damage_boost_target:Plant000Base
var target_check_time := 0.0
var damage_boost_beam: BuffBeam2D
var source_anchor_node:Node2D
var target_anchor_node:Node2D
var damage_boost_glow_containers:Array[Node2D] = []
var glow_overlay_shader:Shader
var config_lookup:Dictionary = {}  ## plant_type → DamageBoostTargetConfig

const TARGET_ANCHOR_PATHS:Array[NodePath] = [
	^"Body/BodyCorrect/Stalk_bottom",
	^"Body/BodyCorrect/Stalk_top",
	^"Body/BodyCorrect/Anim_idle/HeadCorrect",
	^"Body/BodyCorrect/Anim_stem/stem_correct",
	^"Body/BodyCorrect",
]

const BEAM_SCENE := preload("res://scenes/effects/BuffBeam2D.tscn")


func ready_norm() -> void:
	super()
	if is_zombie_mode:
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)
		return
	_create_damage_boost_beam()
	_build_config_lookup()
	source_anchor_node = get_node_or_null(damage_boost_source_anchor_path)
	set_process(true)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(create_sun_component.owner_update_speed)


func _process(delta:float) -> void:
	if character_init_type != E_CharacterInitType.IsNorm or is_zombie_mode:
		return

	target_check_time -= delta
	if target_check_time <= 0:
		target_check_time = damage_boost_target_check_interval
		_update_damage_boost_target()

	_update_damage_boost_beam()
	_update_damage_boost_glow()


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


# ================================================================
# Beam
# ================================================================

func _create_damage_boost_beam() -> void:
	damage_boost_beam = BEAM_SCENE.instantiate()
	damage_boost_beam.name = "DamageBoostBeam"
	damage_boost_beam.beam_width = beam_glow_width
	damage_boost_beam.curve_height = beam_curve_height
	damage_boost_beam.z_index_override = beam_z_index
	damage_boost_beam.hide_beam()
	add_child(damage_boost_beam)


func _update_damage_boost_beam() -> void:
	if not is_instance_valid(damage_boost_beam):
		return
	if not is_instance_valid(damage_boost_target) or not is_instance_valid(source_anchor_node) or not is_instance_valid(target_anchor_node):
		damage_boost_beam.hide_beam()
		return

	# Compute global positions from anchors, then convert to beam-local
	var from_global := source_anchor_node.to_global(damage_boost_source_anchor_offset)
	var to_global := target_anchor_node.to_global(damage_boost_target_anchor_offset)
	var from_local := damage_boost_beam.to_local(from_global)
	var to_local := damage_boost_beam.to_local(to_global)
	damage_boost_beam.set_endpoints(from_local, to_local)


# ================================================================
# Target management
# ================================================================

func _build_config_lookup() -> void:
	config_lookup.clear()
	for config:DamageBoostTargetConfig in damage_boost_target_configs:
		if config and config.plant_type != 0:
			config_lookup[int(config.plant_type)] = config


func _get_damage_boost_config_for(plant_type:int) -> DamageBoostTargetConfig:
	return config_lookup.get(plant_type, null)


func _update_damage_boost_target():
	var new_target := _get_damage_boost_target()
	if new_target == damage_boost_target:
		return

	_clear_damage_boost_target()
	damage_boost_target = new_target
	if is_instance_valid(damage_boost_target):
		target_anchor_node = _get_target_anchor_node(damage_boost_target)
		damage_boost_target.add_attack_damage_multiplier(self, damage_boost_multiplier)
		_create_damage_boost_glow_sprites(damage_boost_target)


func _clear_damage_boost_target():
	_clear_damage_boost_glow()
	if is_instance_valid(damage_boost_target):
		damage_boost_target.remove_attack_damage_multiplier(self)
	damage_boost_target = null
	target_anchor_node = null
	if is_instance_valid(damage_boost_beam):
		damage_boost_beam.hide_beam()


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

	# 从近到远扫描前方格子（1, 2, ..., max_range），优先连接最近的
	for offset in range(1, damage_boost_target_cell_max_range + 1):
		var target_index := current_index + offset
		if target_index >= lane_cells.size():
			break

		var target_cell:PlantCell = lane_cells[target_index]
		var target_plant:Plant000Base = target_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm]
		if not is_instance_valid(target_plant):
			continue
		if not damage_boost_target_plant_types.has(target_plant.plant_type):
			continue
		return target_plant

	return null


func _get_target_anchor_node(target_plant:Plant000Base) -> Node2D:
	# 1) Per-type custom anchor from config
	var config := _get_damage_boost_config_for(target_plant.plant_type)
	if config and not config.custom_target_anchor_path.is_empty():
		var node := target_plant.get_node_or_null(NodePath(config.custom_target_anchor_path))
		if node is Node2D:
			return node

	# 2) Default search through standard anchor paths
	for target_anchor_path:NodePath in TARGET_ANCHOR_PATHS:
		var node := target_plant.get_node_or_null(target_anchor_path)
		if node is Node2D:
			return node
	return target_plant.body


# ================================================================
# Glow overlay on target
# ================================================================

func _create_damage_boost_glow_sprites(target_plant:Plant000Base):
	var config := _get_damage_boost_config_for(target_plant.plant_type)

	# Route A: config provides exact sprite paths — use them directly
	if config and not config.custom_glow_sprite_paths.is_empty():
		for sprite_path_str:String in config.custom_glow_sprite_paths:
			if sprite_path_str.is_empty():
				continue
			var sprite := target_plant.get_node_or_null(NodePath(sprite_path_str)) as Sprite2D
			if not is_instance_valid(sprite) or _has_damage_boost_glow(sprite):
				continue
			var container := _create_damage_boost_glow_overlay(sprite)
			damage_boost_glow_containers.append(container)
		return

	# Route B: use AttackComponent markers + keyword-based sprite search
	var keywords:Array[String] = ["mouth"]
	if config and not config.glow_sprite_name_keywords.is_empty():
		keywords = config.glow_sprite_name_keywords

	var attack_component := target_plant.get_node_or_null(^"AttackComponent")
	if not attack_component is AttackComponentBulletBase:
		return
	var bullet_attack_component := attack_component as AttackComponentBulletBase

	var glow_sprites:Array[Sprite2D] = _get_damage_boost_glow_sprites_by_keywords(
		target_plant, bullet_attack_component.markers_2d_bullet, keywords
	)
	for marker:Marker2D in bullet_attack_component.markers_2d_bullet:
		if not is_instance_valid(marker):
			continue
		var glow_sprite := _get_closest_glow_sprite(marker.global_position, glow_sprites)
		if not is_instance_valid(glow_sprite) or _has_damage_boost_glow(glow_sprite):
			continue
		var container := _create_damage_boost_glow_overlay(glow_sprite)
		damage_boost_glow_containers.append(container)


func _update_damage_boost_glow():
	for container:Node2D in damage_boost_glow_containers:
		if not is_instance_valid(container):
			continue
		var glow_sprite := container.get_parent() as Sprite2D
		var overlay := container.get_node_or_null(^"BlueOverlay") as Sprite2D
		if not is_instance_valid(glow_sprite) or not is_instance_valid(overlay):
			continue
		_sync_glow_overlay_sprite(overlay, glow_sprite)


func _clear_damage_boost_glow():
	for container:Node2D in damage_boost_glow_containers:
		if is_instance_valid(container):
			container.queue_free()
	damage_boost_glow_containers.clear()


func _create_damage_boost_glow_overlay(glow_sprite:Sprite2D) -> Node2D:
	var container := Node2D.new()
	container.name = "MercyDamageBoostGlow"
	container.z_index = 1
	container.z_as_relative = true
	glow_sprite.add_child(container)

	var overlay := Sprite2D.new()
	overlay.name = "BlueOverlay"
	overlay.material = _create_glow_overlay_material()
	container.add_child(overlay)
	_sync_glow_overlay_sprite(overlay, glow_sprite)
	return container


func _get_damage_boost_glow_sprites_by_keywords(
	target_plant:Plant000Base, markers:Array[Marker2D], keywords:Array[String]
) -> Array[Sprite2D]:
	var all_glow_sprites:Array[Sprite2D] = []
	_collect_damage_boost_glow_sprites(target_plant, all_glow_sprites, keywords)
	if markers.is_empty():
		return all_glow_sprites

	var selected_glow_sprites:Array[Sprite2D] = []
	for marker:Marker2D in markers:
		if not is_instance_valid(marker):
			continue
		var glow_sprite := _get_closest_glow_sprite(marker.global_position, all_glow_sprites)
		if is_instance_valid(glow_sprite) and not selected_glow_sprites.has(glow_sprite):
			selected_glow_sprites.append(glow_sprite)
	return selected_glow_sprites


func _collect_damage_boost_glow_sprites(node:Node, glow_sprites:Array[Sprite2D], keywords:Array[String]) -> void:
	for child:Node in node.get_children():
		if child is Sprite2D and _is_damage_boost_glow_sprite(child, keywords):
			glow_sprites.append(child)
		_collect_damage_boost_glow_sprites(child, glow_sprites, keywords)


func _is_damage_boost_glow_sprite(node:Node, keywords:Array[String]) -> bool:
	if not node is Sprite2D:
		return false
	var sprite := node as Sprite2D
	if not is_instance_valid(sprite.texture):
		return false
	var node_name := String(sprite.name).to_lower()
	for keyword:String in keywords:
		if node_name.contains(keyword.to_lower()):
			return true
	return false


func _get_closest_glow_sprite(global_pos:Vector2, glow_sprites:Array[Sprite2D]) -> Sprite2D:
	var closest_glow_sprite:Sprite2D
	var closest_distance := INF
	for glow_sprite:Sprite2D in glow_sprites:
		if not is_instance_valid(glow_sprite):
			continue
		var distance := glow_sprite.global_position.distance_to(global_pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_glow_sprite = glow_sprite
	return closest_glow_sprite


func _has_damage_boost_glow(glow_sprite:Sprite2D) -> bool:
	return is_instance_valid(glow_sprite.get_node_or_null(^"MercyDamageBoostGlow"))


func _sync_glow_overlay_sprite(overlay:Sprite2D, glow_sprite:Sprite2D) -> void:
	overlay.texture = glow_sprite.texture
	overlay.centered = glow_sprite.centered
	overlay.offset = glow_sprite.offset
	overlay.flip_h = glow_sprite.flip_h
	overlay.flip_v = glow_sprite.flip_v
	overlay.region_enabled = glow_sprite.region_enabled
	overlay.region_rect = glow_sprite.region_rect
	overlay.hframes = glow_sprite.hframes
	overlay.vframes = glow_sprite.vframes
	overlay.frame = glow_sprite.frame
	overlay.position = Vector2.ZERO
	overlay.rotation = 0.0
	overlay.scale = Vector2.ONE
	overlay.skew = 0.0
	overlay.visible = glow_sprite.visible and is_instance_valid(glow_sprite.texture)


func _create_glow_overlay_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_glow_overlay_shader()
	material.set_shader_parameter("base_color", glow_overlay_base_color)
	material.set_shader_parameter("highlight_color", glow_overlay_highlight_color)
	material.set_shader_parameter("pulse_amount", glow_overlay_pulse_amount)
	material.set_shader_parameter("pulse_speed", glow_overlay_pulse_speed)
	material.set_shader_parameter("flow_speed", glow_overlay_flow_speed)
	return material


func _get_glow_overlay_shader() -> Shader:
	if is_instance_valid(glow_overlay_shader):
		return glow_overlay_shader

	glow_overlay_shader = Shader.new()
	glow_overlay_shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 base_color : source_color = vec4(0.0, 0.35, 0.72, 0.82);
uniform vec4 highlight_color : source_color = vec4(0.2, 0.65, 0.95, 0.88);
uniform float pulse_amount = 0.18;
uniform float pulse_speed = 2.8;
uniform float flow_speed = 1.4;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = tex.a;
	float flow = 0.5 + 0.5 * sin((UV.x * 13.0 + UV.y * 7.0) + TIME * flow_speed * 6.28318);
	float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed);
	vec3 color = mix(base_color.rgb, highlight_color.rgb, flow * 0.45) * pulse;
	float alpha = mask * mix(base_color.a, highlight_color.a, flow);
	COLOR = vec4(color, alpha);
}
"""
	return glow_overlay_shader
