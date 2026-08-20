extends Plant000Base
class_name Plant069HypnoShroomJuno

const PULSAR_TORPEDO_SCENE:PackedScene = preload("res://scenes/bullet/bullet_013_juno_pulsar_torpedo.tscn")
const PULSAR_RETICLE_SCRIPT:Script = preload("res://scripts/fx/plant_effect/plant_effect_juno_pulsar_reticle.gd")
const PULSAR_BURST_SCRIPT:Script = preload("res://scripts/fx/plant_effect/plant_effect_juno_pulsar_burst.gd")

@export_group("朱诺·脉冲飞雷")
@export_range(0.1, 30.0, 0.1, "suffix:秒") var pulsar_cooldown:= 10.0
@export_range(0.1, 3.0, 0.05, "suffix:秒") var pulsar_lock_time_near:= 0.5
@export_range(0.1, 3.0, 0.05, "suffix:秒") var pulsar_lock_time_far:= 1.0
@export_range(0.05, 1.0, 0.05, "suffix:秒") var pulsar_fire_delay:= 0.18
@export_range(0.5, 6.0, 0.1, "suffix:秒") var pulsar_targeting_window:= 4.0
@export_range(1, 12, 1) var pulsar_max_targets:= 12
@export_range(1, 500, 1, "suffix:伤害") var pulsar_damage:= 85
@export_range(1, 9, 1, "suffix:列") var pulsar_column_count:= 2
@export_range(0.05, 3.0, 0.05, "suffix:秒") var pulsar_initial_delay:= 0.6

var _pulsar_cooldown_remaining:= 0.0
var _pulsar_is_targeting:= false
var _pulsar_targeting_elapsed:= 0.0
var _pulsar_fire_countdown:= -1.0
var _pulsar_targets:Array[Zombie000Base] = []
var _pulsar_lock_elapsed:Dictionary[int, float] = {}
var _pulsar_lock_duration:Dictionary[int, float] = {}
var _pulsar_locked:Dictionary[int, bool] = {}
var _pulsar_reticles:Dictionary[int, Node2D] = {}


func ready_norm_signal_connect():
	super()
	signal_character_death.connect(_cleanup_pulsar_targeting)
	_pulsar_cooldown_remaining = pulsar_initial_delay


func _physics_process(delta:float) -> void:
	if character_init_type != E_CharacterInitType.IsNorm or is_death:
		return
	if is_sleeping:
		if _pulsar_is_targeting:
			_cancel_pulsar_targeting()
		return
	if _pulsar_is_targeting:
		_update_pulsar_targeting(delta)
		return
	_pulsar_cooldown_remaining = maxf(_pulsar_cooldown_remaining - delta, 0.0)
	if _pulsar_cooldown_remaining <= 0.0:
		var candidates:= _get_zombies_in_pulsar_range()
		if not candidates.is_empty():
			_begin_pulsar_targeting(candidates)


func _begin_pulsar_targeting(candidates:Array[Zombie000Base]) -> void:
	_pulsar_is_targeting = true
	_pulsar_targeting_elapsed = 0.0
	_pulsar_fire_countdown = -1.0
	_clear_pulsar_targets()
	for target:Zombie000Base in candidates:
		if _pulsar_targets.size() >= pulsar_max_targets:
			break
		_add_pulsar_target(target)
	_spawn_pulsar_burst(global_position + Vector2(0.0, -48.0), false)


func _update_pulsar_targeting(delta:float) -> void:
	_pulsar_targeting_elapsed += delta
	_prune_pulsar_targets()
	_scan_for_new_pulsar_targets()
	var has_locked_target:= false
	var all_targets_locked:= not _pulsar_targets.is_empty()
	for target:Zombie000Base in _pulsar_targets:
		if not is_instance_valid(target) or target.is_death:
			continue
		var target_id:= target.get_instance_id()
		var is_in_range:= _is_zombie_in_pulsar_range(target)
		if is_in_range and not _pulsar_locked.get(target_id, false):
			_pulsar_lock_elapsed[target_id] = _pulsar_lock_elapsed.get(target_id, 0.0) + delta
			if _pulsar_lock_elapsed[target_id] >= _pulsar_lock_duration.get(target_id, pulsar_lock_time_far):
				_pulsar_locked[target_id] = true
		var is_locked:bool = _pulsar_locked.get(target_id, false)
		has_locked_target = has_locked_target or is_locked
		all_targets_locked = all_targets_locked and is_locked
		var reticle:= _pulsar_reticles.get(target_id) as Node2D
		if is_instance_valid(reticle):
			var duration:float = _pulsar_lock_duration.get(target_id, pulsar_lock_time_far)
			reticle.call(&"set_lock_progress", _pulsar_lock_elapsed.get(target_id, 0.0) / maxf(duration, 0.001))
			reticle.call(&"set_tracking_active", is_in_range or is_locked)

	if all_targets_locked and has_locked_target:
		if _pulsar_fire_countdown < 0.0:
			_pulsar_fire_countdown = pulsar_fire_delay
		else:
			_pulsar_fire_countdown -= delta
			if _pulsar_fire_countdown <= 0.0:
				_fire_pulsar_torpedoes()
	else:
		_pulsar_fire_countdown = -1.0
	## 对齐原作最长索敌窗口：超时后释放已完成锁定的目标，未完成者淡出。
	if _pulsar_targeting_elapsed >= pulsar_targeting_window:
		if has_locked_target:
			_fire_pulsar_torpedoes()
		else:
			_cancel_pulsar_targeting()
		return

	if _pulsar_targets.is_empty():
		_cancel_pulsar_targeting()


