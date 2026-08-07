extends Plant027Cactus
class_name Plant027CactusCassidy

const CASSIDY_SKILL_BULLET_SCENE:PackedScene = preload("res://scenes/bullet/bullet_027_cactus_cassidy_skill.tscn")
const CASSIDY_RETICLE_SCRIPT:Script = preload("res://scripts/fx/plant_effect/plant_effect_cassidy_deadeye_reticle.gd")
const TUMBLEWEED_TEXTURE:Texture2D = preload("res://assets/reanim/Cactus_Cassidy_tumbleweed.png")
const FLASHBANG_TEXTURE:Texture2D = preload("res://assets/reanim/Cactus_Cassidy_flare.png")
const MAX_CHARGE_DURATION:= 6.0
const CHARGE_DAMAGE_CAP_PER_SECOND:= 8.0
const SKILL_RISE_SPEED_MULTIPLIER:= 1.15
const TRAPPED_FAN_BULLET_COUNT:= 6
const TRAPPED_FAN_SPREAD_RADIANS:= 0.2094395
const TRAPPED_SHORT_ROLL_DISTANCE:= 22.0

@onready var flare:Sprite2D = $Body/BodyCorrect/flare
@onready var flare_remote_transform:RemoteTransform2D = $Body/BodyCorrect/Anim_face/RemoteTransform2D

@export_group("Cassidy 蓄力技能")
@export_range(0.1, 30.0, 0.1, "suffix:秒") var charge_time:= 4.0
@export_range(1, 10000, 1, "suffix:血") var charge_reference_hp:= 250
@export_range(0.1, 10.0, 0.1, "or_greater", "suffix:倍") var lock_speed_multiplier:= 1.5
@export_range(1, 5000, 1, "suffix:血") var skill_trigger_hp:= 50
@export_range(1, 9, 1) var skill_column_count:= 2
@export_range(0.05, 1.0, 0.05, "suffix:秒") var locked_fire_delay:= 0.3
@export_range(0.0, 2.0, 0.05, "suffix:秒") var charged_icon_hold_time:= 0.25
@export_range(0.05, 2.0, 0.05, "suffix:秒") var backstep_duration:= 0.25
@export_range(0.25, 3.0, 0.25, "suffix:圈") var backstep_roll_turns:= 1.0
@export_range(0.1, 5.0, 0.05, "suffix:秒") var trapped_flashbang_stun_time:= 1.25
@export_range(1.0, 1000.0, 1.0, "suffix:像素") var trapped_flashbang_front_range:= 520.0

var _skill_has_triggered:= false
var _skill_is_pending_rise:= false
var _skill_is_charging:= false
var _skill_forces_rise:= false
var _skill_is_invulnerable:= false
var _skill_roll_finished:= false
var _skill_rise_finished:= false
var _skill_rise_original_anim_speed:= 1.0
var _skill_rise_speed_is_boosted:= false
var _charge_elapsed:= 0.0
var _charge_total_duration:= 0.0
var _charge_damage_cap_elapsed:= 0.0
var _charge_damage_cap_is_active:= false
var _charge_capped_damage_taken:= 0
var _locked_targets:Array[Zombie000Base] = []
var _target_charge_durations:Dictionary[int, float] = {}
var _target_charge_started_at:Dictionary[int, float] = {}
var _target_lock_completed:Dictionary[int, bool] = {}
var _target_reticles:Dictionary[int, Node2D] = {}
var _locked_fire_countdown:= -1.0
var _flare_remote_final_scale:= Vector2.ONE
var _tumbleweed:Sprite2D
var _tumbleweed_move_tween:Tween
var _tumbleweed_bob_tween:Tween
var _backstep_tween:Tween
var _trapped_burst_tween:Tween
var _backstep_body_position:= Vector2.ZERO
var _backstep_body_rotation:= 0.0
var _backstep_body_scale:= Vector2.ONE
var _backstep_roll_pivot:= Vector2.ZERO
var _backstep_roll_direction:= -1.0


func ready_norm_signal_connect():
	super()
	hp_component.signal_hp_loss.connect(_on_hp_loss_for_charge)
	## 原版仙人掌先更新气球状态，卡西迪随后叠加技能的强制升高状态。
	attack_component.signal_change_is_attack.connect(_refresh_cassidy_rise)
	signal_character_death.connect(_defer_charge_cleanup_on_death)
	_flare_remote_final_scale = flare_remote_transform.scale
	flare.visible = false
	flare_remote_transform.scale = Vector2.ZERO


