extends Plant000Base
class_name Plant031PumpkinZarya

const GRAVITY_EFFECT_SCRIPT := preload("res://scripts/character/components/pumpkin_zarya_gravity_effect.gd")
const BLACK_HOLE_EFFECT_SCRIPT := preload("res://scripts/fx/plant_effect/plant_effect_pumpkin_zarya_black_hole.gd")
const GRAVITY_TARGET_COLUMN_OFFSET := 2
const GRAVITY_DETECTION_CELL_RADIUS := 1
const BLACK_HOLE_TRAVEL_DURATION := 0.55
const GRAVITY_PULL_DURATION := 0.45
const GRAVITY_CLUSTER_MAX_RADIUS := 18.0
const GRAVITY_CLUSTER_ANGLE_STEP := 2.399963
const READY_GLOW_SPRITE_PATHS := [
	^"Body/BodyCorrect/Pumpkin_back",
	^"Body/BodyCorrect/Pumpkin_front",
	^"Body/BodyCorrect/Pumpkin_front/body",
	^"Body/BodyCorrect/Pumpkin_front/face",
	^"Body/BodyCorrect/Pumpkin_front/hair",
]
const READY_GLOW_AURA_OFFSETS := [
	Vector2(-2.0, 0.0),
	Vector2(2.0, 0.0),
	Vector2(0.0, -2.0),
	Vector2(0.0, 2.0),
	Vector2(-1.5, -1.5),
	Vector2(1.5, -1.5),
	Vector2(-1.5, 1.5),
	Vector2(1.5, 1.5),
]

@export_group("引力吸附")
## 当前血量小于等于此值时，允许点击本体触发一次引力吸附。
@export_range(0, 100000, 1) var gravity_trigger_hp_threshold:int = 1000
## 僵尸全部吸到目标位置后，稳定黑洞与聚集禁行共同维持的时间。
@export_range(0.0, 60.0, 0.1, "suffix:s") var gravity_hold_duration:float = 3.0

@export_group("叠种显示")
@export var covered_front_child_path: NodePath = ^"Body/BodyCorrect/Pumpkin_front/hair"
@export_range(0.0, 100.0, 1.0) var covered_front_child_alpha_percent: float = 85.0

@onready var hp_stage_change_component: HpStageChangeComponent = $HpStageChangeComponent
@onready var pumpkin_back: Sprite2D = $Body/BodyCorrect/Pumpkin_back
@onready var area_2d_mouse: Area2D = $Body/Area2DMouse

var _gravity_activated := false
var _gravity_captured_zombie_ids:Dictionary = {}
var _gravity_cluster_count := 0
var _ready_glow_sprites:Array[Sprite2D] = []
var _ready_glow_shader:Shader
var _ready_glow_rim_material:ShaderMaterial
var _ready_glow_aura_material:ShaderMaterial
var _is_ready_glow_active := false

func ready_norm():
	super()
	pumpkin_back.z_index -= 1
	area_2d_mouse.visible = true
	_update_covered_front_child_alpha()
	_create_ready_glow_layer()
	_update_ready_glow_state()


func ready_norm_signal_connect():
	super()
	## 血量状态变化组件
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)
	hp_component.signal_hp_loss.connect(_on_hp_loss_update_ready_glow)
	if is_instance_valid(plant_cell):
		plant_cell.signal_plant_create.connect(_on_plant_cell_plant_create)
		plant_cell.signal_plant_free.connect(_on_plant_cell_plant_free)


func _on_plant_cell_plant_create(_plant_cell:PlantCell, _plant_type:CharacterRegistry.PlantType):
	_update_covered_front_child_alpha()


func _on_plant_cell_plant_free(_plant_cell:PlantCell, _plant_type:CharacterRegistry.PlantType):
	call_deferred("_update_covered_front_child_alpha")


