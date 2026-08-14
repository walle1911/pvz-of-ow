extends Plant037Garlic
class_name Plant037GarlicMauga

const CHAIN_OWNERS_META := &"garlic_mauga_chain_owners"
const CHAIN_EFFECT_SCENE := preload("res://scripts/fx/plant_effect/plant_effect_garlic_mauga_chain.gd")
const CAGE_EFFECT_SCENE := preload("res://scripts/fx/plant_effect/plant_effect_garlic_mauga_cage.gd")
const CAGE_PROCESS_PRIORITY := 100
const STOMP_BODY_Z_BOOST := 50
const FLATTENED_BODY_LIFETIME := 2.0

@export_range(0.1, 60.0, 0.1, "suffix:s") var chain_skill_duration := 6.0
@export_range(0, 10000, 1, "suffix:HP") var chain_health_cost := 200
@export_group("笼中斗踩踏")
@export_range(1.0, 80.0, 1.0, "suffix:px") var chain_lunge_distance := 25.0
@export_range(0.01, 1.0, 0.01, "suffix:s") var chain_lunge_duration := 0.10
@export_range(0.05, 2.0, 0.05, "suffix:s") var chain_jump_duration := 0.45
@export_range(1.0, 240.0, 1.0, "suffix:px") var chain_jump_height := 34.0

@onready var area_2d_mouse:Area2D = $Body/Area2DMouse

var _chain_skill_active := false
var _chain_intro_active := false
var _chain_skill_elapsed := 0.0
var _pending_skill_cost_death := false
var _intro_health_cost_applied := 0
var _chained_zombies:Dictionary[int, Zombie000Base] = {}
var _chain_visuals:Dictionary[int, Node2D] = {}
var _cage_visual:Node2D
var _chain_area_x_ranges:Dictionary[int, Vector2] = {}
var _chain_ground_bounds := Rect2()
var _boundary_enforcement_deferred := false
var _chain_intro_tween:Tween
var _stomp_body_layer_raised := false

func ready_norm() -> void:
	super()
	## 僵尸移动组件使用 _process；笼子稍后执行，保证本帧任何越界位移都会被截回边缘。
	process_priority = CAGE_PROCESS_PRIORITY
	area_2d_mouse.visible = true
	_update_ready_glow()

func ready_norm_signal_connect():
	super()
	signal_character_death.connect(_on_character_death_cleanup)

func _process(delta:float) -> void:
	if not _chain_skill_active:
		return
	var active_delta:float = minf(delta, chain_skill_duration - _chain_skill_elapsed)
	_chain_skill_elapsed += active_delta
	if is_death or not is_inside_tree():
		return
	## 和原版笼中斗一致：技能展开后才走进范围的敌人也会被锁链捕获。
	_chain_new_zombies_in_area()
	for target_id:int in _chained_zombies.keys().duplicate():
		var zombie:Zombie000Base = _chained_zombies.get(target_id)
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			_release_chain_target(target_id)
		else:
			_update_chain_target_leash(target_id, zombie)
	_queue_deferred_boundary_enforcement()
	if _chain_skill_elapsed >= chain_skill_duration:
		_finish_chain_skill()

func _can_activate_chain_skill() -> bool:
	return (
		not _chain_skill_active
		and not _chain_intro_active
		and not is_death
		and hp_component.curr_hp > 0
		and is_instance_valid(Global.main_game)
		and is_instance_valid(plant_cell)
		and is_instance_valid(_get_forward_plant_cell())
	)

