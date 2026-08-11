extends Node
class_name SombraEmpConfusion

## 黑影磁力菇 EMP 的临时、可逆魅惑状态。
## 不修改 Zombie000Base.is_hypno，避免永久魅惑流程破坏波次和死亡统计。

const HYPNO_DETECTION_LAYER := 32
const HYPNO_REAL_LAYER := 1024
const EMP_MARK_TEXTURE := preload("res://resources/character_resource/sombra_emp_skull.png")
const EMP_MARK_POSITION := Vector2(0.0, -66.0)
const EMP_MARK_SCALE := Vector2.ONE * 0.92
const EMP_MARK_GROW_DURATION := 0.25
const EMP_MARK_FADE_DURATION := 0.45

var zombie:Zombie000Base
var switch_interval := 0.8
var switch_interval_randomness := 0.25
var turn_reaction_duration := 0.35
## -1：原有的来回混乱；0：保持普通阵营向左；1：保持临时魅惑阵营向右。
var fight_side := -1
var fight_target:Zombie000Base
var _generation := 0
var _is_temp_hypno := false
var _is_holding_grossout := false
var _normal_detection_layer := 4
var _normal_real_layer := 512
var _emp_mark_root:Node2D


func apply_to(
	target:Zombie000Base,
	duration:float,
	new_switch_interval:float,
	new_switch_interval_randomness:float,
	new_turn_reaction_duration:float,
	new_fight_side:int = -1,
	new_fight_target:Zombie000Base = null
) -> void:
	if not is_instance_valid(zombie):
		var initial_hurt_box := target.hurt_box_component as HurtBoxComponentZombie
		if is_instance_valid(initial_hurt_box):
			_normal_detection_layer = initial_hurt_box.hurt_box_detection.collision_layer
			_normal_real_layer = initial_hurt_box.hurt_box_real.collision_layer
	zombie = target
	fight_side = new_fight_side
	fight_target = new_fight_target
	_show_emp_mark_once()
	if not _is_holding_grossout:
		zombie.hold_garlic_grossout_face()
		_is_holding_grossout = true
	switch_interval = maxf(new_switch_interval, 0.2)
	switch_interval_randomness = maxf(new_switch_interval_randomness, 0.0)
	turn_reaction_duration = maxf(new_turn_reaction_duration, 0.0)
	_generation += 1
	_run(_generation, maxf(duration, 0.0))

func _show_emp_mark_once() -> void:
	if not is_instance_valid(zombie):
		return
	_release_emp_mark()
	_emp_mark_root = Node2D.new()
	_emp_mark_root.name = "SombraEmpMark"
	_emp_mark_root.position = EMP_MARK_POSITION
	## 覆盖角色身体，但保留 z=10 的血条在最上层。
	_emp_mark_root.z_index = 9
	zombie.add_child(_emp_mark_root)

	var sprite := Sprite2D.new()
	sprite.name = "Mark"
	sprite.texture = EMP_MARK_TEXTURE
	sprite.scale = Vector2.ZERO
	sprite.modulate.a = 0.0
	_emp_mark_root.add_child(sprite)

	var tween := sprite.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, ^"scale", EMP_MARK_SCALE, EMP_MARK_GROW_DURATION)
	tween.parallel().tween_property(sprite, ^"modulate:a", 1.0, EMP_MARK_GROW_DURATION * 0.6)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, ^"scale", EMP_MARK_SCALE * 1.12, EMP_MARK_FADE_DURATION)
	tween.parallel().tween_property(sprite, ^"modulate:a", 0.0, EMP_MARK_FADE_DURATION)
	tween.tween_callback(_release_emp_mark)


func _release_emp_mark() -> void:
	if is_instance_valid(_emp_mark_root):
		_emp_mark_root.queue_free()
	_emp_mark_root = null


