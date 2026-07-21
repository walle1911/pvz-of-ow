extends Plant037Garlic
class_name Plant037GarlicMauga

const CHAIN_META := &"garlic_mauga_chain_count"
const CHAIN_OWNER_META := &"garlic_mauga_chain_owner"
const CHAIN_EFFECT_SCENE := preload("res://scripts/fx/plant_effect/plant_effect_garlic_mauga_chain.gd")
const CHAIN_LEFT_BOUNDARY_INSET := 40.0

@export var chain_lane_shift_time := 0.55
@export var chain_lane_hold_time := 1.0
@export var chain_pull_time := 0.75
@export var chain_stink_pause := 0.35
@export var chain_last_stand_duration := 5.0

var _chain_activated := false
var _chained_zombies:Dictionary[int, Zombie000Base] = {}
var _chain_visuals:Dictionary[int, Node2D] = {}
var _chain_anchor_positions:Dictionary[int, Vector2] = {}
var _chain_lane_directions:Dictionary[int, int] = {}
var _chain_tweens:Dictionary[int, Tween] = {}
var _movement_locked_target_ids:Dictionary[int, bool] = {}
var _trigger_zombie_id := 0
var _active_pull_target_id := 0
var _chain_area_x_range:= Vector2(-INF, INF)
var _death_trigger_zombie:Zombie000Base
var _is_chain_last_stand := false

func ready_norm_signal_connect():
	super()
	signal_character_death.connect(_release_all_chains)

func _process(_delta:float) -> void:
	if not _chain_activated:
		return
	_chain_new_zombies_in_area()
	for target_id:int in _chained_zombies.keys().duplicate():
		var zombie:Zombie000Base = _chained_zombies.get(target_id)
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			_release_chain_target(target_id)
		elif target_id != _active_pull_target_id:
			_update_normal_chain_target_leash(target_id, zombie)
	_try_start_pending_trigger_cycle()

func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base) -> void:
	_death_trigger_zombie = attack_zombie
	super(attack_value, attack_zombie)
	_death_trigger_zombie = null

## 临终锁链启动前保留普通大蒜换行；启动后由专属循环接管。
func _be_zombie_eat_once_special(attack_zombie:Zombie000Base) -> void:
	if not _chain_activated:
		super(attack_zombie)

func character_death() -> void:
	if _is_chain_last_stand:
		return
	_is_chain_last_stand = true
	_activate_chains(_death_trigger_zombie)
	await get_tree().create_timer(chain_last_stand_duration, false).timeout
	if is_inside_tree():
		super()

func _activate_chains(trigger_zombie:Zombie000Base) -> void:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return
	_chain_activated = true
	_chain_area_x_range = _get_mauga_nine_grid_x_range()
	_trigger_zombie_id = trigger_zombie.get_instance_id() if is_instance_valid(trigger_zombie) else 0
	var chain_targets:Array[Zombie000Base] = _get_zombies_in_nine_cells()
	if (
		is_instance_valid(trigger_zombie)
		and not trigger_zombie.is_death
		and not trigger_zombie.is_hypno
		and not chain_targets.has(trigger_zombie)
	):
		chain_targets.append(trigger_zombie)
	for zombie:Zombie000Base in chain_targets:
		_attach_chain_target(zombie, zombie.get_instance_id() == _trigger_zombie_id)

func _chain_new_zombies_in_area() -> void:
	for zombie:Zombie000Base in _get_zombies_in_nine_cells():
		if not _chained_zombies.has(zombie.get_instance_id()):
			_attach_chain_target(zombie, zombie.get_instance_id() == _trigger_zombie_id)

func _attach_chain_target(zombie:Zombie000Base, is_trigger_zombie:bool) -> void:
	if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
		return
	var target_id:int = zombie.get_instance_id()
	if _chained_zombies.has(target_id):
		return
	if not _claim_chain_ownership(zombie):
		return
	_chained_zombies[target_id] = zombie
	_chain_anchor_positions[target_id] = zombie.global_position
	_create_chain_visual(target_id, zombie)
	if is_trigger_zombie:
		_try_start_pending_trigger_cycle()