func _activate_chain_skill(
	candidate_targets:Array[Zombie000Base] = []
) -> void:
	if not _can_activate_chain_skill():
		return
	if candidate_targets.is_empty():
		candidate_targets = _get_zombies_in_x_ranges(_get_current_cage_x_ranges())
	var stomp_candidates:Array[Zombie000Base] = candidate_targets.duplicate()
	var target_cell:PlantCell = _get_forward_plant_cell()
	if not is_instance_valid(target_cell):
		return
	var landing_global_position:Vector2 = (
		target_cell.plant_container_node[_get_mauga_plant_place()] as CanvasItem
	).global_position
	var landing_x_range:Vector2 = _get_plant_cell_world_x_range(target_cell)
	if not _reserve_forward_plant_cell(target_cell):
		return
	_chain_intro_active = true
	_intro_health_cost_applied = 0
	_pending_skill_cost_death = hp_component.curr_hp - chain_health_cost <= hp_component.death_hp
	if _pending_skill_cost_death:
		hp_component.set_death_hp(-1)
	hp_component.add_damage_immunity(self)
	body.body_light_and_dark_end()
	_play_chain_stomp_intro(
		target_cell, landing_global_position, landing_x_range, stomp_candidates
	)

func _begin_chain_skill_after_stomp() -> void:
	if is_death or not is_inside_tree():
		_cancel_chain_intro()
		return
	_chain_intro_active = false
	_chain_skill_active = true
	_chain_skill_elapsed = 0.0
	_apply_intro_health_cost_progress(1.0)
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		_finish_chain_skill()
		return
	_chain_area_x_ranges = _get_current_cage_x_ranges()
	_chain_ground_bounds = _get_current_cage_ground_bounds()
	_create_cage_visual()
	_chain_new_zombies_in_area()
func _get_forward_plant_cell() -> PlantCell:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return null
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_cells.size():
		return null
	var place:= _get_mauga_plant_place()
	var current_center_x:float = _get_plant_cell_world_center_x(plant_cell)
	var nearest_cell:PlantCell
	var nearest_x:= INF
	for candidate:PlantCell in all_cells[row_col.x]:
		var candidate_x:float = _get_plant_cell_world_center_x(candidate)
		if candidate_x <= current_center_x + 0.01 or candidate_x >= nearest_x:
			continue
		nearest_cell = candidate
		nearest_x = candidate_x
	if not is_instance_valid(nearest_cell):
		return null
	if is_instance_valid(nearest_cell.plant_in_cell.get(place)):
		return null
	return nearest_cell

func _get_mauga_plant_place() -> CharacterRegistry.PlacePlantInCell:
	var condition:ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	return condition.place_plant_in_cell if is_instance_valid(condition) \
		else CharacterRegistry.PlacePlantInCell.Norm

func _get_plant_cell_world_center_x(target_cell:PlantCell) -> float:
	if not is_instance_valid(target_cell):
		return 0.0
	var place:= _get_mauga_plant_place()
	var container:= target_cell.plant_container_node.get(place) as CanvasItem
	return container.global_position.x if is_instance_valid(container) \
		else target_cell.get_global_rect().get_center().x

func _get_plant_cell_world_x_range(target_cell:PlantCell) -> Vector2:
	## PlantCell 位于容器布局中，换格 reparent 时 Control 矩形可能被重新排版；
	## 种植容器的世界坐标才是植物与僵尸实际对齐的物理格中心。
	var center_x:float = _get_plant_cell_world_center_x(target_cell)
	var half_width:float = maxf(target_cell.size.x * 0.5, 1.0)
	if is_instance_valid(Global.main_game):
		var lane_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[target_cell.row_col.x]
		var nearest_spacing:= INF
		for candidate:PlantCell in lane_cells:
			if candidate == target_cell:
				continue
			var spacing:float = absf(_get_plant_cell_world_center_x(candidate) - center_x)
			if spacing > 0.01:
				nearest_spacing = minf(nearest_spacing, spacing)
		if nearest_spacing < INF:
			half_width = nearest_spacing * 0.5
	return Vector2(center_x - half_width, center_x + half_width)

