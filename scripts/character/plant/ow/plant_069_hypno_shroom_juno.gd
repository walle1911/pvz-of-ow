extends Plant000Base
class_name Plant069HypnoShroomJuno

const PULSAR_TORPEDO_SCENE:PackedScene = preload("res://scenes/bullet/bullet_013_juno_pulsar_torpedo.tscn")
const PULSAR_RETICLE_SCRIPT:Script = preload("res://scripts/fx/plant_effect/plant_effect_juno_pulsar_reticle.gd")
const PULSAR_BURST_SCRIPT:Script = preload("res://scripts/fx/plant_effect/plant_effect_juno_pulsar_burst.gd")

@export_group("朱诺·脉冲飞雷")
@export_range(0.1, 120.0, 0.1, "suffix:秒") var pulsar_cooldown:= 15.0
@export_range(0.1, 3.0, 0.05, "suffix:秒") var pulsar_second_jump_ascent_time:= 0.55
@export_range(0.05, 1.0, 0.05, "suffix:秒") var pulsar_fire_delay:= 0.18
@export_range(1, 12, 1) var pulsar_max_targets:= 12
@export_range(1, 500, 1, "suffix:伤害") var pulsar_damage:= 80
@export_range(1, 9, 1, "suffix:列") var pulsar_column_count:= 2
@export_range(0.05, 3.0, 0.05, "suffix:秒") var pulsar_initial_delay:= 0.6
@export_group("朱诺·二段跳")
@export_range(1.0, 60.0, 0.5, "suffix:像素") var pulsar_first_jump_height:= 32.0
@export_range(0.5, 0.95, 0.01) var pulsar_first_jump_trigger_ratio:= 0.82
@export_range(0.02, 0.3, 0.01, "suffix:秒") var pulsar_charge_hold_duration:= 0.07
@export_range(0.05, 0.5, 0.01, "suffix:秒") var pulsar_charge_duration:= 0.12
@export_range(0.7, 1.0, 0.01) var pulsar_charge_scale_y:= 0.82
@export_range(1.0, 1.2, 0.01) var pulsar_charge_scale_x:= 1.08
@export_range(10.0, 120.0, 1.0, "suffix:像素") var pulsar_second_jump_height:= 64.0
@export_range(0.1, 2.0, 0.05, "suffix:秒") var pulsar_descent_time:= 0.45

enum E_PulsarPhase {
	Idle,
	FirstJump,
	SecondJumpAscent,
	ApexHold,
	Descent,
}

var _pulsar_cooldown_remaining:= 0.0
var _pulsar_is_targeting:= false
var _pulsar_phase:= E_PulsarPhase.Idle
var _pulsar_phase_elapsed:= 0.0
var _pulsar_body_rest_position:= Vector2.ZERO
var _pulsar_body_rest_scale:= Vector2.ONE
var _pulsar_bite_invulnerable:= false
var _pulsar_targets:Array[Zombie000Base] = []
var _pulsar_lock_elapsed:Dictionary[int, float] = {}
var _pulsar_locked:Dictionary[int, bool] = {}
var _pulsar_reticles:Dictionary[int, Node2D] = {}


func ready_norm_signal_connect():
	super()
	signal_character_death.connect(_cleanup_pulsar_targeting)
	_pulsar_cooldown_remaining = pulsar_initial_delay
	_pulsar_body_rest_position = body.position
	_pulsar_body_rest_scale = body.scale


func _physics_process(delta:float) -> void:
	if character_init_type != E_CharacterInitType.IsNorm or is_death:
		return
	if is_sleeping:
		if _pulsar_is_targeting:
			_cancel_pulsar_targeting()
		return
	if _pulsar_is_targeting:
		## 冷却从技能起跳时开始，动作期间也正常流逝，保证两次触发间隔使用配置值。
		_pulsar_cooldown_remaining = maxf(_pulsar_cooldown_remaining - delta, 0.0)
		_update_pulsar_targeting(delta)
		return
	_pulsar_cooldown_remaining = maxf(_pulsar_cooldown_remaining - delta, 0.0)
	if _pulsar_cooldown_remaining <= 0.0:
		var candidates:= _get_zombies_in_pulsar_range()
		if not candidates.is_empty():
			_begin_pulsar_targeting(candidates)


