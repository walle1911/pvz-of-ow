extends Plant000Base
class_name Plant057TallNutSigma

const GRAVITY_WELL_EFFECT_SCRIPT := preload("res://scripts/fx/plant_effect/plant_effect_tall_nut_sigma_gravity_well.gd")

@onready var hp_stage_change_component: HpStageChangeComponent = $HpStageChangeComponent

@export_group("西格玛下砸")
@export_range(0.0, 30.0, 1.0, "suffix:px") var slam_range_edge_tolerance:float = 0.0
@export_range(0.01, 4.0, 0.01, "suffix:秒") var slam_charge_time:float = 1.5
@export_range(0.5, 2.0, 0.05) var slam_effect_radius_scale:float = 1.0
@export_range(0.3, 0.9, 0.01) var slam_effect_perspective_y_scale:float = 0.56
@export_range(1.0, 150.0, 1.0, "suffix:px") var slam_lift_height:float = 91.0
@export_range(1.0, 2.0, 0.01) var slam_air_body_scale:float = 1.25
@export_range(0.1, 1.0, 0.05) var slam_air_shadow_scale:float = 0.4
@export_range(0.05, 1.0, 0.05) var slam_air_shadow_alpha:float = 0.25
@export_range(0.01, 2.0, 0.01, "suffix:秒") var slam_lift_time:float = 0.67
@export_range(0.0, 2.0, 0.01, "suffix:秒") var slam_hold_time:float = 1.25
@export_range(0.01, 2.0, 0.01, "suffix:秒") var slam_fall_time:float = 0.33
@export var slam_impact_squash_scale:= Vector2(1.12, 0.82)
@export_range(0.01, 0.5, 0.01, "suffix:秒") var slam_impact_recover_time:float = 0.12
@export_range(0.0, 1.0, 0.05) var slam_current_hp_ratio:float = 0.5
@export_range(-40.0, 0.0, 1.0, "suffix:dB") var slam_impact_sound_volume_db:float = 0.0

const SLAM_TRIGGER_HP_STAGE:int = 1
const SLAM_ACTIVE_META:StringName = &"tall_nut_sigma_slam_active"