func _play_chain_stomp_intro(
	target_cell:PlantCell,
	landing_global_position:Vector2,
	landing_x_range:Vector2,
	stomp_candidates:Array[Zombie000Base]
) -> void:
	var lunge_start:Vector2 = global_position
	var lunge_end:= lunge_start + Vector2.RIGHT * chain_lunge_distance
	_chain_intro_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_chain_intro_tween.tween_property(self, ^"global_position", lunge_end, chain_lunge_duration)
	_chain_intro_tween.parallel().tween_method(
		_apply_intro_health_cost_progress, 0.0,
		chain_lunge_duration / (chain_lunge_duration + chain_jump_duration),
		chain_lunge_duration
	)
	await _chain_intro_tween.finished
	if not _chain_intro_active or is_death or not is_instance_valid(target_cell):
		return
	## 完整走完 25px 小前摇后才起跳；最终落点仍是原位置前一格。
	var jump_start:Vector2 = lunge_end
	global_position = jump_start
	_raise_stomp_body_layer()
	var jump_end:Vector2 = landing_global_position
	_chain_intro_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_chain_intro_tween.tween_method(
		func(progress:float):
			var arc_offset:= Vector2.UP * chain_jump_height * 4.0 * progress * (1.0 - progress)
			global_position = jump_start.lerp(jump_end, progress) + arc_offset,
		0.0,
		1.0,
		chain_jump_duration
	)
	_chain_intro_tween.parallel().tween_method(
		_apply_intro_health_cost_progress,
		chain_lunge_duration / (chain_lunge_duration + chain_jump_duration),
		1.0,
		chain_jump_duration
	)
	await _chain_intro_tween.finished
	if not _chain_intro_active or is_death:
		return
	global_position = landing_global_position
	SoundManager.play_character_SFX(&"gargantuar_thump")
	_stomp_zombies_in_cell(target_cell, landing_x_range, stomp_candidates)
	_restore_stomp_body_layer_after_flattened_bodies()
	_begin_chain_skill_after_stomp()

func _raise_stomp_body_layer() -> void:
	if _stomp_body_layer_raised or not is_instance_valid(body):
		return
	body.z_index += STOMP_BODY_Z_BOOST
	_stomp_body_layer_raised = true

func _restore_stomp_body_layer_after_flattened_bodies() -> void:
	await get_tree().create_timer(FLATTENED_BODY_LIFETIME, false).timeout
	_restore_stomp_body_layer()

func _restore_stomp_body_layer() -> void:
	if not _stomp_body_layer_raised:
		return
	if is_instance_valid(body):
		body.z_index -= STOMP_BODY_Z_BOOST
	_stomp_body_layer_raised = false

func _apply_intro_health_cost_progress(progress:float) -> void:
	var expected_cost:int = int(floor(float(chain_health_cost) * clampf(progress, 0.0, 1.0) + 0.0001))
	var cost_now:int = expected_cost - _intro_health_cost_applied
	if cost_now <= 0:
		return
	_intro_health_cost_applied += cost_now
	hp_component.curr_hp -= cost_now
	hp_component.signal_hp_loss.emit(hp_component.curr_hp, true)

func _reserve_forward_plant_cell(target_cell:PlantCell) -> bool:
	if not is_instance_valid(target_cell) or not is_instance_valid(plant_cell):
		return false
	var place:= _get_mauga_plant_place()
	if is_instance_valid(target_cell.plant_in_cell.get(place)):
		return false
	var old_cell:PlantCell = plant_cell
	var old_free_callback:= old_cell.one_plant_free.bind(self)
	if signal_character_death.is_connected(old_free_callback):
		signal_character_death.disconnect(old_free_callback)
	if old_cell.plant_in_cell.get(place) == self:
		old_cell.plant_in_cell[place] = null
	target_cell.plant_in_cell[place] = self
	plant_cell = target_cell
	row_col = target_cell.row_col
	lane = target_cell.row_col.x
	var target_parent:Node = target_cell.plant_container_node[place]
	reparent(target_parent, true)
	var new_free_callback:= target_cell.one_plant_free.bind(self)
	if not signal_character_death.is_connected(new_free_callback):
		signal_character_death.connect(new_free_callback)
	GlobalUtils.update_plant_cell_slope_y_array(plant_cell, node2d_detect_in_slope)
	return true