func _try_start_pending_trigger_cycle() -> void:
	if _active_pull_target_id != 0 or _trigger_zombie_id == 0:
		return
	if not _chained_zombies.has(_trigger_zombie_id):
		return
	var zombie:Zombie000Base = _chained_zombies[_trigger_zombie_id]
	if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
		return
	_active_pull_target_id = _trigger_zombie_id
	_chain_lane_directions[_active_pull_target_id] = _pick_initial_lane_direction(_active_pull_target_id, zombie)
	_acquire_zombie_movement_lock(_active_pull_target_id, zombie)
	_run_front_chain_cycle(_active_pull_target_id)

func _claim_chain_ownership(zombie:Zombie000Base) -> bool:
	var current_owner = zombie.get_meta(CHAIN_OWNER_META, null)
	if is_instance_valid(current_owner) and current_owner != self:
		return false
	zombie.set_meta(CHAIN_OWNER_META, self)
	return true

func _get_zombies_in_nine_cells() -> Array[Zombie000Base]:
	var result:Array[Zombie000Base] = []
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_cells.size():
		return result
	var lane_cells:Array = all_cells[row_col.x]
	if row_col.y < 0 or row_col.y >= lane_cells.size():
		return result
	var chain_x_range:Vector2 = _get_mauga_nine_grid_x_range()
	var all_zombies_2d:Array = Global.main_game.zombie_manager.all_zombies_2d
	var first_lane:int = maxi(0, row_col.x - 1)
	var last_lane:int = mini(all_zombies_2d.size() - 1, row_col.x + 1)
	for target_lane:int in range(first_lane, last_lane + 1):
		for zombie:Zombie000Base in all_zombies_2d[target_lane].duplicate():
			if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
				continue
			var zombie_x:float = zombie.shadow.global_position.x
			if zombie_x >= chain_x_range.x and zombie_x <= chain_x_range.y:
				result.append(zombie)
	return result

func _get_mauga_nine_grid_x_range() -> Vector2:
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_cells.size():
		return Vector2(-INF, INF)
	var lane_cells:Array = all_cells[row_col.x]
	if lane_cells.is_empty():
		return Vector2(-INF, INF)
	var first_column:int = maxi(0, row_col.y - 1)
	var last_column:int = mini(lane_cells.size() - 1, row_col.y + 1)
	var range_min_x:float = INF
	var range_max_x:float = -INF
	for column:int in range(first_column, last_column + 1):
		var range_cell:PlantCell = lane_cells[column]
		var cell_start_x:float = range_cell.global_position.x
		var cell_end_x:float = cell_start_x + range_cell.size.x
		range_min_x = minf(range_min_x, minf(cell_start_x, cell_end_x))
		range_max_x = maxf(range_max_x, maxf(cell_start_x, cell_end_x))
	## 将左边界累计向右收窄 40px，形成锁链实际使用的矩形范围。
	return Vector2(range_min_x + CHAIN_LEFT_BOUNDARY_INSET, range_max_x)

func _create_chain_visual(target_id:int, zombie:Zombie000Base) -> void:
	var chain_visual:Node2D = CHAIN_EFFECT_SCENE.new()
	chain_visual.name = "MaugaChain_%s" % target_id
	add_child(chain_visual)
	chain_visual.setup(self, zombie)
	_chain_visuals[target_id] = chain_visual

func _acquire_zombie_movement_lock(target_id:int, zombie:Zombie000Base) -> void:
	if _movement_locked_target_ids.has(target_id):
		return
	var lock_count:int = int(zombie.get_meta(CHAIN_META, 0)) + 1
	zombie.set_meta(CHAIN_META, lock_count)
	zombie.move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsGarlicMaugaChain)
	_movement_locked_target_ids[target_id] = true

func _release_zombie_movement_lock(zombie:Zombie000Base) -> void:
	var lock_count:int = maxi(0, int(zombie.get_meta(CHAIN_META, 1)) - 1)
	if lock_count > 0:
		zombie.set_meta(CHAIN_META, lock_count)
		return
	zombie.remove_meta(CHAIN_META)
	zombie.move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsGarlicMaugaChain)