func _update_covered_front_child_alpha():
	if plant_type != CharacterRegistry.PlantType.P031PumpkinZarya:
		return

	var covered_front_child := get_node_or_null(covered_front_child_path) as CanvasItem
	if not is_instance_valid(covered_front_child):
		return

	var has_norm_plant := (
		is_instance_valid(plant_cell)
		and is_instance_valid(plant_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm])
	)
	var target_alpha := 1.0
	if has_norm_plant:
		target_alpha = clampf(covered_front_child_alpha_percent / 100.0, 0.0, 1.0)

	var new_self_modulate := covered_front_child.self_modulate
	new_self_modulate.a = target_alpha
	covered_front_child.self_modulate = new_self_modulate


func _can_activate_gravity() -> bool:
	return (
		not _gravity_activated
		and not is_death
		and hp_component.curr_hp <= gravity_trigger_hp_threshold
		and is_instance_valid(Global.main_game)
		and is_instance_valid(Global.main_game.zombie_manager)
		and is_instance_valid(plant_cell)
	)


func _on_hp_loss_update_ready_glow(_curr_hp:int, _is_drop:bool) -> void:
	_update_ready_glow_state()


func _update_ready_glow_state() -> void:
	var should_glow := _can_activate_gravity()
	if should_glow == _is_ready_glow_active:
		return
	_is_ready_glow_active = should_glow
	for glow_sprite:Sprite2D in _ready_glow_sprites:
		if is_instance_valid(glow_sprite):
			glow_sprite.visible = should_glow
	set_process(should_glow)
	if should_glow:
		_sync_ready_glow_layer()


func _process(_delta:float) -> void:
	if _is_ready_glow_active:
		_sync_ready_glow_layer()


func _create_ready_glow_layer() -> void:
	_ready_glow_rim_material = _create_ready_glow_material(0.72, true)
	_ready_glow_aura_material = _create_ready_glow_material(0.16, false)
	for sprite_path:NodePath in READY_GLOW_SPRITE_PATHS:
		var source_sprite := get_node_or_null(sprite_path) as Sprite2D
		if not is_instance_valid(source_sprite):
			continue
		for aura_offset:Vector2 in READY_GLOW_AURA_OFFSETS:
			var aura := Sprite2D.new()
			aura.name = "GravityReadyAura"
			aura.material = _ready_glow_aura_material
			aura.show_behind_parent = true
			aura.visible = false
			aura.set_meta(&"ready_glow_offset", aura_offset)
			source_sprite.add_child(aura)
			_ready_glow_sprites.append(aura)
		var rim := Sprite2D.new()
		rim.name = "GravityReadyEnergyRim"
		rim.z_index = 1
		rim.material = _ready_glow_rim_material
		rim.visible = false
		rim.set_meta(&"ready_glow_offset", Vector2.ZERO)
		source_sprite.add_child(rim)
		_ready_glow_sprites.append(rim)


func _sync_ready_glow_layer() -> void:
	for overlay:Sprite2D in _ready_glow_sprites:
		if not is_instance_valid(overlay):
			continue
		var source_sprite := overlay.get_parent() as Sprite2D
		if not is_instance_valid(source_sprite):
			continue
		_sync_ready_glow_sprite(overlay, source_sprite)


func _sync_ready_glow_sprite(overlay:Sprite2D, source_sprite:Sprite2D) -> void:
	overlay.texture = source_sprite.texture
	overlay.centered = source_sprite.centered
	overlay.offset = source_sprite.offset
	overlay.flip_h = source_sprite.flip_h
	overlay.flip_v = source_sprite.flip_v
	overlay.region_enabled = source_sprite.region_enabled
	overlay.region_rect = source_sprite.region_rect
	overlay.hframes = source_sprite.hframes
	overlay.vframes = source_sprite.vframes
	overlay.frame = source_sprite.frame
	overlay.position = overlay.get_meta(&"ready_glow_offset", Vector2.ZERO)
	overlay.visible = (
		_is_ready_glow_active
		and source_sprite.visible
		and is_instance_valid(source_sprite.texture)
	)


func _create_ready_glow_material(intensity:float, edge_only:bool) -> ShaderMaterial:
	var glow_material := ShaderMaterial.new()
	glow_material.shader = _get_ready_glow_shader()
	glow_material.set_shader_parameter(&"intensity", intensity)
	glow_material.set_shader_parameter(&"edge_only", edge_only)
	return glow_material