func _physics_process(delta:float) -> void:
	if character_init_type != E_CharacterInitType.IsNorm or is_death:
		return
	if _charge_damage_cap_is_active:
		_charge_damage_cap_elapsed += delta
	if not _skill_is_charging:
		return
	_charge_elapsed += delta
	## 索敌窗口从翻滚完成后的蓄力阶段才开始；翻滚前的重叠对象不会进入锁定列表。
	_scan_for_new_targets()
	_update_flare_charge_scale()
	_update_target_reticles()
	if _are_all_targets_locked():
		if _locked_fire_countdown < 0.0:
			_locked_fire_countdown = locked_fire_delay
		else:
			_locked_fire_countdown -= delta
			if _locked_fire_countdown <= 0.0:
				_fire_charged_shots()
	else:
		_locked_fire_countdown = -1.0


func anim_rise_end():
	super()
	_restore_skill_rise_animation_speed()
	if _skill_is_pending_rise and not is_death:
		_skill_rise_finished = true
		_try_begin_charge_after_intro()


func _start_skill() -> void:
	_skill_is_pending_rise = true
	_skill_roll_finished = false
	_skill_rise_finished = is_rise
	_clear_locked_targets()
	_set_skill_invulnerable(true)
	if not _try_roll_for_charge():
		## 左、右、后方都被植物堵住时，先扔闪光弹，再在原格内短后滚并释放六发。
		_throw_flashbang(trapped_flashbang_stun_time)
		attack_component.update_is_attack_factors(false, AttackComponentBase.E_IsAttackFactors.Character)
		_start_trapped_short_roll()
		return
	## 蓄力优先于普通气球攻击；检测组件保持工作，释放后可立即恢复攻击气球。
	attack_component.update_is_attack_factors(false, AttackComponentBase.E_IsAttackFactors.Character)
	if _skill_roll_finished:
		_start_forced_rise_after_roll()


func _start_forced_rise_after_roll() -> void:
	if _skill_forces_rise or not _skill_is_pending_rise or is_death:
		return
	## 后滚结束、进入生长时立刻取消无敌，并开始覆盖生长与完整蓄力过程的伤害上限。
	_set_skill_invulnerable(false)
	_start_charge_damage_cap()
	if not _skill_rise_finished:
		_boost_skill_rise_animation_speed()
	_skill_forces_rise = true
	_refresh_cassidy_rise(false)
	## 翻滚和升起动画都结束后才正式开始锁定；伤害上限已从生长起始覆盖。
	_try_begin_charge_after_intro()


func _boost_skill_rise_animation_speed() -> void:
	if _skill_rise_speed_is_boosted:
		return
	var norm_anim_component:= anim_component as AnimComponentNorm
	if not is_instance_valid(norm_anim_component):
		return
	var speed_path:= &"parameters/TimeScale/scale"
	_skill_rise_original_anim_speed = float(norm_anim_component.animation_tree.get(speed_path))
	norm_anim_component.animation_tree.set(
		speed_path,
		_skill_rise_original_anim_speed * SKILL_RISE_SPEED_MULTIPLIER
	)
	_skill_rise_speed_is_boosted = true


func _restore_skill_rise_animation_speed() -> void:
	if not _skill_rise_speed_is_boosted:
		return
	var norm_anim_component:= anim_component as AnimComponentNorm
	if not is_instance_valid(norm_anim_component):
		_skill_rise_speed_is_boosted = false
		return
	norm_anim_component.animation_tree.set(
		&"parameters/TimeScale/scale",
		_skill_rise_original_anim_speed
	)
	_skill_rise_speed_is_boosted = false


func _try_begin_charge_after_intro() -> void:
	if not _skill_is_pending_rise or is_death:
		return
	if not _skill_roll_finished or not _skill_rise_finished:
		return
	_begin_charge()


func _begin_charge() -> void:
	_skill_is_pending_rise = false
	_skill_is_charging = true
	_charge_elapsed = 0.0
	if not _charge_damage_cap_is_active:
		_start_charge_damage_cap()
	_locked_fire_countdown = -1.0
	_charge_total_duration = minf(
		charge_time / maxf(lock_speed_multiplier, 0.001),
		MAX_CHARGE_DURATION
	)
	_start_charge_visuals()
	## 此时翻滚和升起前置动作均已结束，只收录翻滚后仍在检测区域内的敌人。
	_scan_for_new_targets()


