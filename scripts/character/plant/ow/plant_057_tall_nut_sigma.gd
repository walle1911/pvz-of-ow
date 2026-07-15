extends Plant000Base
class_name Plant057TallNutSigma

@onready var hp_stage_change_component: HpStageChangeComponent = $HpStageChangeComponent

@export_group("西格玛下砸")
@export_range(1, 9, 1) var slam_front_cell_count:int = 2
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

var _slam_triggered:= false

func ready_norm_signal_connect():
	super()
	## 连接信号
	hp_stage_change_component.signal_hp_stage_change.connect(_on_hp_stage_change)
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)

func _on_hp_stage_change(curr_hp_stage:int) -> void:
	if _slam_triggered or is_death or curr_hp_stage < SLAM_TRIGGER_HP_STAGE:
		return
	_slam_triggered = true
	_slam_zombies_in_front_cells()

func _slam_zombies_in_front_cells() -> void:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return
	var all_plant_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	var all_zombies_2d:Array = Global.main_game.zombie_manager.all_zombies_2d
	var first_front_col:int = row_col.y + 1
	var first_lane:int = maxi(0, row_col.x - 1)
	var last_lane_exclusive:int = mini(all_plant_cells.size(), row_col.x + 2)

	for target_lane:int in range(first_lane, last_lane_exclusive):
		if target_lane >= all_zombies_2d.size():
			continue
		var lane_cells:Array = all_plant_cells[target_lane]
		if first_front_col >= lane_cells.size():
			continue
		var last_front_col_exclusive:int = mini(
			lane_cells.size(),
			first_front_col + slam_front_cell_count
		)
		var first_cell:PlantCell = lane_cells[first_front_col]
		var last_cell:PlantCell = lane_cells[last_front_col_exclusive - 1]
		var area_left:float = minf(first_cell.global_position.x, last_cell.global_position.x)
		var area_right:float = maxf(
			first_cell.global_position.x + first_cell.size.x,
			last_cell.global_position.x + last_cell.size.x
		)
		for zombie:Zombie000Base in all_zombies_2d[target_lane].duplicate():
			if not is_instance_valid(zombie) or zombie.is_death:
				continue
			if zombie.global_position.x < area_left or zombie.global_position.x > area_right:
				continue
			_start_zombie_slam(zombie)

func _start_zombie_slam(zombie:Zombie000Base) -> void:
	if zombie.has_meta(SLAM_ACTIVE_META):
		return
	var slam_sequence:= TallNutSigmaSlamSequence.new()
	zombie.add_child(slam_sequence)
	slam_sequence.start(
		zombie,
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

func _on_area_2d_stop_jump_area_entered(area: Area2D) -> void:
	var zombie:Zombie000Base = area.owner
	if zombie.lane == lane and zombie.is_trigger_tall_nut_stop_jump:
		zombie.jump_be_stop(self)