func _get_ready_glow_shader() -> Shader:
	if is_instance_valid(_ready_glow_shader):
		return _ready_glow_shader
	_ready_glow_shader = Shader.new()
	_ready_glow_shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 energy_blue : source_color = vec4(0.02, 0.32, 1.0, 1.0);
uniform vec4 energy_violet : source_color = vec4(0.68, 0.12, 1.0, 1.0);
uniform vec4 energy_white : source_color = vec4(0.78, 0.94, 1.0, 1.0);
uniform float intensity = 0.72;
uniform bool edge_only = true;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * 1.35;
	float neighbour_alpha = min(
		min(texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, pixel.y)).a, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a)
	);
	float inner_rim = tex.a * (1.0 - neighbour_alpha);
	float diagonal_flow = 0.5 + 0.5 * sin((UV.x * 15.0 - UV.y * 10.0) + TIME * 4.8);
	float fine_flow = 0.5 + 0.5 * sin((UV.x * 29.0 + UV.y * 21.0) - TIME * 7.2);
	float pulse = 0.88 + 0.12 * sin(TIME * 4.2);
	float white_energy = smoothstep(0.67, 0.96, diagonal_flow * 0.74 + fine_flow * 0.26);
	vec3 blue_violet = mix(energy_blue.rgb, energy_violet.rgb, diagonal_flow * 0.42);
	vec3 energy_color = mix(blue_violet, energy_white.rgb, white_energy);
	float mask = edge_only ? inner_rim : tex.a;
	float energy_alpha = mask * intensity * (0.78 + white_energy * 0.48) * pulse;
	COLOR = vec4(energy_color, energy_alpha);
}
"""
	return _ready_glow_shader


func _activate_gravity() -> void:
	if not _can_activate_gravity():
		return
	_gravity_activated = true
	_update_ready_glow_state()
	body.body_light_and_dark_end()
	var target_cell:PlantCell = _get_gravity_center_cell()
	if not is_instance_valid(target_cell):
		return
	var target_center_x:float = target_cell.global_position.x + target_cell.size.x * 0.5
	var target_row_y:float = Global.main_game.zombie_manager.all_zombie_rows[lane].zombie_create_position.global_position.y
	_create_black_hole_visual(Vector2(target_center_x, target_row_y - 8.0))
	_gravity_captured_zombie_ids.clear()
	_gravity_cluster_count = 0
	_monitor_black_hole_targets(target_cell.row_col.y, target_center_x)


func _monitor_black_hole_targets(target_column:int, target_center_x:float) -> void:
	## 飞行阶段结束后，黑洞从生效到消失的整个窗口都持续捕获新进入九宫格的僵尸。
	await get_tree().create_timer(BLACK_HOLE_TRAVEL_DURATION, false).timeout
	var active_duration:float = GRAVITY_PULL_DURATION + gravity_hold_duration
	var active_end_msec:int = Time.get_ticks_msec() + roundi(active_duration * 1000.0)
	while is_inside_tree():
		var remaining_duration:float = maxf(
			0.0,
			float(active_end_msec - Time.get_ticks_msec()) / 1000.0
		)
		if remaining_duration <= 0.0:
			break
		for zombie:Zombie000Base in _get_gravity_targets(target_column):
			_capture_gravity_target(zombie, target_center_x, remaining_duration)
		await get_tree().process_frame


func _capture_gravity_target(
	zombie:Zombie000Base,
	target_center_x:float,
	remaining_duration:float
) -> void:
	if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
		return
	var zombie_id:int = zombie.get_instance_id()
	if _gravity_captured_zombie_ids.has(zombie_id):
		return
	_gravity_captured_zombie_ids[zombie_id] = true
	var cluster_offset:Vector2 = _get_cluster_offset(_gravity_cluster_count)
	_gravity_cluster_count += 1
	var pull_duration:float = minf(GRAVITY_PULL_DURATION, remaining_duration)
	var hold_duration:float = maxf(0.0, remaining_duration - pull_duration)
	var gravity_effect:PumpkinZaryaGravityEffect = GRAVITY_EFFECT_SCRIPT.new()
	gravity_effect.name = "PumpkinZaryaGravityEffect"
	zombie.add_child(gravity_effect)
	gravity_effect.start(
		zombie,
		lane,
		target_center_x + cluster_offset.x,
		cluster_offset.y,
		0.0,
		pull_duration,
		hold_duration
	)


func _create_black_hole_visual(target_position:Vector2) -> void:
	var effect_parent:Node = Global.main_game.get_node_or_null(^"Bombs")
	if not is_instance_valid(effect_parent):
		effect_parent = Global.main_game
	var black_hole_effect:Node2D = BLACK_HOLE_EFFECT_SCRIPT.new()
	black_hole_effect.name = "PumpkinZaryaBlackHoleEffect"
	effect_parent.add_child(black_hole_effect)
	black_hole_effect.play(
		global_position + Vector2(12.0, -42.0),
		target_position,
		BLACK_HOLE_TRAVEL_DURATION,
		GRAVITY_PULL_DURATION,
		gravity_hold_duration
	)


func _get_gravity_center_cell() -> PlantCell:
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_cells.size() or all_cells[row_col.x].is_empty():
		return null
	var lane_cells:Array = all_cells[row_col.x]
	var target_column:int = mini(row_col.y + GRAVITY_TARGET_COLUMN_OFFSET, lane_cells.size() - 1)
	return lane_cells[target_column]


func _get_gravity_targets(target_column:int) -> Array[Zombie000Base]:
	var targets:Array[Zombie000Base] = []
	var all_zombies_2d:Array = Global.main_game.zombie_manager.all_zombies_2d
	var first_lane:int = maxi(0, row_col.x - GRAVITY_DETECTION_CELL_RADIUS)
	var last_lane:int = mini(all_zombies_2d.size() - 1, row_col.x + GRAVITY_DETECTION_CELL_RADIUS)
	var source_x_range:Vector2 = _get_cell_x_range(target_column, GRAVITY_DETECTION_CELL_RADIUS)
	for target_lane:int in range(first_lane, last_lane + 1):
		for zombie:Zombie000Base in all_zombies_2d[target_lane].duplicate():
			if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
				continue
			var zombie_ground_x:float = zombie.shadow.global_position.x
			if zombie_ground_x >= source_x_range.x and zombie_ground_x <= source_x_range.y:
				targets.append(zombie)
	return targets


func _get_cluster_offset(target_index:int) -> Vector2:
	if target_index == 0:
		return Vector2.ZERO
	var angle:float = float(target_index - 1) * GRAVITY_CLUSTER_ANGLE_STEP
	var radius:float = minf(GRAVITY_CLUSTER_MAX_RADIUS, 6.0 + sqrt(float(target_index - 1)) * 3.0)
	return Vector2(cos(angle) * radius, sin(angle) * radius * 0.45)


func _get_cell_x_range(center_column:int, cell_radius:int) -> Vector2:
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	var lane_cells:Array = all_cells[row_col.x]
	var first_column:int = maxi(0, center_column - cell_radius)
	var last_column:int = mini(lane_cells.size() - 1, center_column + cell_radius)
	var first_cell:PlantCell = lane_cells[first_column]
	var last_cell:PlantCell = lane_cells[last_column]
	var first_start:float = first_cell.global_position.x
	var first_end:float = first_start + first_cell.size.x
	var last_start:float = last_cell.global_position.x
	var last_end:float = last_start + last_cell.size.x
	return Vector2(
		minf(minf(first_start, first_end), minf(last_start, last_end)),
		maxf(maxf(first_start, first_end), maxf(last_start, last_end))
	)


func _on_area_2d_mouse_entered() -> void:
	if _can_activate_gravity():
		body.body_light_and_dark()


func _on_area_2d_mouse_exited() -> void:
	body.body_light_and_dark_end()


@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport:Node, event:InputEvent, shape_idx:int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_activate_gravity()