func _try_roll_for_charge() -> bool:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return false
	var all_plant_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_plant_cells.size():
		return false

	var target_cell:PlantCell
	var back_column:= row_col.y - direction_x_root
	var lane_cells:Array = all_plant_cells[row_col.x]
	if back_column >= 0 and back_column < lane_cells.size():
		var back_cell := lane_cells[back_column] as PlantCell
		if _can_roll_into_cell(back_cell):
			target_cell = back_cell

	## 身后被堵时改为向同列的上/下相邻行翻滚；两边都空时随机选一边。
	if target_cell == null:
		var side_cells:Array[PlantCell] = []
		for target_lane in [row_col.x - 1, row_col.x + 1]:
			if target_lane < 0 or target_lane >= all_plant_cells.size():
				continue
			var target_lane_cells:Array = all_plant_cells[target_lane]
			if row_col.y < 0 or row_col.y >= target_lane_cells.size():
				continue
			var side_cell := target_lane_cells[row_col.y] as PlantCell
			if _can_roll_into_cell(side_cell):
				side_cells.append(side_cell)
		if not side_cells.is_empty():
			target_cell = side_cells.pick_random()
	if target_cell == null:
		return false

	_move_to_roll_cell(target_cell)
	return true


func _can_roll_into_cell(target_cell:PlantCell) -> bool:
	if not is_instance_valid(target_cell):
		return false
	## 后退只进入完整空格，避免覆盖花盆、睡莲或其他位置的植物。
	if target_cell.get_curr_plant_num() > 0:
		return false
	var plant_condition:ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	return is_instance_valid(plant_condition) and plant_condition.judge_is_can_plant(target_cell, plant_type)


func _move_to_roll_cell(target_cell:PlantCell) -> void:
	var plant_condition:ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)

	var place:= plant_condition.place_plant_in_cell
	var old_cell:= plant_cell
	if old_cell.plant_in_cell.get(place) == self:
		old_cell.plant_in_cell[place] = null
	target_cell.plant_in_cell[place] = self
	plant_cell = target_cell
	row_col = target_cell.row_col
	lane = target_cell.row_col.x

	var target_parent:Node = target_cell.plant_container_node[place]
	reparent(target_parent, true)
	GlobalUtils.update_plant_cell_slope_y_array(plant_cell, node2d_detect_in_slope)
	if is_instance_valid(_backstep_tween):
		_backstep_tween.kill()
	_prepare_backstep_roll()
	_backstep_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_backstep_tween.tween_property(self, ^"global_position", target_parent.global_position, backstep_duration)
	_backstep_tween.tween_method(_update_backstep_roll_visual, 0.0, 1.0, backstep_duration)
	_backstep_tween.chain()
	_backstep_tween.tween_callback(_finish_backstep_roll)


func _start_trapped_short_roll() -> void:
	if not is_instance_valid(plant_cell):
		_finish_trapped_short_roll_and_fire()
		return
	if is_instance_valid(_backstep_tween):
		_backstep_tween.kill()
	_prepare_backstep_roll()
	## 植物根节点仍留在原格容器中；最多只偏移格子宽度的四分之一。
	var max_local_offset:= maxf(plant_cell.size.x * 0.25, 0.0)
	var target_local_x:= clampf(
		position.x - float(direction_x_root) * TRAPPED_SHORT_ROLL_DISTANCE,
		-max_local_offset,
		max_local_offset
	)
	var target_local_position:= Vector2(target_local_x, position.y)
	_backstep_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_backstep_tween.tween_property(self, ^"position", target_local_position, backstep_duration)
	_backstep_tween.tween_method(_update_backstep_roll_visual, 0.0, 1.0, backstep_duration)
	_backstep_tween.chain()
	_backstep_tween.tween_callback(_finish_trapped_short_roll_and_fire)


func _finish_trapped_short_roll_and_fire() -> void:
	body.position = _backstep_body_position
	body.rotation = _backstep_body_rotation
	body.scale = _backstep_body_scale
	_set_skill_invulnerable(false)
	_start_trapped_fan_burst()


func _finish_trapped_fan_burst() -> void:
	_trapped_burst_tween = null
	_skill_is_pending_rise = false
	_skill_roll_finished = false
	_skill_rise_finished = false
	if not is_death:
		attack_component.update_is_attack_factors(true, AttackComponentBase.E_IsAttackFactors.Character)


