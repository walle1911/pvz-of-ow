extends Plant000Base
class_name Plant001PeaShooterSoldier76

@onready var attack_component: AttackComponentBulletBase = $AttackComponent
@onready var heal_animation_player: AnimationPlayer = $HealAnimationPlayer
@onready var heal_plus_effect: Node2D = $Body/BodyCorrect/HealPlusEffect
@onready var soldier76_e: Sprite2D = $Body/BodyCorrect/Anim_stem/Anim_Soldier76_E

@export_group("PeaShooter 76")
@export var heal_delay_after_attack:float = 1.0
@export var heal_duration:float = 1.25
@export var heal_amount_per_second:int = 240
@export var escape_move_time:float = 0.15
@export var escape_hp_threshold:int = 100
@export var heal_animation_name:StringName = &"Heal"

const RECORDING_5757_SCENE_PATH := "res://scenes/main/test/MainGameDebugRecording5757.tscn"
const RECORDING_5757_NIGHT_SCENE_PATH := "res://scenes/main/test/MainGameDebugRecording5757Night.tscn"
const FRONT_CELL_OFFSET := Vector2i(0, 1)
const BACK_CELL_OFFSET := Vector2i(0, -1)
const SIDE_CELL_OFFSETS:Array[Vector2i] = [
	FRONT_CELL_OFFSET,
	BACK_CELL_OFFSET,
	Vector2i(-1, 0),
	Vector2i(1, 0),
]

var _has_used_heal := false
var _heal_wait_token := 0
var _is_healing := false
var _has_escaped := false
var _escape_tween:Tween

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)

## 被僵尸啃食掉血
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	super(attack_value, attack_zombie)
	_on_took_damage()

## 被僵尸啃食一次发光，动画调用时认为敌人快要攻击到自己
func be_zombie_eat_once(attack_zombie:Zombie000Base):
	_try_escape_once(attack_zombie)
	super(attack_zombie)

## 被子弹攻击
func be_attacked_bullet(attack_value:int, bullet_mode:BulletRegistry.AttackMode=BulletRegistry.AttackMode.Norm, is_drop:bool=true, trigger_be_attack_SFX:=true):
	super(attack_value, bullet_mode, is_drop, trigger_be_attack_SFX)
	_on_took_damage()

## 被锤子攻击
func be_attacked_hammer(attack_value:int):
	var is_dead = super(attack_value)
	_on_took_damage()
	return is_dead

func _on_took_damage():
	if _has_used_heal or is_death:
		return
	if _is_healing:
		_interrupt_heal()
	_start_heal_countdown()

func _start_heal_countdown():
	if _has_used_heal or is_death:
		return
	_heal_wait_token += 1
	_heal_after_delay(_heal_wait_token)

func _heal_after_delay(token:int):
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(heal_delay_after_attack).timeout
	if not is_inside_tree() or token != _heal_wait_token or _has_used_heal or is_death or _is_healing:
		return
	if hp_component.curr_hp >= hp_component.max_hp:
		return
	_begin_heal(token)

func _begin_heal(token:int):
	var tree := get_tree()
	if tree == null:
		return
	_is_healing = true
	_has_used_heal = true
	body.body_light()
	_play_heal_anim()
	var elapsed := 0.0
	while elapsed < heal_duration:
		var prev_msec := Time.get_ticks_msec()
		## 保留开始治疗时的 SceneTree；切换/退出场景后节点的 get_tree() 会变为 null。
		await tree.process_frame
		if not is_inside_tree() or token != _heal_wait_token or is_death or not _is_healing:
			_is_healing = false
			return
		var delta := (Time.get_ticks_msec() - prev_msec) / 1000.0
		elapsed += delta
		hp_component.curr_hp = min(hp_component.curr_hp + int(heal_amount_per_second * delta), hp_component.max_hp)
	if token != _heal_wait_token or is_death or not _is_healing:
		return
	_is_healing = false

func _play_heal_anim():
	var anim := heal_animation_player.get_animation(heal_animation_name)
	if anim and anim.length > 0:
		heal_animation_player.speed_scale = anim.length / heal_duration
	heal_animation_player.play(heal_animation_name)

func _interrupt_heal():
	_is_healing = false
	heal_animation_player.stop()
	_reset_heal_visual()

func _reset_heal_visual():
	heal_plus_effect.visible = false
	heal_plus_effect.modulate = Color(1, 1, 1, 0)
	heal_plus_effect.position = Vector2(39, 22)
	heal_plus_effect.scale = Vector2(0.75, 0.75)
	soldier76_e.self_modulate = Color(1, 1, 1, 1)