func _scan_for_new_pulsar_targets() -> void:
	if _pulsar_targets.size() >= pulsar_max_targets:
		return
	for target:Zombie000Base in _get_zombies_in_pulsar_range():
		if _pulsar_targets.size() >= pulsar_max_targets:
			break
		if not _pulsar_targets.has(target):
			_add_pulsar_target(target)


func _add_pulsar_target(target:Zombie000Base) -> void:
	if not is_instance_valid(target) or target.is_death or target.is_hypno:
		return
	var target_id:= target.get_instance_id()
	var distance_ratio:= _get_pulsar_target_distance_ratio(target)
	_pulsar_targets.append(target)
	_pulsar_lock_elapsed[target_id] = 0.0
	_pulsar_lock_duration[target_id] = lerpf(pulsar_lock_time_near, pulsar_lock_time_far, distance_ratio)
	_pulsar_locked[target_id] = false
	if not is_instance_valid(Global.main_game):
		return
	var reticle:= PULSAR_RETICLE_SCRIPT.new() as Node2D
	Global.main_game.add_child(reticle)
	reticle.call(&"setup", target)
	_pulsar_reticles[target_id] = reticle


func _fire_pulsar_torpedoes() -> void:
	if not _pulsar_is_targeting:
		return
	_pulsar_is_targeting = false
	_pulsar_targeting_elapsed = 0.0
	_pulsar_cooldown_remaining = pulsar_cooldown
	var locked_targets:Array[Zombie000Base] = []
	for target:Zombie000Base in _pulsar_targets:
		if not is_instance_valid(target) or target.is_death:
			continue
		if _pulsar_locked.get(target.get_instance_id(), false):
			locked_targets.append(target)
	var launch_position:= global_position + Vector2(float(direction_x_root) * 5.0, -55.0)
	_spawn_pulsar_burst(launch_position, true)
	for target_index in locked_targets.size():
		_spawn_pulsar_torpedo(locked_targets[target_index], target_index, locked_targets.size(), launch_position)
	_release_pulsar_reticles()
	_clear_pulsar_target_data()


func _spawn_pulsar_torpedo(
	target:Zombie000Base,
	target_index:int,
	target_count:int,
	launch_position:Vector2
) -> void:
	if not is_instance_valid(target) or not is_instance_valid(Global.main_game):
		return
	var bullet:= PULSAR_TORPEDO_SCENE.instantiate() as Bullet000TrackBase
	if not is_instance_valid(bullet):
		return
	mark_bullet_recording_source(bullet)
	var spread_center:= (float(target_count) - 1.0) * 0.5
	var spread_offset:= (float(target_index) - spread_center) * 0.13
	var launch_direction:= Vector2(0.15 * float(direction_x_root), -1.0).rotated(spread_offset).normalized()
	var final_damage:= maxi(1, int(round(float(pulsar_damage) * get_attack_damage_multiplier())))
	var bullet_paras:Dictionary[Bullet000NormBase.E_InitParasAttr, Variant] = {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
		Bullet000NormBase.E_InitParasAttr.BulletLane: lane,
		Bullet000NormBase.E_InitParasAttr.Position: Global.main_game.bullets.to_local(launch_position),
		Bullet000NormBase.E_InitParasAttr.Direction: launch_direction,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: target.curr_be_attack_status,
		Bullet000NormBase.E_InitParasAttr.Enemy: target,
		Bullet000NormBase.E_InitParasAttr.AttackValue: final_damage,
	}
	bullet.init_bullet(bullet_paras)
	Global.main_game.bullets.add_child(bullet)


func _spawn_pulsar_burst(effect_position:Vector2, is_launch:bool) -> void:
	if not is_instance_valid(Global.main_game):
		return
	var burst:= PULSAR_BURST_SCRIPT.new() as Node2D
	Global.main_game.add_child(burst)
	burst.global_position = effect_position
	burst.call(&"setup", is_launch)


