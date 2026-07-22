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

func ready_norm():
	super()
	pumpkin_back.z_index -= 1
	area_2d_mouse.visible = true
	_update_covered_front_child_alpha()


func ready_norm_signal_connect():
	super()
	## 血量状态变化组件
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)
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


func _activate_gravity() -> void:
	if not _can_activate_gravity():
		return
	_gravity_activated = true
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