class TallNutSigmaSlamSequence extends Node:
	var zombie:Zombie000Base
	var damage_ratio:float
	var body_start_y:float
	var body_start_scale:Vector2
	var shadow_start_scale:Vector2
	var shadow_start_modulate:Color
	var impact_sound_volume_db:float
	var impact_squash_scale:Vector2
	var impact_recover_time:float

	func start(
		target_zombie:Zombie000Base,
		lift_height:float,
		air_body_scale:float,
		air_shadow_scale:float,
		air_shadow_alpha:float,
		lift_time:float,
		hold_time:float,
		fall_time:float,
		landing_squash_scale:Vector2,
		landing_recover_time:float,
		current_hp_ratio:float,
		sound_volume_db:float
	) -> void:
		zombie = target_zombie
		damage_ratio = current_hp_ratio
		impact_sound_volume_db = sound_volume_db
		impact_squash_scale = landing_squash_scale
		impact_recover_time = landing_recover_time
		body_start_y = zombie.body.position.y
		body_start_scale = zombie.body.scale
		shadow_start_scale = zombie.shadow.scale
		shadow_start_modulate = zombie.shadow.modulate
		var shadow_air_modulate:= shadow_start_modulate
		shadow_air_modulate.a *= air_shadow_alpha

		zombie.set_meta(SLAM_ACTIVE_META, true)
		zombie.update_speed_factor(0.0, Character000Base.E_Influence_Speed_Factor.TallNutSigmaSlam)
		zombie.move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsTallNutSigmaSlam)
		zombie.attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.TallNutSigmaSlam)
		var slam_tween:Tween = create_tween()
		slam_tween.set_trans(Tween.TRANS_QUAD)
		slam_tween.set_ease(Tween.EASE_OUT)
		slam_tween.tween_property(zombie.body, ^"position:y", body_start_y - lift_height, lift_time)
		slam_tween.parallel().tween_property(zombie.body, ^"scale", body_start_scale * air_body_scale, lift_time)
		slam_tween.parallel().tween_property(zombie.shadow, ^"scale", shadow_start_scale * air_shadow_scale, lift_time)
		slam_tween.parallel().tween_property(zombie.shadow, ^"modulate", shadow_air_modulate, lift_time)
		slam_tween.tween_interval(hold_time)
		slam_tween.set_ease(Tween.EASE_IN)
		slam_tween.tween_property(zombie.body, ^"position:y", body_start_y, fall_time)
		slam_tween.parallel().tween_property(zombie.body, ^"scale", body_start_scale * impact_squash_scale, fall_time)
		slam_tween.parallel().tween_property(zombie.shadow, ^"scale", shadow_start_scale, fall_time)
		slam_tween.parallel().tween_property(zombie.shadow, ^"modulate", shadow_start_modulate, fall_time)
		slam_tween.tween_callback(_impact_slam)
		slam_tween.set_trans(Tween.TRANS_BACK)
		slam_tween.set_ease(Tween.EASE_OUT)
		slam_tween.tween_property(zombie.body, ^"scale", body_start_scale, impact_recover_time)
		slam_tween.tween_callback(queue_free)

	func _impact_slam() -> void:
		if not is_instance_valid(zombie):
			queue_free()
			return
		zombie.body.position.y = body_start_y
		zombie.shadow.scale = shadow_start_scale
		zombie.shadow.modulate = shadow_start_modulate
		zombie.update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.TallNutSigmaSlam)
		zombie.move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsTallNutSigmaSlam)
		zombie.attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.TallNutSigmaSlam)
		zombie.remove_meta(SLAM_ACTIVE_META)
		_create_impact_ring()
		SoundManager.play_character_SFX(&"gargantuar_thump", impact_sound_volume_db)
		if not zombie.is_death:
			var current_hp:int = zombie.hp_component.get_all_hp()
			var slam_damage:int = maxi(1, ceili(current_hp * damage_ratio))
			zombie.be_attacked_bullet(slam_damage, BulletRegistry.AttackMode.Norm, true, true)

	func _create_impact_ring() -> void:
		var effect_parent:= zombie.get_parent()
		if not is_instance_valid(effect_parent):
			return
		var impact_root:= Node2D.new()
		effect_parent.add_child(impact_root)
		impact_root.global_position = zombie.shadow.global_position
		impact_root.z_index = zombie.z_index - 1
		impact_root.scale = Vector2.ONE * 0.45

		var impact_ring:= Line2D.new()
		impact_ring.width = 3.0
		impact_ring.default_color = Color(0.78, 0.72, 0.58, 0.7)
		impact_ring.closed = true
		impact_ring.antialiased = true
		for point_index:int in range(24):
			var angle:float = TAU * point_index / 24.0
			impact_ring.add_point(Vector2(cos(angle) * 28.0, sin(angle) * 9.0))
		impact_root.add_child(impact_ring)

		var impact_tween:Tween = impact_root.create_tween().set_parallel(true)
		impact_tween.set_trans(Tween.TRANS_QUAD)
		impact_tween.set_ease(Tween.EASE_OUT)
		impact_tween.tween_property(impact_root, ^"scale", Vector2.ONE * 1.6, 0.35)
		impact_tween.tween_property(impact_root, ^"modulate:a", 0.0, 0.35)
		impact_tween.chain().tween_callback(impact_root.queue_free)