func _prune_pulsar_targets() -> void:
	for target_index in range(_pulsar_targets.size() - 1, -1, -1):
		var target:= _pulsar_targets[target_index]
		if is_instance_valid(target) and not target.is_death and not target.is_hypno:
			continue
		var target_id:= target.get_instance_id() if is_instance_valid(target) else 0
		var reticle:= _pulsar_reticles.get(target_id) as Node2D
		if is_instance_valid(reticle):
			reticle.queue_free()
		_pulsar_reticles.erase(target_id)
		_pulsar_lock_elapsed.erase(target_id)
		_pulsar_lock_duration.erase(target_id)
		_pulsar_locked.erase(target_id)
		_pulsar_targets.remove_at(target_index)


func _release_pulsar_reticles() -> void:
	for target:Zombie000Base in _pulsar_targets:
		if not is_instance_valid(target):
			continue
		var target_id:= target.get_instance_id()
		var reticle:= _pulsar_reticles.get(target_id) as Node2D
		if not is_instance_valid(reticle):
			continue
		if _pulsar_locked.get(target_id, false):
			reticle.call(&"finish_and_free")
		else:
			reticle.call(&"fade_and_free")
	_pulsar_reticles.clear()


func _cancel_pulsar_targeting() -> void:
	_pulsar_is_targeting = false
	_pulsar_targeting_elapsed = 0.0
	_pulsar_fire_countdown = -1.0
	_pulsar_cooldown_remaining = minf(maxf(pulsar_initial_delay, 0.1), 1.0)
	_clear_pulsar_targets()


func _cleanup_pulsar_targeting() -> void:
	_pulsar_is_targeting = false
	_pulsar_targeting_elapsed = 0.0
	_clear_pulsar_targets()


func _clear_pulsar_targets() -> void:
	for reticle:Node2D in _pulsar_reticles.values():
		if is_instance_valid(reticle):
			reticle.queue_free()
	_pulsar_reticles.clear()
	_clear_pulsar_target_data()


func _clear_pulsar_target_data() -> void:
	_pulsar_targets.clear()
	_pulsar_lock_elapsed.clear()
	_pulsar_lock_duration.clear()
	_pulsar_locked.clear()


func _get_zombies_in_pulsar_range() -> Array[Zombie000Base]:
	var result:Array[Zombie000Base] = []
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return result
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= all_cells.size():
		return result
	var lane_cells:Array = all_cells[lane]
	if row_col.y < 0 or row_col.y >= lane_cells.size():
		return result
	var x_bounds:= _get_pulsar_range_x_bounds(lane_cells)
	var first_lane:= maxi(0, lane - 1)
	var last_lane:= mini(Global.main_game.zombie_manager.all_zombies_2d.size() - 1, lane + 1)
	for target_lane in range(first_lane, last_lane + 1):
		var zombie_row:Array = Global.main_game.zombie_manager.all_zombies_2d[target_lane]
		for zombie:Zombie000Base in zombie_row:
			if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
				continue
			if zombie.global_position.x >= x_bounds.x and zombie.global_position.x <= x_bounds.y:
				result.append(zombie)
	result.sort_custom(
		func(a:Zombie000Base, b:Zombie000Base):
			return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return result


func _is_zombie_in_pulsar_range(target:Zombie000Base) -> bool:
	if not is_instance_valid(target) or target.is_death or target.is_hypno:
		return false
	if absi(target.lane - lane) > 1:
		return false
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return false
	var lane_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	var x_bounds:= _get_pulsar_range_x_bounds(lane_cells)
	return target.global_position.x >= x_bounds.x and target.global_position.x <= x_bounds.y


func _get_pulsar_range_x_bounds(lane_cells:Array) -> Vector2:
	var furthest_front_column:= clampi(
		row_col.y + pulsar_column_count * direction_x_root,
		0,
		lane_cells.size() - 1
	)
	var first_column:= mini(row_col.y, furthest_front_column)
	var last_column:= maxi(row_col.y, furthest_front_column)
	var first_cell:PlantCell = lane_cells[first_column]
	var last_cell:PlantCell = lane_cells[last_column]
	return Vector2(
		minf(first_cell.global_position.x, last_cell.global_position.x),
		maxf(first_cell.global_position.x + first_cell.size.x, last_cell.global_position.x + last_cell.size.x)
	)


func _get_pulsar_target_distance_ratio(target:Zombie000Base) -> float:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return 1.0
	var lane_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	var x_bounds:= _get_pulsar_range_x_bounds(lane_cells)
	var max_distance:= maxf(
		maxf(absf(x_bounds.x - global_position.x), absf(x_bounds.y - global_position.x)),
		1.0
	)
	return clampf(absf(target.global_position.x - global_position.x) / max_distance, 0.0, 1.0)


## 被僵尸啃食一次特殊效果,魅惑\大蒜
func _be_zombie_eat_once_special(attack_zombie:Zombie000Base):
	hypno_zombie(attack_zombie)

## 魅惑僵尸
func hypno_zombie(zombie:Zombie000Base):
	if not is_sleeping:
		SoundManager.play_character_SFX("MindControlled")
		zombie.be_hypno()
		character_death()