func _update_normal_chain_target_leash(target_id:int, zombie:Zombie000Base) -> void:
	var ground_x:float = zombie.shadow.global_position.x
	if ground_x >= _chain_area_x_range.x and ground_x <= _chain_area_x_range.y:
		return
	## 用脚下坐标修正根节点，保证角色视觉不会跨出以毛加为中心的九宫格边界。
	var clamped_ground_x:float = clampf(ground_x, _chain_area_x_range.x, _chain_area_x_range.y)
	zombie.global_position.x += clamped_ground_x - ground_x
	if not _movement_locked_target_ids.has(target_id):
		_acquire_zombie_movement_lock(target_id, zombie)

func _run_front_chain_cycle(target_id:int) -> void:
	while _is_chain_target_active(target_id):
		var zombie:Zombie000Base = _chained_zombies[target_id]
		var first_lane_direction:int = _chain_lane_directions[target_id]
		await _stink_and_shift_to_adjacent_lane(target_id, zombie, first_lane_direction)
		if not _is_chain_target_active(target_id):
			break
		await _hold_zombie_in_shifted_lane(target_id)
		if not _is_chain_target_active(target_id):
			break
		await _pull_zombie_toward_mauga(target_id, zombie)
		if not _is_chain_target_active(target_id):
			break
		await _stink_and_shift_to_adjacent_lane(target_id, zombie, -first_lane_direction)
		if not _is_chain_target_active(target_id):
			break
		await _hold_zombie_in_shifted_lane(target_id)
		if not _is_chain_target_active(target_id):
			break
		await _pull_zombie_toward_mauga(target_id, zombie)
	if not _chained_zombies.has(target_id):
		return
	var final_zombie:Zombie000Base = _chained_zombies[target_id]
	if is_death or not is_instance_valid(final_zombie) or final_zombie.is_death or final_zombie.is_hypno:
		_release_chain_target(target_id)

func _stink_and_shift_to_adjacent_lane(target_id:int, zombie:Zombie000Base, lane_direction:int) -> void:
	await _play_stink(zombie)
	if not _is_chain_target_active(target_id):
		return
	var target_lane:int = _pick_adjacent_lane(target_id, zombie, lane_direction)
	if target_lane == zombie.lane:
		return
	await _move_zombie_to_lane(target_id, zombie, target_lane, chain_lane_shift_time)

func _pick_initial_lane_direction(target_id:int, zombie:Zombie000Base) -> int:
	var valid_directions:Array[int] = _get_valid_lane_directions(target_id, zombie)
	if valid_directions.is_empty():
		return 1
	return valid_directions.pick_random()

func _get_valid_lane_directions(target_id:int, zombie:Zombie000Base) -> Array[int]:
	var valid_directions:Array[int] = []
	var zombie_rows:Array = Global.main_game.zombie_manager.all_zombie_rows
	var center_lane:int = lane
	for lane_offset:int in [-1, 1]:
		var candidate_lane:int = zombie.lane + lane_offset
		if candidate_lane < 0 or candidate_lane >= zombie_rows.size():
			continue
		## 每只僵尸只能在其被锁住时所在行及上下相邻行内活动。
		if absi(candidate_lane - center_lane) > 1:
			continue
		if zombie_rows[candidate_lane].zombie_row_type == zombie.curr_zombie_row_type:
			valid_directions.append(lane_offset)
	return valid_directions

func _pick_adjacent_lane(target_id:int, zombie:Zombie000Base, preferred_direction:int) -> int:
	var valid_directions:Array[int] = _get_valid_lane_directions(target_id, zombie)
	if valid_directions.is_empty():
		return zombie.lane
	var real_direction:int = preferred_direction if valid_directions.has(preferred_direction) else valid_directions[0]
	return zombie.lane + real_direction

func _hold_zombie_in_shifted_lane(target_id:int) -> void:
	if not _is_chain_target_active(target_id):
		return
	await get_tree().create_timer(chain_lane_hold_time, false).timeout