func _run(generation:int, duration:float) -> void:
	var end_time := Time.get_ticks_msec() * 0.001 + duration
	if fight_side >= 0:
		## 成对目标分别站到两个阵营，并朝彼此靠近后互相攻击。
		_set_temp_hypno(fight_side == 1)
		while _get_remaining_time(end_time) > 0.0:
			if not _can_continue(generation):
				return
			if not is_instance_valid(fight_target) or fight_target.is_death:
				fight_side = -1
				break
			await get_tree().create_timer(
				minf(0.1, _get_remaining_time(end_time)), false
			).timeout
		if fight_side >= 0:
			_finish_effect()
			return

	## 没有近邻，或配对对象提前死亡时，延续原有的来回转向逻辑。
	_set_temp_hypno(false)
	while _get_remaining_time(end_time) > 0.0:
		## 每只僵尸、每一次转向都独立取样，让同批目标的动作自然错开。
		var min_interval := maxf(0.2, switch_interval - switch_interval_randomness)
		var max_interval := maxf(min_interval, switch_interval + switch_interval_randomness)
		var random_interval := randf_range(min_interval, max_interval)
		var wait_before_turn := minf(random_interval, _get_remaining_time(end_time))
		await get_tree().create_timer(wait_before_turn, false).timeout
		if not _can_continue(generation):
			return
		var remaining := _get_remaining_time(end_time)
		## 剩余时间不足以完成整段表情过渡时不再转向，直接等待最终恢复。
		if remaining <= turn_reaction_duration:
			if remaining > 0.0:
				await get_tree().create_timer(remaining, false).timeout
			break

		## 全程嫌恶脸下短暂停步翻面；EMP 不重复播放大蒜音效。
		zombie.play_garlic_reaction(turn_reaction_duration, true, false)
		var before_turn := turn_reaction_duration * 0.5
		await get_tree().create_timer(before_turn, false).timeout
		if not _can_continue(generation):
			return
		_set_temp_hypno(not _is_temp_hypno)
		var after_turn := turn_reaction_duration - before_turn
		if after_turn > 0.0:
			await get_tree().create_timer(after_turn, false).timeout
			if not _can_continue(generation):
				return

	_finish_effect()


func _finish_effect() -> void:
	## 无论最后一个阶段是什么，EMP 结束时必定回到正常向左状态。
	_set_temp_hypno(false)
	_release_grossout()
	_release_emp_mark()
	queue_free()


func _get_remaining_time(end_time:float) -> float:
	return maxf(0.0, end_time - Time.get_ticks_msec() * 0.001)


func _can_continue(generation:int) -> bool:
	if generation != _generation:
		return false
	if not is_instance_valid(zombie) or zombie.is_death:
		_release_grossout()
		_release_emp_mark()
		queue_free()
		return false
	## 外部永久魅惑优先，不能在 EMP 结束时把它错误恢复为普通僵尸。
	if zombie.is_hypno:
		_release_grossout()
		_release_emp_mark()
		queue_free()
		return false
	return true


func _release_grossout() -> void:
	if not _is_holding_grossout:
		return
	_is_holding_grossout = false
	if is_instance_valid(zombie):
		zombie.release_garlic_grossout_face()


func _set_temp_hypno(value:bool) -> void:
	if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
		return
	_is_temp_hypno = value
	zombie.update_direction_x_root(-1 if value else 1)
	zombie.body.set_other_color(
		BodyCharacter.E_ChangeColors.HypnoColor,
		Color(1.0, 0.5, 1.0) if value else Color.WHITE
	)

	var hurt_box := zombie.hurt_box_component as HurtBoxComponentZombie
	if is_instance_valid(hurt_box):
		hurt_box.hurt_box_detection.collision_layer = HYPNO_DETECTION_LAYER if value else _normal_detection_layer
		hurt_box.hurt_box_real.collision_layer = HYPNO_REAL_LAYER if value else _normal_real_layer
		## 强制刷新 monitorable，使同帧阵营变化立即被检测组件感知。
		hurt_box.hurt_box_detection_on_attack.monitoring = not hurt_box.hurt_box_detection_on_attack.monitoring
		hurt_box.hurt_box_detection_on_attack.monitoring = not hurt_box.hurt_box_detection_on_attack.monitoring

	if is_instance_valid(zombie.attack_component) and is_instance_valid(zombie.attack_component.detect_component):
		zombie.attack_component.detect_component.update_curr_collision_lay(1 if value else 2)
		zombie.attack_component.detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.Hypno)
		zombie.attack_component.detect_component.enable_component(ComponentNormBase.E_IsEnableFactor.Hypno)
	zombie.move_component._walking_start()