func _begin_pulsar_targeting(candidates:Array[Zombie000Base]) -> void:
	_pulsar_is_targeting = true
	## 从一段离地到二段完整落地前，啃咬不会造成伤害或触发蛊惑。
	_pulsar_bite_invulnerable = true
	_pulsar_phase = E_PulsarPhase.FirstJump
	_pulsar_phase_elapsed = 0.0
	_pulsar_cooldown_remaining = pulsar_cooldown
	_clear_pulsar_targets()
	for target:Zombie000Base in candidates:
		if _pulsar_targets.size() >= pulsar_max_targets:
			break
		_pulsar_targets.append(target)
	_spawn_pulsar_burst(global_position + Vector2(0.0, -48.0), false)


func _update_pulsar_targeting(delta:float) -> void:
	_prune_pulsar_targets()
	## 已经发射后即使目标死亡，也要完整播完下落着地。
	if _pulsar_targets.is_empty() and _pulsar_phase != E_PulsarPhase.Descent:
		_cancel_pulsar_targeting()
		return
	_pulsar_phase_elapsed += delta
	match _pulsar_phase:
		E_PulsarPhase.FirstJump:
			_update_first_jump()
		E_PulsarPhase.SecondJumpAscent:
			_update_second_jump_ascent(delta)
		E_PulsarPhase.ApexHold:
			_update_apex_hold()
		E_PulsarPhase.Descent:
			_update_descent()


func _update_first_jump() -> void:
	var first_jump_duration:= _get_pulsar_first_jump_duration()
	var jump_motion:= _get_pulsar_jump_motion()
	var elapsed:= minf(_pulsar_phase_elapsed, first_jump_duration)
	var progress:= clampf(elapsed / first_jump_duration, 0.0, 1.0)
	## 一段与二段使用同一组起跳初速度和重力；一段尚在上升时触发第二次冲量。
	_set_pulsar_body_height(_get_pulsar_ballistic_height(elapsed, jump_motion))
	## 前 35% 保持原形，随后快速压下，最后 30% 上升路程保持完整压缩，避免峰值只出现一帧。
	var charge_progress:= clampf((progress - 0.35) / 0.35, 0.0, 1.0)
	_set_pulsar_body_scale(Vector2(
		lerpf(1.0, pulsar_charge_scale_x, charge_progress),
		lerpf(1.0, pulsar_charge_scale_y, charge_progress)
	))
	if _pulsar_phase_elapsed < first_jump_duration:
		return
	var phase_overshoot:= maxf(_pulsar_phase_elapsed - first_jump_duration, 0.0)
	_set_pulsar_body_height(_get_pulsar_first_jump_transition_height())
	_pulsar_phase = E_PulsarPhase.SecondJumpAscent
	_pulsar_phase_elapsed = phase_overshoot
	for target:Zombie000Base in _pulsar_targets:
		_add_pulsar_target_lock(target)
	if phase_overshoot > 0.0:
		_update_second_jump_ascent(phase_overshoot)