class TallNutSigmaFieldSequence extends Node:
	var effect_center:= Vector2.ZERO
	var effect_radii:= Vector2.ONE
	var lift_height:float
	var air_body_scale:float
	var air_shadow_scale:float
	var air_shadow_alpha:float
	var lift_time:float
	var hold_time:float
	var fall_time:float
	var impact_squash_scale:Vector2
	var impact_recover_time:float
	var current_hp_ratio:float
	var impact_sound_volume_db:float

	func start(
		center:Vector2,
		radii:Vector2,
		charge_time:float,
		new_lift_height:float,
		new_air_body_scale:float,
		new_air_shadow_scale:float,
		new_air_shadow_alpha:float,
		new_lift_time:float,
		new_hold_time:float,
		new_fall_time:float,
		new_impact_squash_scale:Vector2,
		new_impact_recover_time:float,
		new_current_hp_ratio:float,
		new_impact_sound_volume_db:float
	) -> void:
		effect_center = center
		effect_radii = Vector2(maxf(1.0, radii.x), maxf(1.0, radii.y))
		lift_height = new_lift_height
		air_body_scale = new_air_body_scale
		air_shadow_scale = new_air_shadow_scale
		air_shadow_alpha = new_air_shadow_alpha
		lift_time = new_lift_time
		hold_time = new_hold_time
		fall_time = new_fall_time
		impact_squash_scale = new_impact_squash_scale
		impact_recover_time = new_impact_recover_time
		current_hp_ratio = new_current_hp_ratio
		impact_sound_volume_db = new_impact_sound_volume_db

		var gravity_well:= GRAVITY_WELL_EFFECT_SCRIPT.new()
		gravity_well.name = "TallNutSigmaGravityWellEffect"
		add_child(gravity_well)
		gravity_well.play(effect_center, effect_radii, charge_time)
		await gravity_well.finished
		## 特效结束前只取一次目标快照；之后进入范围的僵尸不会补抬。
		_slam_targets_in_effect()
		queue_free()

	func _slam_targets_in_effect() -> void:
		if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.zombie_manager):
			return
		for zombie_value in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
			var zombie:= zombie_value as Zombie000Base
			if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
				continue
			if zombie.has_meta(SLAM_ACTIVE_META) or not _is_position_in_effect(zombie.shadow.global_position):
				continue
			_start_zombie_slam(zombie)

	func _is_position_in_effect(target_position:Vector2) -> bool:
		var normalized_offset:= Vector2(
			(target_position.x - effect_center.x) / effect_radii.x,
			(target_position.y - effect_center.y) / effect_radii.y
		)
		return normalized_offset.length_squared() <= 1.0

	func _start_zombie_slam(zombie:Zombie000Base) -> void:
		var slam_sequence:= TallNutSigmaSlamSequence.new()
		zombie.add_child(slam_sequence)
		slam_sequence.start(
			zombie,
			lift_height,
			air_body_scale,
			air_shadow_scale,
			air_shadow_alpha,
			lift_time,
			hold_time,
			fall_time,
			impact_squash_scale,
			impact_recover_time,
			current_hp_ratio,
			impact_sound_volume_db
		)

var _slam_triggered:= false
var _is_being_shoveled:= false

func be_shovel_kill() -> void:
	## 铲除通过 Hp_loss_death() 清空血量，但不应触发血量阶段技能。
	_is_being_shoveled = true
	super()

func ready_norm_signal_connect():
	super()
	## 连接信号
	hp_stage_change_component.signal_hp_stage_change.connect(_on_hp_stage_change)
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)

func _on_hp_stage_change(curr_hp_stage:int) -> void:
	## HpComponent 会先同步标记死亡、再发阶段更新；不能用 is_death 拦截致死跨阶段。
	if _slam_triggered or _is_being_shoveled or curr_hp_stage < SLAM_TRIGGER_HP_STAGE:
		return
	_slam_triggered = true
	_create_gravity_field_sequence()