func _stomp_zombies_in_cell(
	target_cell:PlantCell,
	landing_x_range:Vector2,
	stomp_candidates:Array[Zombie000Base]
) -> void:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(target_cell):
		return
	var lane_zombies:Array = Global.main_game.zombie_manager.all_zombies_2d[target_cell.row_col.x].duplicate()
	for candidate:Zombie000Base in stomp_candidates:
		if is_instance_valid(candidate) and candidate not in lane_zombies:
			lane_zombies.append(candidate)
	for zombie:Zombie000Base in lane_zombies:
		if (
			is_instance_valid(zombie)
			and zombie.lane == target_cell.row_col.x
			and zombie.shadow.global_position.x >= landing_x_range.x
			and zombie.shadow.global_position.x <= landing_x_range.y
		):
			## 踩踏是处决，并复用窝瓜压扁身体后短暂保留残影的视觉流程。
			zombie.be_squash(0, true)

func _cancel_chain_intro() -> void:
	_chain_intro_active = false
	if is_instance_valid(_chain_intro_tween):
		_chain_intro_tween.kill()
	_chain_intro_tween = null
	_restore_stomp_body_layer()
	hp_component.remove_damage_immunity(self)
	_update_ready_glow()

## 以跳跃落地后的毛加为中心取 3 列 × 3 行。
## 因此相对起跳位置，横向范围正好是原格、前一格、前两格。
func _get_current_cage_x_ranges() -> Dictionary[int, Vector2]:
	var result:Dictionary[int, Vector2] = {}
	var selected_column_indices:PackedInt32Array = _get_cage_column_indices()
	if selected_column_indices.is_empty():
		return result
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	var first_lane:int = maxi(0, row_col.x - 1)
	var last_lane:int = mini(all_cells.size() - 1, row_col.x + 1)
	for lane_index:int in range(first_lane, last_lane + 1):
		var lane_cells:Array = all_cells[lane_index]
		var range_min_x:float = INF
		var range_max_x:float = -INF
		for column_index:int in selected_column_indices:
			if column_index < 0 or column_index >= lane_cells.size():
				continue
			var cell_rect:Rect2 = (lane_cells[column_index] as PlantCell).get_global_rect()
			range_min_x = minf(range_min_x, cell_rect.position.x)
			range_max_x = maxf(range_max_x, cell_rect.end.x)
		if range_min_x <= range_max_x:
			var lane_y:float = Global.main_game.zombie_manager \
				.all_zombie_rows[lane_index].zombie_create_position.global_position.y
			var circle_x_range:Vector2 = _get_cage_hard_x_range_at_y(
				_get_current_cage_ground_bounds(),
				lane_y
			)
			result[lane_index] = Vector2(
				maxf(range_min_x, circle_x_range.x),
				minf(range_max_x, circle_x_range.y)
			)
	return result

func _get_cage_column_indices() -> PackedInt32Array:
	var result:= PackedInt32Array()
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return result
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_cells.size():
		return result
	var lane_cells:Array = all_cells[row_col.x]
	var current_index:int = lane_cells.find(plant_cell)
	if current_index < 0:
		return result
	var selected_by_x:Array[Dictionary] = []
	for candidate_index:int in lane_cells.size():
		var candidate_cell:PlantCell = lane_cells[candidate_index]
		selected_by_x.append({
			"index": candidate_index,
			"center_x": _get_plant_cell_world_center_x(candidate_cell),
		})
	selected_by_x.sort_custom(func(a:Dictionary, b:Dictionary) -> bool:
		return float(a["center_x"]) < float(b["center_x"])
	)
	var sorted_current_index:int = -1
	for sorted_index:int in selected_by_x.size():
		if int(selected_by_x[sorted_index]["index"]) == current_index:
			sorted_current_index = sorted_index
			break
	if sorted_current_index < 0:
		return result
	var first_index:int = clampi(sorted_current_index - 1, 0, maxi(selected_by_x.size() - 3, 0))
	for selected:Dictionary in selected_by_x.slice(
		first_index,
		mini(first_index + 3, selected_by_x.size())
	):
		result.append(int(selected["index"]))
	return result

