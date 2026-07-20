extends Plant037Garlic
class_name Plant037GarlicMauga

const CHAIN_TRIGGER_HP := 75
const CHAIN_META := &"garlic_mauga_chain_count"
const CHAIN_EFFECT_SCENE := preload("res://scripts/fx/plant_effect/plant_effect_garlic_mauga_chain.gd")

@export var chain_lane_shift_time := 0.55
@export var chain_lane_hold_time := 1.0
@export var chain_pull_time := 0.75
@export var chain_stink_pause := 0.35

var _chain_activated := false
var _chained_zombies:Dictionary[int, Zombie000Base] = {}
var _chain_visuals:Dictionary[int, Node2D] = {}
var _chain_anchor_positions:Dictionary[int, Vector2] = {}
var _chain_anchor_lanes:Dictionary[int, int] = {}
var _chain_lane_directions:Dictionary[int, int] = {}
var _chain_tweens:Dictionary[int, Tween] = {}
var _front_target_ids:Dictionary[int, bool] = {}

func ready_norm_signal_connect():
	super()
	hp_component.signal_hp_loss.connect(_on_hp_loss_for_chain)
	signal_character_death.connect(_release_all_chains)

func _process(_delta:float) -> void:
	if not _chain_activated:
		return
	for target_id:int in _chained_zombies.keys().duplicate():
		var zombie:Zombie000Base = _chained_zombies.get(target_id)
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			_release_chain_target(target_id)

func _on_hp_loss_for_chain(curr_hp:int, _is_drop:bool) -> void:
	if _chain_activated or is_death or curr_hp > CHAIN_TRIGGER_HP:
		return
	_activate_chains()

## 75 血以前保留普通大蒜换行；锁链启动后由专属循环接管，避免两套换行协程互相打断。
func _be_zombie_eat_once_special(attack_zombie:Zombie000Base) -> void:
	if not _chain_activated:
		super(attack_zombie)

func _activate_chains() -> void:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return
	_chain_activated = true
	var center_x:float = plant_cell.global_position.x + plant_cell.size.x * 0.5
	for zombie:Zombie000Base in _get_zombies_in_nine_cells():
		var target_id:int = zombie.get_instance_id()
		_chained_zombies[target_id] = zombie
		_chain_anchor_positions[target_id] = zombie.global_position
		_chain_anchor_lanes[target_id] = zombie.lane
		_front_target_ids[target_id] = zombie.shadow.global_position.x > center_x
		_chain_lane_directions[target_id] = _pick_initial_lane_direction(zombie)
		_acquire_zombie_movement_lock(zombie)
		_create_chain_visual(target_id, zombie)
		if _front_target_ids[target_id]:
			_run_front_chain_cycle(target_id)

func _get_zombies_in_nine_cells() -> Array[Zombie000Base]:
	var result:Array[Zombie000Base] = []
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_cells.size():
		return result
	var lane_cells:Array = all_cells[row_col.x]
	if row_col.y < 0 or row_col.y >= lane_cells.size():
		return result
	var first_column:int = maxi(0, row_col.y - 1)
	var last_column:int = mini(lane_cells.size() - 1, row_col.y + 1)
	var first_cell:PlantCell = lane_cells[first_column]
	var last_cell:PlantCell = lane_cells[last_column]
	var range_min_x:float = minf(first_cell.global_position.x, last_cell.global_position.x)
	var range_max_x:float = maxf(
		first_cell.global_position.x + first_cell.size.x,
		last_cell.global_position.x + last_cell.size.x
	)
	var all_zombies_2d:Array = Global.main_game.zombie_manager.all_zombies_2d
	var first_lane:int = maxi(0, row_col.x - 1)
	var last_lane:int = mini(all_zombies_2d.size() - 1, row_col.x + 1)
	for target_lane:int in range(first_lane, last_lane + 1):
		for zombie:Zombie000Base in all_zombies_2d[target_lane].duplicate():
			if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
				continue
			var zombie_x:float = zombie.shadow.global_position.x
			if zombie_x >= range_min_x and zombie_x <= range_max_x:
				result.append(zombie)
	return result

func _create_chain_visual(target_id:int, zombie:Zombie000Base) -> void:
	var chain_visual:Node2D = CHAIN_EFFECT_SCENE.new()
	chain_visual.name = "MaugaChain_%s" % target_id
	add_child(chain_visual)
	chain_visual.setup(self, zombie)
	_chain_visuals[target_id] = chain_visual

func _acquire_zombie_movement_lock(zombie:Zombie000Base) -> void:
	var lock_count:int = int(zombie.get_meta(CHAIN_META, 0)) + 1
	zombie.set_meta(CHAIN_META, lock_count)
	zombie.move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsGarlicMaugaChain)