func _try_escape_once(attack_zombie:Zombie000Base):
	if _has_escaped or is_death or not is_instance_valid(plant_cell):
		return
	if hp_component.curr_hp >= escape_hp_threshold:
		return
	var threat_dir := _get_facing_threat_direction(attack_zombie)
	if threat_dir == 0:
		return
	var target_cell := _get_random_escape_cell(threat_dir)
	if not is_instance_valid(target_cell):
		return
	_move_to_plant_cell(target_cell)
	_has_escaped = true

## 返回 1 表示前方威胁，-1 表示后方威胁，0 表示不满足“僵尸面向自己”
func _get_facing_threat_direction(zombie:Zombie000Base) -> int:
	if not is_instance_valid(zombie):
		return 0
	if zombie.global_position.x >= global_position.x:
		return 1 if zombie.direction_x_root == 1 else 0
	else:
		return -1 if zombie.direction_x_root == -1 else 0

func _get_random_escape_cell(threat_dir:int) -> PlantCell:
	if _is_recording_5757_scene():
		var downward_cell := _get_cell_by_offset(Vector2i(1, 0))
		return downward_cell if is_instance_valid(downward_cell) and _can_escape_to_cell(downward_cell) else null

	var candidate_offsets := SIDE_CELL_OFFSETS.duplicate()
	candidate_offsets.shuffle()
	for offset:Vector2i in candidate_offsets:
		if threat_dir == 1 and offset == FRONT_CELL_OFFSET:
			continue
		if threat_dir == -1 and offset == BACK_CELL_OFFSET:
			continue
		var target_cell := _get_cell_by_offset(offset)
		if is_instance_valid(target_cell) and _can_escape_to_cell(target_cell):
			return target_cell
	return null

func _is_recording_5757_scene() -> bool:
	var current_scene := get_tree().current_scene
	return is_instance_valid(current_scene) \
		and current_scene.scene_file_path in [
			RECORDING_5757_SCENE_PATH,
			RECORDING_5757_NIGHT_SCENE_PATH,
		]

func _get_cell_by_offset(offset:Vector2i) -> PlantCell:
	var all_plant_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	var target_row := row_col.x + offset.x
	var target_col := row_col.y + offset.y
	if target_row < 0 or target_row >= all_plant_cells.size():
		return null
	if target_col < 0 or target_col >= all_plant_cells[target_row].size():
		return null
	return all_plant_cells[target_row][target_col]

func _can_escape_to_cell(target_cell:PlantCell) -> bool:
	if target_cell == plant_cell:
		return false
	if target_cell.get_curr_plant_num() > 0:
		return false
	var plant_condition:ResourcePlantCondition = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if not plant_condition.judge_is_can_plant(target_cell, plant_type):
		return false
	return not _cell_has_zombie(target_cell)

func _cell_has_zombie(target_cell:PlantCell) -> bool:
	if target_cell.row_col.x < 0 or target_cell.row_col.x >= Global.main_game.zombie_manager.all_zombies_2d.size():
		return false
	var cell_left := target_cell.global_position.x
	var cell_right := cell_left + target_cell.size.x
	for zombie:Zombie000Base in Global.main_game.zombie_manager.all_zombies_2d[target_cell.row_col.x]:
		if is_instance_valid(zombie) and not zombie.is_death:
			if zombie.global_position.x >= cell_left and zombie.global_position.x <= cell_right:
				return true
	return false

func _move_to_plant_cell(target_cell:PlantCell):
	var plant_condition:ResourcePlantCondition = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	var place := plant_condition.place_plant_in_cell
	var old_cell := plant_cell
	if is_instance_valid(old_cell) and old_cell.plant_in_cell.get(place) == self:
		old_cell.plant_in_cell[place] = null
	target_cell.plant_in_cell[place] = self
	plant_cell = target_cell
	row_col = target_cell.row_col
	lane = target_cell.row_col.x

	var target_parent:Node = target_cell.plant_container_node[place]
	reparent(target_parent, true)
	GlobalUtils.update_plant_cell_slope_y_array(plant_cell, node2d_detect_in_slope)

	if is_instance_valid(_escape_tween):
		_escape_tween.kill()
	_escape_tween = create_tween()
	_escape_tween.tween_property(self, ^"global_position", target_parent.global_position, escape_move_time)
	_escape_tween.tween_callback(func(): position = Vector2.ZERO)