func _get_current_cage_ground_bounds() -> Rect2:
	var selected_column_indices:PackedInt32Array = _get_cage_column_indices()
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	var first_lane:int = maxi(0, row_col.x - 1)
	var last_lane:int = mini(all_cells.size() - 1, row_col.x + 1)
	var result:= Rect2()
	var has_bounds := false
	for lane_index:int in range(first_lane, last_lane + 1):
		var lane_cells:Array = all_cells[lane_index]
		for column_index:int in selected_column_indices:
			if column_index < 0 or column_index >= lane_cells.size():
				continue
			var cell_rect:Rect2 = (lane_cells[column_index] as PlantCell).get_global_rect()
			result = result.merge(cell_rect) if has_bounds else cell_rect
			has_bounds = true
	if has_bounds:
		## 纵深必须按僵尸实际脚线，而不是 PlantCell 控件矩形；后者的视觉中心偏上，
		## 会把底圈拉成竖蛋形，并让最下路脚点挤在尖端。
		var first_ground_y:float = Global.main_game.zombie_manager \
			.all_zombie_rows[first_lane].zombie_create_position.global_position.y
		var last_ground_y:float = Global.main_game.zombie_manager \
			.all_zombie_rows[last_lane].zombie_create_position.global_position.y
		var ground_margin:float = maxf(18.0, plant_cell.size.y * 0.25)
		var top_y:float = minf(first_ground_y, last_ground_y) - ground_margin
		var bottom_y:float = maxf(first_ground_y, last_ground_y) + ground_margin
		result.position.y = top_y
		result.size.y = bottom_y - top_y
	return result

func _get_cage_hard_x_range_at_y(ground_bounds:Rect2, world_y:float) -> Vector2:
	## 与视觉底圈使用完全相同的椭圆方程；这条曲线既是捕获范围，也是不可穿越的硬墙。
	var center:Vector2 = ground_bounds.get_center()
	var radius_x:float = maxf(ground_bounds.size.x * 0.5, 0.001)
	var radius_y:float = maxf(ground_bounds.size.y * 0.5, 0.001)
	var normalized_y:float = clampf((world_y - center.y) / radius_y, -1.0, 1.0)
	var half_width:float = radius_x * sqrt(maxf(0.0, 1.0 - normalized_y * normalized_y))
	return Vector2(center.x - half_width, center.x + half_width)

func _finish_chain_skill() -> void:
	if not _chain_skill_active:
		return
	_chain_skill_active = false
	_restore_stomp_body_layer()
	_release_all_chains()
	_remove_cage_visual()
	hp_component.remove_damage_immunity(self)
	if _pending_skill_cost_death:
		_pending_skill_cost_death = false
		hp_component.set_death_hp(0)
		## 技能代价致死后即使期间收到治疗，技能结束仍按规则直接死亡。
		hp_component.curr_hp = 0
		return
	_update_ready_glow()

func _update_ready_glow() -> void:
	if _can_activate_chain_skill():
		body.body_light_and_dark()
	else:
		body.body_light_and_dark_end()

func _on_character_death_cleanup() -> void:
	_chain_skill_active = false
	_chain_intro_active = false
	if is_instance_valid(_chain_intro_tween):
		_chain_intro_tween.kill()
	_chain_intro_tween = null
	_restore_stomp_body_layer()
	hp_component.remove_damage_immunity(self)
	body.body_light_and_dark_end()
	_release_all_chains()
	_remove_cage_visual()

func _chain_new_zombies_in_area() -> void:
	for zombie:Zombie000Base in _get_zombies_in_cage_area():
		if not _chained_zombies.has(zombie.get_instance_id()):
			_attach_chain_target(zombie)

