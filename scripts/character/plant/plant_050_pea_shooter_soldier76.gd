extends Plant000Base
class_name Plant050PeaShooterSoldier76

@onready var attack_component: AttackComponentBulletBase = $AttackComponent

@export_group("PeaShooter 76")
@export var heal_delay_after_attack:float = 1.5
@export var escape_move_time:float = 0.15

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
var _has_escaped := false
var _escape_tween:Tween

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)

## 被僵尸啃食掉血
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	super(attack_value, attack_zombie)
	_start_heal_countdown()

## 被僵尸啃食一次发光，动画调用时认为敌人快要攻击到自己
func be_zombie_eat_once(attack_zombie:Zombie000Base):
	_try_escape_once(attack_zombie)
	super(attack_zombie)

## 被子弹攻击
func be_attacked_bullet(attack_value:int, bullet_mode:BulletRegistry.AttackMode=BulletRegistry.AttackMode.Norm, is_drop:bool=true, trigger_be_attack_SFX:=true):
	super(attack_value, bullet_mode, is_drop, trigger_be_attack_SFX)
	_start_heal_countdown()

## 被锤子攻击
func be_attacked_hammer(attack_value:int):
	var is_dead = super(attack_value)
	_start_heal_countdown()
	return is_dead

func _start_heal_countdown():
	if _has_used_heal or is_death:
		return
	_heal_wait_token += 1
	_heal_after_delay(_heal_wait_token)

func _heal_after_delay(token:int):
	await get_tree().create_timer(heal_delay_after_attack).timeout
	if token != _heal_wait_token or _has_used_heal or is_death:
		return
	if hp_component.curr_hp >= hp_component.max_hp:
		return
	hp_component.curr_hp = hp_component.max_hp
	_has_used_heal = true
	body.body_light()

func _try_escape_once(attack_zombie:Zombie000Base):
	if _has_escaped or is_death or not is_instance_valid(plant_cell):
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
