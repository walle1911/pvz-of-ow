extends Node
class_name PumpkinZaryaGravityEffect

const LOCK_COUNT_META := &"pumpkin_zarya_gravity_lock_count"
const FLOAT_HEIGHT := 11.0
const FLOAT_BOB_AMPLITUDE := 2.2
const FLOAT_BOB_SPEED := 2.8
const FLOAT_LAND_DURATION := 0.18

var _zombie:Zombie000Base
var _lock_acquired := false
var _is_holding := false
var _hold_global_position := Vector2.ZERO
var _float_visual_active := false
var _float_elapsed := 0.0
var _float_phase := 0.0
var _body_base_position := Vector2.ZERO
var _shadow_base_scale := Vector2.ONE
var _shadow_base_self_modulate := Color.WHITE


func start(
	zombie:Zombie000Base,
	target_lane:int,
	target_ground_x:float,
	target_vertical_offset:float,
	start_delay:float,
	pull_duration:float,
	hold_duration:float
) -> void:
	_zombie = zombie
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay, false).timeout
	if not is_instance_valid(zombie) or zombie.is_death:
		queue_free()
		return
	_acquire_movement_lock()

	var zombie_rows:Array = Global.main_game.zombie_manager.all_zombie_rows
	if target_lane != zombie.lane:
		zombie.lane = target_lane
		zombie.signal_lane_update.emit()
		zombie.reparent(zombie_rows[target_lane], true)

	var target_global_position := zombie.global_position
	target_global_position.x += target_ground_x - zombie.shadow.global_position.x
	target_global_position.y = (
		zombie_rows[target_lane].zombie_create_position.global_position.y
		+ target_vertical_offset
	)
	var pull_tween:= create_tween()
	pull_tween.tween_property(zombie, ^"global_position", target_global_position, pull_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await pull_tween.finished

	if hold_duration > 0.0 and is_instance_valid(zombie) and not zombie.is_death:
		_hold_global_position = target_global_position
		_is_holding = true
		_start_float_visual()
		set_process(true)
		await get_tree().create_timer(hold_duration, false).timeout
	_is_holding = false
	set_process(false)
	await _stop_float_visual(true)
	_release_movement_lock()
	_resume_ground_movement()
	await _refresh_movement_after_physics()
	queue_free()


func _process(delta:float) -> void:
	if not _is_holding or not is_instance_valid(_zombie) or _zombie.is_death:
		return
	## 跳跃、特殊僵尸状态和动画轨道可能绕过 MoveComponent 直接改根节点位置。
	## 黑洞稳定存在期间每帧钉住脚点，保证僵尸确实持续聚在一起。
	_zombie.global_position = _hold_global_position
	_update_float_visual(delta)
	if not bool(_zombie.move_component.move_factors.get(
		MoveComponent.E_MoveFactor.IsPumpkinZaryaGravity,
		false
	)):
		_zombie.move_component.update_move_factor(
			true,
			MoveComponent.E_MoveFactor.IsPumpkinZaryaGravity
		)


func _start_float_visual() -> void:
	if not is_instance_valid(_zombie.body) or not is_instance_valid(_zombie.shadow):
		return
	_float_visual_active = true
	_float_elapsed = 0.0
	_float_phase = fmod(float(_zombie.get_instance_id()) * 0.173, TAU)
	_body_base_position = _zombie.body.position
	_shadow_base_scale = _zombie.shadow.scale
	_shadow_base_self_modulate = _zombie.shadow.self_modulate


func _update_float_visual(delta:float) -> void:
	if not _float_visual_active:
		return
	if not is_instance_valid(_zombie.body) or not is_instance_valid(_zombie.shadow):
		return
	_float_elapsed += delta
	var bob:float = sin(_float_elapsed * FLOAT_BOB_SPEED + _float_phase)
	_zombie.body.position = _body_base_position + Vector2(
		0.0,
		-FLOAT_HEIGHT + bob * FLOAT_BOB_AMPLITUDE
	)
	_zombie.shadow.scale = _shadow_base_scale * (0.86 - bob * 0.025)
	var shadow_modulate:= _shadow_base_self_modulate
	shadow_modulate.a *= 0.58
	_zombie.shadow.self_modulate = shadow_modulate


func _stop_float_visual(animate_landing:bool) -> void:
	if not _float_visual_active:
		return
	_float_visual_active = false
	if not is_instance_valid(_zombie):
		return
	if not is_instance_valid(_zombie.body) or not is_instance_valid(_zombie.shadow):
		return
	if animate_landing and not _zombie.is_death and _zombie.is_inside_tree():
		var landing_tween:= _zombie.body.create_tween().set_parallel()
		landing_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		landing_tween.tween_property(
			_zombie.body,
			^"position",
			_body_base_position,
			FLOAT_LAND_DURATION
		)
		landing_tween.tween_property(
			_zombie.shadow,
			^"scale",
			_shadow_base_scale,
			FLOAT_LAND_DURATION
		)
		landing_tween.tween_property(
			_zombie.shadow,
			^"self_modulate",
			_shadow_base_self_modulate,
			FLOAT_LAND_DURATION
		)
		await landing_tween.finished
		return
	_zombie.body.position = _body_base_position
	_zombie.shadow.scale = _shadow_base_scale
	_zombie.shadow.self_modulate = _shadow_base_self_modulate


func _refresh_attack_detection() -> void:
	if not is_instance_valid(_zombie) or not is_instance_valid(_zombie.attack_component):
		return
	var detect_component:DetectComponent = _zombie.attack_component.detect_component
	if not is_instance_valid(detect_component) or not detect_component.is_enabling:
		return
	## 强制位移不会可靠触发旧 Area2D 的离开事件；主动重判，清掉已经不在范围内的攻击目标。
	detect_component.judge_is_have_enemy()


func _refresh_movement_after_physics() -> void:
	if not is_inside_tree() or not is_instance_valid(_zombie) or _zombie.is_death:
		return
	## 强制位移结束的当帧，Area2D 的重叠列表仍可能保留位移前的植物。
	## 等待一次完整物理步后再重判，否则 IsAttack 会残留，表现为走路动画播放但原地不动。
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or not is_instance_valid(_zombie) or _zombie.is_death:
		return
	_refresh_attack_detection()
	_resume_ground_movement()


func _resume_ground_movement() -> void:
	if not is_instance_valid(_zombie) or not is_instance_valid(_zombie.move_component):
		return
	if not _zombie.move_component.is_move:
		return
	## 动画地面节点在定身期间仍会循环；用当前脚点重设基准，避免解除后只原地播放走路。
	_zombie.move_component.update_previous_ground_global_x()
	_zombie.move_component._walking_start()


func _acquire_movement_lock() -> void:
	if not is_instance_valid(_zombie) or _lock_acquired:
		return
	var lock_count:int = int(_zombie.get_meta(LOCK_COUNT_META, 0)) + 1
	_zombie.set_meta(LOCK_COUNT_META, lock_count)
	_zombie.move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsPumpkinZaryaGravity)
	_lock_acquired = true


func _release_movement_lock() -> void:
	if not _lock_acquired:
		return
	_lock_acquired = false
	if not is_instance_valid(_zombie):
		return
	var lock_count:int = maxi(0, int(_zombie.get_meta(LOCK_COUNT_META, 1)) - 1)
	if lock_count > 0:
		_zombie.set_meta(LOCK_COUNT_META, lock_count)
		return
	_zombie.remove_meta(LOCK_COUNT_META)
	_zombie.move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsPumpkinZaryaGravity)


func _exit_tree() -> void:
	_is_holding = false
	_stop_float_visual(false)
	_release_movement_lock()
