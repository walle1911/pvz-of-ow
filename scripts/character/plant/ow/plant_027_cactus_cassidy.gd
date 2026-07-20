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

var _skill_has_triggered:= false
var _skill_is_pending_rise:= false
var _skill_is_charging:= false
var _skill_forces_rise:= false
var _charge_elapsed:= 0.0
var _flare_remote_final_scale:= Vector2.ONE
var _tumbleweed:Sprite2D
var _tumbleweed_move_tween:Tween
var _tumbleweed_bob_tween:Tween


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
	var was_risen:= is_rise
	_skill_is_pending_rise = not was_risen
	_skill_forces_rise = true
	## 蓄力优先于普通气球攻击；检测组件保持工作，释放后可立即恢复攻击气球。
	attack_component.update_is_attack_factors(false, AttackComponentBase.E_IsAttackFactors.Character)
	_refresh_cassidy_rise(false)
	if was_risen:
		_begin_charge()


func _begin_charge() -> void:
	_skill_is_pending_rise = false
	_skill_is_charging = true
	_charge_elapsed = 0.0
	_start_charge_visuals()


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
	_tumbleweed.position = Vector2(-75.0, 25.0)
	_tumbleweed.z_index = 5
	add_child(_tumbleweed)

	_tumbleweed_move_tween = create_tween().set_parallel()
	_tumbleweed_move_tween.tween_property(_tumbleweed, "position:x", 110.0, charge_time)
	_tumbleweed_move_tween.tween_property(_tumbleweed, "rotation", TAU * 3.0, charge_time)

	_tumbleweed_bob_tween = create_tween().set_loops()
	_tumbleweed_bob_tween.tween_property(_tumbleweed, "position:y", 17.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tumbleweed_bob_tween.tween_property(_tumbleweed, "position:y", 25.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