func _update_second_jump_ascent(delta:float) -> void:
	var ascent_time:= maxf(pulsar_second_jump_ascent_time, 0.001)
	var elapsed:= minf(_pulsar_phase_elapsed, ascent_time)
	var progress:= clampf(elapsed / ascent_time, 0.0, 1.0)
	var jump_motion:= _get_pulsar_jump_motion()
	## 二段立即重置为与一段完全相同的向上初速度，随后受同样的重力自然减速到顶点。
	_set_pulsar_body_height(
		_get_pulsar_first_jump_transition_height() + _get_pulsar_ballistic_height(elapsed, jump_motion)
	)
	## 二段开始后仍在上升中保持 0.07 秒完整压缩，然后快速弹到小幅拉伸再回正。
	var release_progress:= clampf(
		(_pulsar_phase_elapsed - pulsar_charge_hold_duration) / maxf(pulsar_charge_duration, 0.001),
		0.0,
		1.0
	)
	if release_progress < 0.55:
		var stretch_progress:= release_progress / 0.55
		_set_pulsar_body_scale(Vector2(
			lerpf(pulsar_charge_scale_x, 0.97, stretch_progress),
			lerpf(pulsar_charge_scale_y, 1.06, stretch_progress)
		))
	else:
		var settle_progress:= (release_progress - 0.55) / 0.45
		_set_pulsar_body_scale(Vector2(
			lerpf(0.97, 1.0, settle_progress),
			lerpf(1.06, 1.0, settle_progress)
		))
	for target:Zombie000Base in _pulsar_targets:
		if not is_instance_valid(target):
			continue
		var target_id:= target.get_instance_id()
		_pulsar_lock_elapsed[target_id] = minf(
			_pulsar_lock_elapsed.get(target_id, 0.0) + delta,
			ascent_time
		)
		var lock_progress:float = _pulsar_lock_elapsed[target_id] / ascent_time
		var reticle:= _pulsar_reticles.get(target_id) as Node2D
		if is_instance_valid(reticle):
			reticle.call(&"set_lock_progress", lock_progress)
			reticle.call(&"set_tracking_active", true)
	if progress < 1.0:
		return
	## 二段跳到达最高点的同一帧，所有有效目标完成锁定。
	for target:Zombie000Base in _pulsar_targets:
		if is_instance_valid(target):
			_pulsar_locked[target.get_instance_id()] = true
	_set_pulsar_body_scale(Vector2.ONE)
	var phase_overshoot:= maxf(_pulsar_phase_elapsed - ascent_time, 0.0)
	_pulsar_phase = E_PulsarPhase.ApexHold
	_pulsar_phase_elapsed = phase_overshoot


## x 为两段起跳共用的向上初速度，y 为共用重力。
## 二段到顶时间就是锁定时间，因此用它反推两个物理量。
func _get_pulsar_jump_motion() -> Vector2:
	var ascent_time:= maxf(pulsar_second_jump_ascent_time, 0.001)
	var second_jump_rise:= maxf(pulsar_second_jump_height - pulsar_first_jump_height, 1.0)
	var initial_speed:= 2.0 * second_jump_rise / ascent_time
	var gravity:= initial_speed / ascent_time
	return Vector2(initial_speed, gravity)


func _get_pulsar_ballistic_height(elapsed:float, jump_motion:Vector2) -> float:
	return jump_motion.x * elapsed - 0.5 * jump_motion.y * elapsed * elapsed


func _get_pulsar_first_jump_duration() -> float:
	return maxf(
		pulsar_second_jump_ascent_time * pulsar_first_jump_trigger_ratio,
		0.001
	)


func _get_pulsar_first_jump_transition_height() -> float:
	return _get_pulsar_ballistic_height(
		_get_pulsar_first_jump_duration(),
		_get_pulsar_jump_motion()
	)


func _get_pulsar_second_jump_apex_height() -> float:
	var jump_motion:= _get_pulsar_jump_motion()
	return _get_pulsar_first_jump_transition_height() + _get_pulsar_ballistic_height(
		pulsar_second_jump_ascent_time,
		jump_motion
	)


func _update_apex_hold() -> void:
	_set_pulsar_body_height(_get_pulsar_second_jump_apex_height())
	if _pulsar_phase_elapsed < pulsar_fire_delay:
		return
	_fire_pulsar_torpedoes()
	_pulsar_phase = E_PulsarPhase.Descent
	_pulsar_phase_elapsed = 0.0


func _update_descent() -> void:
	var progress:= clampf(_pulsar_phase_elapsed / maxf(pulsar_descent_time, 0.001), 0.0, 1.0)
	_set_pulsar_body_height((1.0 - ease(progress, 1.8)) * _get_pulsar_second_jump_apex_height())
	if progress < 1.0:
		return
	_finish_pulsar_action()