func _release_zombie_movement_lock(zombie:Zombie000Base) -> void:
	var lock_count:int = maxi(0, int(zombie.get_meta(CHAIN_META, 1)) - 1)
	if lock_count > 0:
		zombie.set_meta(CHAIN_META, lock_count)
		return
	zombie.remove_meta(CHAIN_META)
	zombie.move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsGarlicMaugaChain)

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
		await _pull_zombie_to_anchor(target_id, zombie)
		if not _is_chain_target_active(target_id):
			break
		await _stink_and_shift_to_adjacent_lane(target_id, zombie, -first_lane_direction)
		if not _is_chain_target_active(target_id):
			break
		await _hold_zombie_in_shifted_lane(target_id)
		if not _is_chain_target_active(target_id):
			break
		await _pull_zombie_to_anchor(target_id, zombie)
	_release_chain_target(target_id)

func _stink_and_shift_to_adjacent_lane(target_id:int, zombie:Zombie000Base, lane_direction:int) -> void:
	await _play_stink(zombie)
	if not _is_chain_target_active(target_id):
		return
	var target_lane:int = _pick_adjacent_lane(zombie, lane_direction)
	if target_lane == zombie.lane:
		return
	await _move_zombie_to_lane(target_id, zombie, target_lane, chain_lane_shift_time)

func _pick_initial_lane_direction(zombie:Zombie000Base) -> int:
	var valid_directions:Array[int] = _get_valid_lane_directions(zombie)
	if valid_directions.is_empty():
		return 1
	return valid_directions.pick_random()

func _get_valid_lane_directions(zombie:Zombie000Base) -> Array[int]:
	var valid_directions:Array[int] = []
	var zombie_rows:Array = Global.main_game.zombie_manager.all_zombie_rows
	for lane_offset:int in [-1, 1]:
		var candidate_lane:int = zombie.lane + lane_offset
		if candidate_lane < 0 or candidate_lane >= zombie_rows.size():
			continue
		if zombie_rows[candidate_lane].zombie_row_type == zombie.curr_zombie_row_type:
			valid_directions.append(lane_offset)
	return valid_directions

func _pick_adjacent_lane(zombie:Zombie000Base, preferred_direction:int) -> int:
	var valid_directions:Array[int] = _get_valid_lane_directions(zombie)
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

func _pull_zombie_to_anchor(target_id:int, zombie:Zombie000Base) -> void:
	var anchor_lane:int = _chain_anchor_lanes[target_id]
	if zombie.lane != anchor_lane:
		zombie.lane = anchor_lane
		zombie.signal_lane_update.emit()
		zombie.reparent(Global.main_game.zombie_manager.all_zombie_rows[anchor_lane])
	var tween:Tween = create_tween()
	_chain_tweens[target_id] = tween
	tween.tween_property(zombie, ^"global_position", _chain_anchor_positions[target_id], chain_pull_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	_chain_tweens.erase(target_id)

func _play_stink(zombie:Zombie000Base) -> void:
	if not is_instance_valid(zombie):
		return
	SoundManager.play_character_SFX("yuck")
	zombie.update_speed_factor(0.0, E_Influence_Speed_Factor.EatGarlic)
	await get_tree().create_timer(chain_stink_pause, false).timeout
	if is_instance_valid(zombie):
		zombie.update_speed_factor(1.0, E_Influence_Speed_Factor.EatGarlic)

func _is_chain_target_active(target_id:int) -> bool:
	if is_death or not _chained_zombies.has(target_id):
		return false
	var zombie:Zombie000Base = _chained_zombies[target_id]
	return is_instance_valid(zombie) and not zombie.is_death and not zombie.is_hypno

func _release_chain_target(target_id:int) -> void:
	if not _chained_zombies.has(target_id):
		return
	var tween:Tween = _chain_tweens.get(target_id)
	if is_instance_valid(tween):
		tween.kill()
	var zombie:Zombie000Base = _chained_zombies[target_id]
	if is_instance_valid(zombie):
		zombie.update_speed_factor(1.0, E_Influence_Speed_Factor.EatGarlic)
		_release_zombie_movement_lock(zombie)
	var chain_visual:Node2D = _chain_visuals.get(target_id)
	if is_instance_valid(chain_visual):
		chain_visual.queue_free()
	_chained_zombies.erase(target_id)
	_chain_visuals.erase(target_id)
	_chain_anchor_positions.erase(target_id)
	_chain_anchor_lanes.erase(target_id)
	_chain_lane_directions.erase(target_id)
	_chain_tweens.erase(target_id)
	_front_target_ids.erase(target_id)

func _release_all_chains() -> void:
	for target_id:int in _chained_zombies.keys().duplicate():
		_release_chain_target(target_id)