func _move_zombie_to_lane(target_id:int, zombie:Zombie000Base, target_lane:int, duration:float) -> void:
	if target_lane == zombie.lane:
		return
	zombie.lane = target_lane
	zombie.signal_lane_update.emit()
	zombie.reparent(Global.main_game.zombie_manager.all_zombie_rows[target_lane])
	var target_y:float = Global.main_game.zombie_manager.all_zombie_rows[target_lane].zombie_create_position.position.y
	var tween:Tween = create_tween()
	_chain_tweens[target_id] = tween
	tween.tween_property(zombie, ^"position:y", target_y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_chain_tweens.erase(target_id)

func _pull_zombie_toward_mauga(target_id:int, zombie:Zombie000Base) -> void:
	var zombie_rows:Array = Global.main_game.zombie_manager.all_zombie_rows
	var center_lane:int = lane
	var target_lane:int = zombie.lane
	if zombie.lane != lane:
		var lane_toward_mauga:int = zombie.lane + signi(lane - zombie.lane)
		if (
			lane_toward_mauga >= 0
			and lane_toward_mauga < zombie_rows.size()
			and absi(lane_toward_mauga - center_lane) <= 1
			and zombie_rows[lane_toward_mauga].zombie_row_type == zombie.curr_zombie_row_type
		):
			target_lane = lane_toward_mauga

	## 前方目标只能沿捕获时所在的原列上下换行，锁链不改变它的列坐标。
	var activity_center:Vector2 = _chain_anchor_positions[target_id]
	var target_x:float = activity_center.x
	var target_y:float = zombie.global_position.y
	if target_lane != zombie.lane:
		target_y = zombie_rows[target_lane].zombie_create_position.global_position.y
	var pull_destination:= Vector2(target_x, target_y)

	## 斜前方目标若已经被臭到更靠近毛加的行，绝不能再把它拉回较远的捕获点。
	if pull_destination.distance_to(global_position) >= zombie.global_position.distance_to(global_position):
		pull_destination = zombie.global_position
		target_lane = zombie.lane

	if target_lane != zombie.lane:
		zombie.lane = target_lane
		zombie.signal_lane_update.emit()
		zombie.reparent(zombie_rows[target_lane])
	var tween:Tween = create_tween()
	_chain_tweens[target_id] = tween
	tween.tween_property(zombie, ^"global_position", pull_destination, chain_pull_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_chain_tweens.erase(target_id)

func _play_stink(zombie:Zombie000Base) -> void:
	if not is_instance_valid(zombie):
		return
	await zombie.play_garlic_reaction(chain_stink_pause)

func _is_chain_target_active(target_id:int) -> bool:
	if is_death or target_id != _active_pull_target_id or not _chained_zombies.has(target_id):
		return false
	var zombie:Zombie000Base = _chained_zombies[target_id]
	if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
		return false
	return zombie.get_meta(CHAIN_OWNER_META, null) == self

func _release_chain_target(target_id:int) -> void:
	if not _chained_zombies.has(target_id):
		return
	var tween:Tween = _chain_tweens.get(target_id)
	if is_instance_valid(tween):
		tween.kill()
	var zombie:Zombie000Base = _chained_zombies[target_id]
	if is_instance_valid(zombie):
		if zombie.get_meta(CHAIN_OWNER_META, null) == self:
			zombie.remove_meta(CHAIN_OWNER_META)
		zombie.update_speed_factor(1.0, E_Influence_Speed_Factor.EatGarlic)
		if _movement_locked_target_ids.has(target_id):
			_release_zombie_movement_lock(zombie)
	var chain_visual:Node2D = _chain_visuals.get(target_id)
	if is_instance_valid(chain_visual):
		chain_visual.queue_free()
	_chained_zombies.erase(target_id)
	_chain_visuals.erase(target_id)
	_chain_anchor_positions.erase(target_id)
	_chain_lane_directions.erase(target_id)
	_chain_tweens.erase(target_id)
	_movement_locked_target_ids.erase(target_id)
	if target_id == _active_pull_target_id:
		_active_pull_target_id = 0
	if target_id == _trigger_zombie_id:
		_trigger_zombie_id = 0

func _release_all_chains() -> void:
	for target_id:int in _chained_zombies.keys().duplicate():
		_release_chain_target(target_id)