func _set_pulsar_body_height(height:float) -> void:
	if is_instance_valid(body):
		body.position = _pulsar_body_rest_position + Vector2.UP * height


func _set_pulsar_body_scale(scale_factor:Vector2) -> void:
	if is_instance_valid(body):
		body.scale = _pulsar_body_rest_scale * scale_factor


func _add_pulsar_target_lock(target:Zombie000Base) -> void:
	if not is_instance_valid(target) or target.is_death or target.is_hypno:
		return
	var target_id:= target.get_instance_id()
	_pulsar_lock_elapsed[target_id] = 0.0
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
	var locked_targets:Array[Zombie000Base] = []
	for target:Zombie000Base in _pulsar_targets:
		if not is_instance_valid(target) or target.is_death:
			continue
		if _pulsar_locked.get(target.get_instance_id(), false):
			locked_targets.append(target)
	## 根节点与碰撞仍留在种植格；发射点单独补上可视身体的跳跃高度。
	var launch_position:= global_position + Vector2(
		float(direction_x_root) * 5.0,
		-55.0 - _get_pulsar_second_jump_apex_height()
	)
	_spawn_pulsar_burst(launch_position, true)
	for target_index in locked_targets.size():
		_spawn_pulsar_torpedo(locked_targets[target_index], target_index, locked_targets.size(), launch_position)
	_release_pulsar_reticles()


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
	## 飞雷会先沿这个扇面短暂出膛；相邻角度必须足够大，密集目标下才能看清
	## 每个锁定框确实各自发射了一颗。
	var spread_offset:= (float(target_index) - spread_center) * 0.28
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
	_pulsar_bite_invulnerable = false
	_pulsar_phase = E_PulsarPhase.Idle
	_pulsar_phase_elapsed = 0.0
	_set_pulsar_body_height(0.0)
	_set_pulsar_body_scale(Vector2.ONE)
	_clear_pulsar_targets()


func _cleanup_pulsar_targeting() -> void:
	_pulsar_is_targeting = false
	_pulsar_bite_invulnerable = false
	_pulsar_phase = E_PulsarPhase.Idle
	_pulsar_phase_elapsed = 0.0
	_set_pulsar_body_height(0.0)
	_set_pulsar_body_scale(Vector2.ONE)
	_clear_pulsar_targets()


func _finish_pulsar_action() -> void:
	_pulsar_is_targeting = false
	_pulsar_bite_invulnerable = false
	_pulsar_phase = E_PulsarPhase.Idle
	_pulsar_phase_elapsed = 0.0
	_set_pulsar_body_height(0.0)
	_set_pulsar_body_scale(Vector2.ONE)
	_clear_pulsar_target_data()


func _clear_pulsar_targets() -> void:
	for reticle:Node2D in _pulsar_reticles.values():
		if is_instance_valid(reticle):
			reticle.queue_free()
	_pulsar_reticles.clear()
	_clear_pulsar_target_data()


func _clear_pulsar_target_data() -> void:
	_pulsar_targets.clear()
	_pulsar_lock_elapsed.clear()
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

## 被僵尸啃食一次特殊效果,魅惑\大蒜
func _be_zombie_eat_once_special(attack_zombie:Zombie000Base):
	hypno_zombie(attack_zombie)


## 技能跳跃期间只屏蔽僵尸啃咬，不扩大为其他伤害免疫。
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	if _pulsar_bite_invulnerable:
		return
	super(attack_value, attack_zombie)


func be_zombie_eat_once(attack_zombie:Zombie000Base):
	if _pulsar_bite_invulnerable:
		return
	super(attack_zombie)

## 魅惑僵尸
func hypno_zombie(zombie:Zombie000Base):
	if not is_sleeping:
		SoundManager.play_character_SFX("MindControlled")
		zombie.be_hypno()
		character_death()