func _throw_flashbang(stun_time:= trapped_flashbang_stun_time) -> void:
	## 闪光弹挂到主场景，保证麦克雷后续状态变化不会中断投掷视觉。
	if is_instance_valid(Global.main_game):
		var flashbang := Sprite2D.new()
		flashbang.name = "CassidyLastFlashbang"
		flashbang.texture = FLASHBANG_TEXTURE
		flashbang.global_position = global_position + Vector2(0.0, -48.0)
		flashbang.scale = Vector2.ONE * 0.45
		flashbang.z_index = 30
		Global.main_game.add_child(flashbang)
		var throw_direction := float(direction_x_root)
		var flashbang_tween := flashbang.create_tween().set_parallel()
		flashbang_tween.tween_property(
			flashbang,
			^"global_position",
			flashbang.global_position + Vector2(90.0 * throw_direction, -18.0),
			0.2
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flashbang_tween.tween_property(flashbang, ^"rotation", TAU, 0.2)
		flashbang_tween.tween_property(flashbang, ^"modulate:a", 0.0, 0.28).set_delay(0.12)
		flashbang_tween.chain().tween_callback(flashbang.queue_free)
	_stun_nearest_zombie_with_flashbang(stun_time)


func _start_trapped_fan_burst() -> void:
	if not is_instance_valid(Global.main_game) or attack_component.markers_2d_bullet.is_empty():
		_finish_trapped_fan_burst()
		return
	if is_instance_valid(_trapped_burst_tween):
		_trapped_burst_tween.kill()
	_trapped_burst_tween = create_tween()
	## 始终保持：闪光弹定身时间 = 短翻滚时间 + 六连发总时间。
	var burst_duration:= maxf(trapped_flashbang_stun_time - backstep_duration, 0.0)
	var shot_interval:= burst_duration / float(TRAPPED_FAN_BULLET_COUNT - 1)
	for shot_index in TRAPPED_FAN_BULLET_COUNT:
		_trapped_burst_tween.tween_callback(_fire_trapped_fan_shot.bind(shot_index))
		if shot_index < TRAPPED_FAN_BULLET_COUNT - 1:
			_trapped_burst_tween.tween_interval(shot_interval)
	_trapped_burst_tween.tween_callback(_finish_trapped_fan_burst)


func _fire_trapped_fan_shot(shot_index:int) -> void:
	if is_death or not is_instance_valid(Global.main_game) or attack_component.markers_2d_bullet.is_empty():
		return
	var marker:= attack_component.markers_2d_bullet[0]
	var base_direction:= Vector2(float(direction_x_root), 0.0)
	var shot_ratio:= float(shot_index) / float(TRAPPED_FAN_BULLET_COUNT - 1)
	var shot_angle:= lerpf(
		-TRAPPED_FAN_SPREAD_RADIANS * 0.5,
		TRAPPED_FAN_SPREAD_RADIANS * 0.5,
		shot_ratio
	)
	var bullet:= Global.bullet_registry.get_bullet_scenes(
		attack_component.attack_bullet_type
	).instantiate() as Bullet000Base
	if not is_instance_valid(bullet):
		return
	mark_bullet_recording_source(bullet)
	var bullet_paras:= attack_component.get_bullet_paras(
		marker.global_position,
		base_direction.rotated(shot_angle)
	)
	attack_component._apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
	bullet.init_bullet(bullet_paras)
	Global.main_game.bullets.add_child(bullet)
	attack_component.play_throw_sfx()


func _stun_nearest_zombie_with_flashbang(stun_time:float) -> void:
	if not is_instance_valid(Global.main_game):
		return
	var all_zombies_2d:Array = Global.main_game.zombie_manager.all_zombies_2d
	if lane < 0 or lane >= all_zombies_2d.size():
		return
	var nearest_zombie:Zombie000Base
	var nearest_distance := INF
	for zombie:Zombie000Base in all_zombies_2d[lane]:
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		var distance_x := (zombie.global_position.x - global_position.x) * float(direction_x_root)
		if distance_x <= 0.0 or distance_x > trapped_flashbang_front_range:
			continue
		if distance_x < nearest_distance:
			nearest_distance = distance_x
			nearest_zombie = zombie
	if is_instance_valid(nearest_zombie):
		nearest_zombie.be_butter(stun_time)


func _prepare_backstep_roll() -> void:
	_backstep_body_position = body.position
	_backstep_body_rotation = body.rotation
	_backstep_body_scale = body.scale
	_backstep_roll_pivot = _get_body_visual_center()
	_backstep_roll_direction = -signf(float(direction_x_root))


func _update_backstep_roll_visual(progress:float) -> void:
	## 翻滚中短暂压扁、挤宽，使高挑的仙人掌更接近一个滚动中的团块。
	var squash_amount:= sin(PI * progress)
	var squash:= Vector2(1.0 + 0.14 * squash_amount, 1.0 - 0.24 * squash_amount)
	var roll_angle:= TAU * backstep_roll_turns * progress * _backstep_roll_direction
	body.rotation = _backstep_body_rotation + roll_angle
	body.scale = _backstep_body_scale * squash

	## 用位置补偿把视觉包围盒中心固定为旋转轴，而不是使用 Body 位于脚底的原点。
	var original_pivot_vector:= Vector2(
		_backstep_roll_pivot.x * _backstep_body_scale.x,
		_backstep_roll_pivot.y * _backstep_body_scale.y
	).rotated(_backstep_body_rotation)
	var transformed_pivot_vector:= Vector2(
		_backstep_roll_pivot.x * body.scale.x,
		_backstep_roll_pivot.y * body.scale.y
	).rotated(body.rotation)
	body.position = _backstep_body_position + original_pivot_vector - transformed_pivot_vector


func _finish_backstep_roll() -> void:
	body.position = _backstep_body_position
	body.rotation = _backstep_body_rotation
	body.scale = _backstep_body_scale
	position = Vector2.ZERO
	_skill_roll_finished = true
	_start_forced_rise_after_roll()


func _set_skill_invulnerable(value:bool) -> void:
	if _skill_is_invulnerable == value:
		return
	_skill_is_invulnerable = value
	## 无敌只在下方各受击入口拦截伤害，不禁用 HurtBoxComponent。
	## HurtBoxDetection 需要保持 monitorable，僵尸才能继续识别并停在麦克雷面前。


func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	if _skill_is_invulnerable:
		return
	var limited_damage:= _limit_charge_damage(attack_value)
	if limited_damage > 0:
		super(limited_damage, attack_zombie)


func be_zombie_eat_once(attack_zombie:Zombie000Base):
	if _skill_is_invulnerable:
		return
	super(attack_zombie)


func be_attacked_bullet(
	attack_value:int,
	bullet_mode:BulletRegistry.AttackMode = BulletRegistry.AttackMode.Norm,
	is_drop:bool = true,
	trigger_be_attack_SFX:bool = true
):
	if _skill_is_invulnerable:
		return
	var limited_damage:= _limit_charge_damage(attack_value)
	if limited_damage > 0:
		super(limited_damage, bullet_mode, is_drop, trigger_be_attack_SFX)


func be_attacked_hammer(attack_value:int):
	if _skill_is_invulnerable:
		return false
	var limited_damage:= _limit_charge_damage(attack_value)
	if limited_damage <= 0:
		return false
	return super(limited_damage)


func be_attack_to_death(trigger_be_attack_SFX:= true):
	if _skill_is_invulnerable:
		return
	if _charge_damage_cap_is_active:
		var limited_damage:= _limit_charge_damage(hp_component.get_all_hp())
		if limited_damage > 0:
			super.be_attacked_bullet(
				limited_damage,
				BulletRegistry.AttackMode.Norm,
				true,
				trigger_be_attack_SFX
			)
		return
	super(trigger_be_attack_SFX)


func be_flattened():
	if _skill_is_invulnerable:
		return
	if _charge_damage_cap_is_active:
		var limited_damage:= _limit_charge_damage(hp_component.get_all_hp())
		if limited_damage > 0:
			super.be_attacked_bullet(limited_damage)
		return
	super()


func _start_charge_damage_cap() -> void:
	_charge_damage_cap_elapsed = 0.0
	_charge_damage_cap_is_active = true
	_charge_capped_damage_taken = 0


func _limit_charge_damage(attack_value:int) -> int:
	if attack_value <= 0 or not _charge_damage_cap_is_active:
		return attack_value
	## 血量为整数：按生长与蓄力阶段已过时间累计 8.0 点/秒的伤害额度。
	var cumulative_damage_cap:= int(round(
		_charge_damage_cap_elapsed * CHARGE_DAMAGE_CAP_PER_SECOND
	))
	var remaining_damage_cap:= maxi(cumulative_damage_cap - _charge_capped_damage_taken, 0)
	var limited_damage:= mini(attack_value, remaining_damage_cap)
	_charge_capped_damage_taken += limited_damage
	return limited_damage


func _get_body_visual_center() -> Vector2:
	var has_visible_rect:= false
	var visible_rect:= Rect2()
	var body_inverse:= body.global_transform.affine_inverse()
	for child in body.find_children("*", "Sprite2D", true, false):
		var sprite:= child as Sprite2D
		if not is_instance_valid(sprite) or sprite.texture == null or not sprite.is_visible_in_tree():
			continue
		var sprite_to_body:= body_inverse * sprite.global_transform
		var sprite_rect:= sprite.get_rect()
		var corners:= [
			sprite_rect.position,
			sprite_rect.position + Vector2(sprite_rect.size.x, 0.0),
			sprite_rect.end,
			sprite_rect.position + Vector2(0.0, sprite_rect.size.y),
		]
		for corner:Vector2 in corners:
			var body_point:Vector2 = sprite_to_body * corner
			if not has_visible_rect:
				visible_rect = Rect2(body_point, Vector2.ZERO)
				has_visible_rect = true
			else:
				visible_rect = visible_rect.expand(body_point)
	if has_visible_rect:
		return visible_rect.get_center()
	return Vector2(0.0, -50.0)


func _on_hp_loss_for_charge(curr_hp:int, _is_drop:bool) -> void:
	if _skill_has_triggered or is_death or curr_hp > skill_trigger_hp:
		return
	_skill_has_triggered = true
	_start_skill()


func _fire_charged_shots(force_release:= false, is_death_release:= false) -> void:
	if not _skill_is_charging:
		return
	_skill_is_charging = false
	_charge_damage_cap_is_active = false
	_set_skill_invulnerable(false)
	_locked_fire_countdown = -1.0
	_stop_charge_visuals()
	var fired_shot:= false
	for target:Zombie000Base in _locked_targets:
		if not is_instance_valid(target) or target.is_death:
			continue
		var target_id:= target.get_instance_id()
		_refresh_target_lock_state(target)
		var target_elapsed:float = _charge_elapsed - _target_charge_started_at.get(target_id, 0.0)
		if _target_lock_completed.get(target_id, false):
			_spawn_skill_bullet(target)
			## 完成红骷髅锁定后是处决，不受伤害上限或减伤影响。
			target.hp_component.Hp_loss_death()
		elif force_release:
			## 仅死亡强制释放会走这里；未锁满目标承受自己的当前累计伤害。
			var accumulated_damage:= maxi(
				1,
				int(round(
					float(charge_reference_hp) * target_elapsed * lock_speed_multiplier
					/ maxf(charge_time, 0.001)
				))
			)
			_spawn_skill_bullet(target, accumulated_damage)
		fired_shot = true
	if fired_shot:
		attack_component.play_throw_sfx()
	_release_target_reticles(force_release)
	_locked_targets.clear()
	_target_charge_durations.clear()
	_target_charge_started_at.clear()
	_target_lock_completed.clear()

	_skill_forces_rise = false
	if not is_death_release and not is_death:
		attack_component.update_is_attack_factors(true, AttackComponentBase.E_IsAttackFactors.Character)
		_refresh_cassidy_rise(false)

func _spawn_skill_bullet(target:Zombie000Base, damage:= -1) -> void:
	if not is_instance_valid(target) or not is_instance_valid(Global.main_game):
		return
	var bullet:= CASSIDY_SKILL_BULLET_SCENE.instantiate() as BulletLinear007Cactus
	if not is_instance_valid(bullet):
		return
	mark_bullet_recording_source(bullet)
	var marker:= attack_component.markers_2d_bullet[0]
	var shot_direction:= marker.global_position.direction_to(target.hurt_box_component.global_position)
	var bullet_paras:Dictionary[Bullet000NormBase.E_InitParasAttr, Variant] = {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
		Bullet000NormBase.E_InitParasAttr.BulletLane: lane,
		Bullet000NormBase.E_InitParasAttr.Position: Global.main_game.bullets.to_local(marker.global_position),
		Bullet000NormBase.E_InitParasAttr.Direction: shot_direction,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: target.curr_be_attack_status,
		Bullet000NormBase.E_InitParasAttr.Enemy: target,
	}
	if damage > 0:
		bullet_paras[Bullet000NormBase.E_InitParasAttr.AttackValue] = damage
	bullet.init_bullet(bullet_paras)
	Global.main_game.bullets.add_child(bullet)


func _refresh_cassidy_rise(_attack_state=true) -> void:
	var has_balloon_target:= attack_component.detect_component.judge_zombie_in_sky()
	is_rise = _skill_forces_rise or has_balloon_target
	attack_component.on_cactus_update_is_rise(is_rise)


func _start_charge_visuals() -> void:
	flare.visible = true
	flare_remote_transform.scale = Vector2.ZERO

	_tumbleweed = Sprite2D.new()
	_tumbleweed.texture = TUMBLEWEED_TEXTURE
	_tumbleweed.position = Vector2(-75.0, 5.0)
	_tumbleweed.z_index = 5
	add_child(_tumbleweed)

	_tumbleweed_move_tween = create_tween().set_parallel()
	_tumbleweed_move_tween.tween_property(_tumbleweed, "position:x", 110.0, _charge_total_duration)
	_tumbleweed_move_tween.tween_property(_tumbleweed, "rotation", TAU * 3.0, _charge_total_duration)

	_tumbleweed_bob_tween = create_tween().set_loops()
	_tumbleweed_bob_tween.tween_property(_tumbleweed, "position:y", -3.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tumbleweed_bob_tween.tween_property(_tumbleweed, "position:y", 5.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_charge_visuals() -> void:
	flare.visible = false
	flare_remote_transform.scale = _flare_remote_final_scale
	if is_instance_valid(_tumbleweed_move_tween):
		_tumbleweed_move_tween.kill()
	if is_instance_valid(_tumbleweed_bob_tween):
		_tumbleweed_bob_tween.kill()
	if is_instance_valid(_tumbleweed):
		_tumbleweed.queue_free()
	_tumbleweed = null


func _update_flare_charge_scale() -> void:
	var charge_ratio:= clampf(_charge_elapsed / maxf(_charge_total_duration, 0.001), 0.0, 1.0)
	flare_remote_transform.scale = _flare_remote_final_scale * charge_ratio


func _scan_for_new_targets() -> void:
	_prune_dead_targets()
	var candidates:= _get_zombies_in_skill_range()
	candidates.sort_custom(
		func(a:Zombie000Base, b:Zombie000Base):
			return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	for target:Zombie000Base in candidates:
		if not is_instance_valid(target) or target.is_death or _locked_targets.has(target):
			continue
		_add_dynamic_target(target)


func _add_dynamic_target(target:Zombie000Base) -> void:
	var target_id:= target.get_instance_id()
	var target_hp:= maxi(target.hp_component.get_all_hp(), 1)
	var target_duration:= maxf(
		0.001,
		charge_time * float(target_hp)
		/ maxf(float(charge_reference_hp) * lock_speed_multiplier, 1.0)
	)
	## 后进入者从进入时开始倒计时，但不能把整次蓄力拖过 6 秒。
	target_duration = minf(target_duration, maxf(MAX_CHARGE_DURATION - _charge_elapsed, 0.0))
	_locked_targets.append(target)
	_target_charge_started_at[target_id] = _charge_elapsed
	_target_charge_durations[target_id] = target_duration
	_target_lock_completed[target_id] = false
	_charge_total_duration = minf(
		maxf(_charge_total_duration, _charge_elapsed + target_duration),
		MAX_CHARGE_DURATION
	)
	if not is_instance_valid(Global.main_game):
		return
	var reticle:= CASSIDY_RETICLE_SCRIPT.new() as Node2D
	Global.main_game.add_child(reticle)
	reticle.call(&"setup", target)
	_target_reticles[target_id] = reticle


func _refresh_target_lock_state(target:Zombie000Base) -> float:
	var target_id:= target.get_instance_id()
	var stored_duration:float = _target_charge_durations.get(target_id, charge_time)
	if _target_lock_completed.get(target_id, false):
		return stored_duration

	## 骷髅出现前持续按僵尸当前总血量（本体与全部护甲）重算，血量越低时长越短。
	var target_hp:= maxi(target.hp_component.get_all_hp(), 1)
	var target_duration:= maxf(
		0.001,
		charge_time * float(target_hp)
		/ maxf(float(charge_reference_hp) * lock_speed_multiplier, 1.0)
	)
	var target_started_at:float = _target_charge_started_at.get(target_id, _charge_elapsed)
	target_duration = minf(
		target_duration,
		maxf(MAX_CHARGE_DURATION - target_started_at, 0.0)
	)
	_target_charge_durations[target_id] = target_duration
	_charge_total_duration = minf(
		maxf(_charge_total_duration, target_started_at + target_duration),
		MAX_CHARGE_DURATION
	)
	if _charge_elapsed - target_started_at >= target_duration:
		_target_lock_completed[target_id] = true
	return target_duration


func _prune_dead_targets() -> void:
	for target_index in range(_locked_targets.size() - 1, -1, -1):
		var target:= _locked_targets[target_index]
		if is_instance_valid(target) and not target.is_death:
			continue
		if is_instance_valid(target):
			var target_id:= target.get_instance_id()
			var reticle:= _target_reticles.get(target_id) as Node2D
			if is_instance_valid(reticle):
				reticle.queue_free()
			_target_reticles.erase(target_id)
			_target_charge_durations.erase(target_id)
			_target_charge_started_at.erase(target_id)
			_target_lock_completed.erase(target_id)
		_locked_targets.remove_at(target_index)


func _are_all_targets_locked() -> bool:
	if _locked_targets.is_empty():
		return false
	for target:Zombie000Base in _locked_targets:
		if not is_instance_valid(target) or target.is_death:
			continue
		var target_id:= target.get_instance_id()
		_refresh_target_lock_state(target)
		if not _target_lock_completed.get(target_id, false):
			return false
	return true


func _update_target_reticles() -> void:
	for target:Zombie000Base in _locked_targets:
		if not is_instance_valid(target):
			continue
		var target_id:= target.get_instance_id()
		var reticle:= _target_reticles.get(target_id) as Node2D
		if not is_instance_valid(reticle):
			continue
		var target_duration:= _refresh_target_lock_state(target)
		var target_elapsed:float = _charge_elapsed - _target_charge_started_at.get(target_id, 0.0)
		reticle.call(&"set_charge_progress", target_elapsed / maxf(target_duration, 0.001))


func _release_target_reticles(force_release:bool) -> void:
	for target:Zombie000Base in _locked_targets:
		if not is_instance_valid(target):
			continue
		var target_id:= target.get_instance_id()
		var reticle:= _target_reticles.get(target_id) as Node2D
		if not is_instance_valid(reticle):
			continue
		_refresh_target_lock_state(target)
		if not force_release or _target_lock_completed.get(target_id, false):
			reticle.call(&"finish_and_free", charged_icon_hold_time)
		else:
			reticle.call(&"fade_and_free", 0.0)
	_target_reticles.clear()


func _clear_locked_targets() -> void:
	for reticle:Node2D in _target_reticles.values():
		if is_instance_valid(reticle):
			reticle.queue_free()
	_target_reticles.clear()
	_locked_targets.clear()
	_target_charge_durations.clear()
	_target_charge_started_at.clear()
	_target_lock_completed.clear()
	_charge_total_duration = 0.0
	_locked_fire_countdown = -1.0


func _defer_charge_cleanup_on_death() -> void:
	## 死亡信号早于掉血信号：在死亡入口直接强制释放，保证任何死亡来源都先发出蓄力子弹。
	if _skill_is_charging:
		_fire_charged_shots(true, true)
	_cleanup_charge_after_death.call_deferred()


func _cleanup_charge_after_death() -> void:
	if _skill_is_charging:
		## 仅作为异常状态兜底；正常死亡已在死亡信号入口完成强制释放。
		_skill_is_charging = false
	if is_instance_valid(_trapped_burst_tween):
		_trapped_burst_tween.kill()
	_trapped_burst_tween = null
	_set_skill_invulnerable(false)
	_skill_is_pending_rise = false
	_skill_roll_finished = false
	_skill_rise_finished = false
	_skill_forces_rise = false
	_restore_skill_rise_animation_speed()
	_charge_damage_cap_elapsed = 0.0
	_charge_damage_cap_is_active = false
	_charge_capped_damage_taken = 0
	_stop_charge_visuals()
	_clear_locked_targets()


func _get_zombies_in_skill_range() -> Array[Zombie000Base]:
	var result:Array[Zombie000Base] = []
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return result
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= all_cells.size():
		return result
	var lane_cells:Array = all_cells[lane]
	if row_col.y < 0 or row_col.y >= lane_cells.size():
		return result

	## 卡西迪所在列加正前方连续三列，共四列。
	var furthest_front_column:= clampi(
		row_col.y + skill_column_count * direction_x_root,
		0,
		lane_cells.size() - 1
	)
	var first_column:= mini(row_col.y, furthest_front_column)
	var last_column:= maxi(row_col.y, furthest_front_column)
	var first_cell:PlantCell = lane_cells[first_column]
	var last_cell:PlantCell = lane_cells[last_column]
	var range_min_x:= minf(first_cell.global_position.x, last_cell.global_position.x)
	var range_max_x:= maxf(
		first_cell.global_position.x + first_cell.size.x,
		last_cell.global_position.x + last_cell.size.x
	)

	## 自身行及上下相邻行，与四列共同组成最多 3×4 的十二格范围。
	var first_lane:= maxi(0, lane - 1)
	var last_lane:= mini(Global.main_game.zombie_manager.all_zombies_2d.size() - 1, lane + 1)
	for target_lane in range(first_lane, last_lane + 1):
		var zombie_row:Array = Global.main_game.zombie_manager.all_zombies_2d[target_lane]
		for zombie:Zombie000Base in zombie_row:
			if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
				continue
			if zombie.global_position.x >= range_min_x and zombie.global_position.x <= range_max_x:
				result.append(zombie)
	return result