func _attach_chain_target(zombie:Zombie000Base) -> void:
	if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
		return
	var target_id:int = zombie.get_instance_id()
	if _chained_zombies.has(target_id):
		return
	if not _claim_chain_ownership(zombie):
		return
	_chained_zombies[target_id] = zombie
	_create_chain_visual(target_id, zombie)

func _claim_chain_ownership(zombie:Zombie000Base) -> bool:
	var owners:Dictionary = zombie.get_meta(CHAIN_OWNERS_META, {})
	owners[self.get_instance_id()] = self
	zombie.set_meta(CHAIN_OWNERS_META, owners)
	return true

func _get_zombies_in_cage_area() -> Array[Zombie000Base]:
	return _get_zombies_in_x_ranges(_chain_area_x_ranges)

func _get_zombies_in_x_ranges(x_ranges:Dictionary[int, Vector2]) -> Array[Zombie000Base]:
	var result:Array[Zombie000Base] = []
	if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.zombie_manager):
		return result
	var ground_bounds:Rect2 = _chain_ground_bounds \
		if _chain_skill_active and _chain_ground_bounds.has_area() \
		else _get_current_cage_ground_bounds()
	## 使用完整存活列表快照，避免僵尸换行时短暂离开按行缓存而漏检。
	for zombie:Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		if not x_ranges.has(zombie.lane):
			continue
		## 行缓存中的范围只用于限定三列；真正进入力场与否必须用僵尸当前脚点
		## 的 X/Y 实时计算椭圆边界。否则处在弧形边缘外的僵尸会被提前上锁。
		var ground_position:Vector2 = zombie.shadow.global_position
		if (
			ground_position.y < ground_bounds.position.y
			or ground_position.y > ground_bounds.end.y
		):
			continue
		var lane_x_range:Vector2 = x_ranges[zombie.lane]
		var wall_x_range:Vector2 = _get_cage_hard_x_range_at_y(
			ground_bounds,
			ground_position.y
		)
		var x_range:= Vector2(
			maxf(lane_x_range.x, wall_x_range.x),
			minf(lane_x_range.y, wall_x_range.y)
		)
		if x_range.x > x_range.y:
			continue
		var zombie_x:float = ground_position.x
		if zombie_x >= x_range.x and zombie_x <= x_range.y:
			result.append(zombie)
	return result

func _create_cage_visual() -> void:
	_remove_cage_visual()
	var first_lane:int = maxi(0, row_col.x - 1)
	var last_lane:int = mini(Global.main_game.zombie_manager.all_zombie_rows.size() - 1, row_col.x + 1)
	var cage_visual:PlantEffectGarlicMaugaCage = CAGE_EFFECT_SCENE.new()
	cage_visual.name = "MaugaCage"
	add_child(cage_visual)
	## 原力场材质与发光保持不变；底部闭合圈就是实际困敌边界。
	cage_visual.setup_pvz_region(_chain_ground_bounds, first_lane, last_lane)
	_cage_visual = cage_visual

func _remove_cage_visual() -> void:
	if is_instance_valid(_cage_visual):
		_cage_visual.queue_free()
	_cage_visual = null

func _create_chain_visual(target_id:int, zombie:Zombie000Base) -> void:
	var chain_visual:Node2D = CHAIN_EFFECT_SCENE.new()
	chain_visual.name = "MaugaChain_%s" % target_id
	add_child(chain_visual)
	chain_visual.setup(self, zombie)
	_chain_visuals[target_id] = chain_visual

