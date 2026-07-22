extends Plant027Cactus
class_name Plant027CactusCassidy

const CASSIDY_SKILL_BULLET_SCENE:PackedScene = preload("res://scenes/bullet/bullet_027_cactus_cassidy_skill.tscn")
const TUMBLEWEED_TEXTURE:Texture2D = preload("res://assets/reanim/Cactus_Cassidy_tumbleweed.png")

@onready var flare:Sprite2D = $Body/BodyCorrect/flare
@onready var flare_remote_transform:RemoteTransform2D = $Body/BodyCorrect/Anim_face/RemoteTransform2D

@export_group("Cassidy 蓄力技能")
@export_range(0.1, 30.0, 0.1, "suffix:秒") var charge_time:= 4.0
@export_range(1, 5000, 1, "suffix:血") var skill_trigger_hp:= 50
@export_range(1, 20, 1) var max_skill_targets:= 3
@export_range(1, 5000, 1) var max_skill_damage:= 300
@export_range(1, 9, 1) var skill_column_count:= 3
@export_range(0.05, 2.0, 0.05, "suffix:秒") var backstep_duration:= 0.25
@export_range(0.25, 3.0, 0.25, "suffix:圈") var backstep_roll_turns:= 1.0

var _skill_has_triggered:= false
var _skill_is_pending_rise:= false
var _skill_is_charging:= false
var _skill_forces_rise:= false
var _charge_elapsed:= 0.0
var _flare_remote_final_scale:= Vector2.ONE
var _tumbleweed:Sprite2D
var _tumbleweed_move_tween:Tween
var _tumbleweed_bob_tween:Tween
var _backstep_tween:Tween
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
	_flare_remote_final_scale = flare_remote_transform.scale
	flare.visible = false
	flare_remote_transform.scale = Vector2.ZERO


func _physics_process(delta:float) -> void:
	if character_init_type != E_CharacterInitType.IsNorm or is_death:
		return
	if not _skill_is_charging:
		return
	_charge_elapsed = minf(_charge_elapsed + delta, charge_time)
	_update_flare_charge_scale()
	if _charge_elapsed >= charge_time:
		_fire_charged_shots()


func anim_rise_end():
	super()
	if _skill_is_pending_rise and not is_death:
		_begin_charge()


func _start_skill() -> void:
	_skill_is_pending_rise = false
	_try_backstep_for_charge()
	_skill_forces_rise = true
	## 蓄力优先于普通气球攻击；检测组件保持工作，释放后可立即恢复攻击气球。
	attack_component.update_is_attack_factors(false, AttackComponentBase.E_IsAttackFactors.Character)
	_refresh_cassidy_rise(false)
	## 后撤、升起动画与蓄力视觉在同一时刻开始；动画结束仍沿用原版仙人掌恢复攻击权限。
	_begin_charge()


func _begin_charge() -> void:
	_skill_is_pending_rise = false
	_skill_is_charging = true
	_charge_elapsed = 0.0
	_start_charge_visuals()


func _try_backstep_for_charge() -> void:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return
	var all_plant_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_plant_cells.size():
		return
	var lane_cells:Array = all_plant_cells[row_col.x]
	var back_column:= row_col.y - direction_x_root
	if back_column < 0 or back_column >= lane_cells.size():
		return
	var target_cell:PlantCell = lane_cells[back_column]
	## 后退只进入完整空格，避免覆盖花盆、睡莲或其他位置的植物。
	if target_cell.get_curr_plant_num() > 0:
		return
	var plant_condition:ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	if not plant_condition.judge_is_can_plant(target_cell, plant_type):
		return

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


func _fire_charged_shots() -> void:
	if not _skill_is_charging:
		return
	_skill_is_charging = false
	_stop_charge_visuals()
	var charge_ratio:= clampf(_charge_elapsed / maxf(charge_time, 0.001), 0.0, 1.0)
	var damage:= int(round(float(max_skill_damage) * charge_ratio * get_attack_damage_multiplier()))
	var targets:= _get_zombies_in_skill_range()
	targets.sort_custom(
		func(a:Zombie000Base, b:Zombie000Base):
			return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	for target_index in mini(max_skill_targets, targets.size()):
		_spawn_skill_bullet(targets[target_index], damage)
	if not targets.is_empty():
		attack_component.play_throw_sfx()

	_skill_forces_rise = false
	attack_component.update_is_attack_factors(true, AttackComponentBase.E_IsAttackFactors.Character)
	_refresh_cassidy_rise(false)


func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	if _skill_is_pending_rise or _skill_is_charging:
		return
	super(attack_value, attack_zombie)


func be_attacked_bullet(attack_value:int, bullet_mode:BulletRegistry.AttackMode=BulletRegistry.AttackMode.Norm, is_drop:bool=true, trigger_be_attack_SFX:=true):
	if _skill_is_pending_rise or _skill_is_charging:
		return
	super(attack_value, bullet_mode, is_drop, trigger_be_attack_SFX)


func be_attacked_hammer(attack_value:int):
	if _skill_is_pending_rise or _skill_is_charging:
		return false
	return super(attack_value)


func be_attack_to_death(trigger_be_attack_SFX:=true):
	if _skill_is_pending_rise or _skill_is_charging:
		return
	super(trigger_be_attack_SFX)


func be_flattened():
	if _skill_is_pending_rise or _skill_is_charging:
		return
	super()


func _spawn_skill_bullet(target:Zombie000Base, damage:int) -> void:
	if not is_instance_valid(target) or not is_instance_valid(Global.main_game):
		return
	var bullet:= CASSIDY_SKILL_BULLET_SCENE.instantiate() as BulletLinear007Cactus
	if not is_instance_valid(bullet):
		return
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
	bullet.init_bullet(bullet_paras)
	## init_bullet 对非正数保留场景默认值；技能允许零蓄力造成零伤害。
	bullet.attack_value = damage
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
	_tumbleweed_move_tween.tween_property(_tumbleweed, "position:x", 110.0, charge_time)
	_tumbleweed_move_tween.tween_property(_tumbleweed, "rotation", TAU * 3.0, charge_time)

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
	var charge_ratio:= clampf(_charge_elapsed / maxf(charge_time, 0.001), 0.0, 1.0)
	flare_remote_transform.scale = _flare_remote_final_scale * charge_ratio


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