func _create_gravity_field_sequence() -> void:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return
	var center_cell:= _get_gravity_well_center_cell()
	if not is_instance_valid(center_cell):
		return
	var effect_center:= _get_gravity_well_center(center_cell)
	var effect_radii:= _get_gravity_well_radii(center_cell, effect_center)
	var field_sequence:= TallNutSigmaFieldSequence.new()
	field_sequence.name = "TallNutSigmaFieldSequence"
	Global.main_game.add_child(field_sequence)
	field_sequence.start(
		effect_center,
		effect_radii,
		slam_charge_time,
		slam_lift_height,
		slam_air_body_scale,
		slam_air_shadow_scale,
		slam_air_shadow_alpha,
		slam_lift_time,
		slam_hold_time,
		slam_fall_time,
		slam_impact_squash_scale,
		slam_impact_recover_time,
		slam_current_hp_ratio,
		slam_impact_sound_volume_db
	)


func _get_gravity_well_center_cell() -> PlantCell:
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if row_col.x < 0 or row_col.x >= all_cells.size() or all_cells[row_col.x].is_empty():
		return null
	var lane_cells:Array = all_cells[row_col.x]
	var target_column:int = mini(row_col.y + 1, lane_cells.size() - 1)
	return lane_cells[target_column] as PlantCell


func _get_gravity_well_center(center_cell:PlantCell) -> Vector2:
	var norm_container:Control = center_cell.plant_container_node.get(
		CharacterRegistry.PlacePlantInCell.Norm
	) as Control
	if is_instance_valid(norm_container):
		return norm_container.global_position
	return center_cell.global_position + center_cell.size * 0.5


func _get_gravity_well_x_range(center_column:int) -> Vector2:
	var all_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	var lane_cells:Array = all_cells[row_col.x]
	var first_column:int = maxi(0, center_column - 1)
	var last_column:int = mini(lane_cells.size() - 1, center_column + 1)
	var first_cell:PlantCell = lane_cells[first_column]
	var last_cell:PlantCell = lane_cells[last_column]
	var first_edge_a:float = first_cell.global_position.x
	var first_edge_b:float = first_edge_a + first_cell.size.x
	var last_edge_a:float = last_cell.global_position.x
	var last_edge_b:float = last_edge_a + last_cell.size.x
	return Vector2(
		minf(first_edge_a, first_edge_b) - slam_range_edge_tolerance,
		maxf(last_edge_a, last_edge_b) + slam_range_edge_tolerance
	)


func _get_gravity_well_radii(center_cell:PlantCell, effect_center:Vector2) -> Vector2:
	var center_lane_x_range:= _get_gravity_well_x_range(center_cell.row_col.y)
	var horizontal_radius:float = minf(
		absf(effect_center.x - center_lane_x_range.x),
		absf(center_lane_x_range.y - effect_center.x)
	)
	var available_vertical_radius:float = plant_cell.size.y * 0.5
	var zombie_rows:Array = Global.main_game.zombie_manager.all_zombie_rows
	var first_lane:int = maxi(0, row_col.x - 1)
	var last_lane:int = mini(zombie_rows.size() - 1, row_col.x + 1)
	if not zombie_rows.is_empty():
		var first_y:float = zombie_rows[first_lane].zombie_create_position.global_position.y
		var last_y:float = zombie_rows[last_lane].zombie_create_position.global_position.y
		var top_y:float = minf(first_y, last_y) - plant_cell.size.y * 0.5
		var bottom_y:float = maxf(first_y, last_y) + plant_cell.size.y * 0.5
		available_vertical_radius = minf(
			absf(effect_center.y - top_y),
			absf(bottom_y - effect_center.y)
		)
	var perspective_vertical_radius:float = horizontal_radius * slam_effect_perspective_y_scale
	var vertical_radius:float = minf(available_vertical_radius, perspective_vertical_radius)
	return Vector2(horizontal_radius, vertical_radius) * slam_effect_radius_scale

func _on_area_2d_stop_jump_area_entered(area: Area2D) -> void:
	var zombie:Zombie000Base = area.owner
	if zombie.lane == lane and zombie.is_trigger_tall_nut_stop_jump:
		zombie.jump_be_stop(self)