func _update_chain_target_leash(target_id:int, zombie:Zombie000Base) -> void:
	var ground_position:Vector2 = zombie.shadow.global_position
	## 换行、击退等效果也不能把脚点送出力场上下边界。
	var clamped_ground_y:float = clampf(
		ground_position.y,
		_chain_ground_bounds.position.y,
		_chain_ground_bounds.end.y
	)
	var target_x_range:Vector2 = _get_chain_target_ground_x_range(
		target_id,
		zombie,
		clamped_ground_y
	)
	var ground_x:float = ground_position.x
	var clamped_ground_x:float = clampf(
		ground_x,
		target_x_range.x,
		target_x_range.y
	)
	if (
		is_equal_approx(clamped_ground_x, ground_x)
		and is_equal_approx(clamped_ground_y, ground_position.y)
	):
		return
	## 只消掉越过墙体的那一段位移；圈内不减速、不定身，也不改动僵尸原本的攻击状态。
	zombie.global_position += Vector2(
		clamped_ground_x - ground_x,
		clamped_ground_y - ground_position.y
	)

func _get_chain_target_ground_x_range(
	target_id:int,
	zombie:Zombie000Base,
	world_y:float
) -> Vector2:
	var wall_x_range:Vector2 = _get_cage_hard_x_range_at_y(_chain_ground_bounds, world_y)
	var point_x_range:Vector2 = _chain_area_x_ranges.get(zombie.lane, wall_x_range)
	point_x_range = Vector2(
		maxf(point_x_range.x, wall_x_range.x),
		minf(point_x_range.y, wall_x_range.y)
	)
	var body_offsets:= Vector2.ZERO
	var chain_visual:PlantEffectGarlicMaugaChain = _chain_visuals.get(target_id)
	if is_instance_valid(chain_visual):
		body_offsets = chain_visual.get_target_visible_body_x_offsets_from_ground()
	var body_safe_range:= Vector2(
		wall_x_range.x - body_offsets.x,
		wall_x_range.y - body_offsets.y
	)
	var result:= Vector2(
		maxf(point_x_range.x, body_safe_range.x),
		minf(point_x_range.y, body_safe_range.y)
	)
	if result.x <= result.y:
		return result
	## 极端超宽角色无法完整放入时，以力场中心对齐，避免 clamp 的反向区间产生跳墙。
	var centered_ground_x:float = _chain_ground_bounds.get_center().x \
		- (body_offsets.x + body_offsets.y) * 0.5
	return Vector2(centered_ground_x, centered_ground_x)

func _queue_deferred_boundary_enforcement() -> void:
	if _boundary_enforcement_deferred:
		return
	_boundary_enforcement_deferred = true
	call_deferred("_enforce_chain_boundaries_after_movement")

func _enforce_chain_boundaries_after_movement() -> void:
	_boundary_enforcement_deferred = false
	if not _chain_skill_active:
		return
	## SceneTree Tween 在普通节点处理之后仍可能改坐标；绘制前再以同一条墙线兜底一次。
	for target_id:int in _chained_zombies.keys().duplicate():
		var zombie:Zombie000Base = _chained_zombies.get(target_id)
		if is_instance_valid(zombie) and not zombie.is_death and not zombie.is_hypno:
			_update_chain_target_leash(target_id, zombie)

func _release_chain_target(target_id:int) -> void:
	if not _chained_zombies.has(target_id):
		return
	var zombie:Zombie000Base = _chained_zombies[target_id]
	if is_instance_valid(zombie):
		var owners:Dictionary = zombie.get_meta(CHAIN_OWNERS_META, {})
		owners.erase(self.get_instance_id())
		if owners.is_empty():
			zombie.remove_meta(CHAIN_OWNERS_META)
		else:
			zombie.set_meta(CHAIN_OWNERS_META, owners)
	var chain_visual:Node2D = _chain_visuals.get(target_id)
	if is_instance_valid(chain_visual):
		chain_visual.queue_free()
	_chained_zombies.erase(target_id)
	_chain_visuals.erase(target_id)

func _release_all_chains() -> void:
	for target_id:int in _chained_zombies.keys().duplicate():
		_release_chain_target(target_id)

@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport:Node, event:InputEvent, shape_idx:int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_activate_chain_skill()

func gat_save_game_data_plant() -> Dictionary:
	return super()

func load_game_data_plant(save_game_data_plant:Dictionary):
	super(save_game_data_plant)
	_update_ready_glow()
