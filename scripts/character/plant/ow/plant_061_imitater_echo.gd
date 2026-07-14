extends Plant000Base
class_name Plant061ImitaterEcho

## 模仿的植物类型
var imitater_plant_type :CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
var imitater_zombie_type :CharacterRegistry.ZombieType = CharacterRegistry.ZombieType.Null
@export_group("复制僵尸染色", "imitater_zombie_")
@export var imitater_zombie_tint_color: Color = Color(0.72, 0.88, 1.0, 1.0)
@export_range(0.0, 1.0) var imitater_zombie_whiteness := 0.62
@export_range(0.0, 1.0) var imitater_zombie_gray_strength := 0.0
@export_range(-1.0, 1.0) var imitater_zombie_brightness := 0.08
@export_range(0.0, 3.0) var imitater_zombie_contrast := 0.95
@onready var imitater_effect: Node2D = $ImitaterEffect
@onready var animation_tree: AnimationTree = $AnimationTree

## 是否已经执行过模仿转换（防止重复调用）
var _imitater_transformed := false
var _is_explode_animation_phase := false
var imitater_echo_can_explode := false
var _fallback_timer_started := false


## 初始化正常出战角色
func ready_norm():
	super()
	imitater_echo_can_explode = imitater_plant_type != CharacterRegistry.PlantType.Null
	_is_explode_animation_phase = imitater_echo_can_explode
	## 监听 explode 动画结束信号，触发模仿转换
	if is_instance_valid(animation_tree):
		animation_tree.animation_finished.connect(_on_animation_finished)
	if imitater_echo_can_explode:
		_start_fallback_timer()


func _on_animation_finished(anim_name: StringName):
	if anim_name != &"ImitaterEcho_explode":
		return
	_do_imitater_transform()


func _on_fallback_timer_timeout():
	if not _imitater_transformed:
		_do_imitater_transform()


func _do_imitater_transform():
	if _imitater_transformed:
		return
	update_imitater()


## 变身阶段被僵尸攻击时，复制刚刚攻击它的僵尸
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	if _try_transform_to_attacking_zombie(attack_zombie):
		return
	super(attack_value, attack_zombie)


func be_zombie_eat_once(attack_zombie:Zombie000Base):
	if _try_transform_to_attacking_zombie(attack_zombie):
		return
	super(attack_zombie)


func be_flattened_from_enemy(character:Character000Base):
	if character is Zombie000Base and _try_transform_to_attacking_zombie(character):
		return
	super(character)


## 更新模仿者植物
func update_imitater():
	if _imitater_transformed:
		return
	_imitater_transformed = true
	_is_explode_animation_phase = false
	imitater_echo_can_explode = false
	if imitater_zombie_type != CharacterRegistry.ZombieType.Null:
		_create_imitater_zombie()
	## plant_cell创造植物,该函数会先等待一帧,当前模仿者死亡后创建
	elif imitater_plant_type != CharacterRegistry.PlantType.Null and is_instance_valid(plant_cell):
		plant_cell.imitater_create_plant(imitater_plant_type, true, CharacterRegistry.PlantType.P053ImitaterEcho)
	if is_instance_valid(imitater_effect) and is_instance_valid(imitater_effect.owner) and is_instance_valid(imitater_effect.owner.get_parent()):
		imitater_effect.visible = true
		imitater_effect.z_index += 1
		imitater_effect.activate_it()
	## 角色死亡直接消失
	character_death_disappear()


func _try_transform_to_attacking_zombie(attack_zombie:Zombie000Base) -> bool:
	if _imitater_transformed or not is_instance_valid(attack_zombie):
		return false
	if attack_zombie.zombie_type == CharacterRegistry.ZombieType.Null:
		return false
	if imitater_zombie_type == CharacterRegistry.ZombieType.Null:
		imitater_zombie_type = attack_zombie.zombie_type
	imitater_echo_can_explode = true
	_is_explode_animation_phase = true
	_start_fallback_timer()
	return true


func _start_fallback_timer():
	if _fallback_timer_started:
		return
	_fallback_timer_started = true
	## 兜底计时器：如果信号因故未触发，2 秒后强制转换
	var fallback_timer := get_tree().create_timer(2.0)
	fallback_timer.timeout.connect(_on_fallback_timer_timeout)


func _create_imitater_zombie():
	if not is_instance_valid(plant_cell) or not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.zombie_manager):
		return
	var lane_index := plant_cell.row_col.x
	if lane_index < 0 or lane_index >= Global.main_game.zombie_manager.all_zombie_rows.size():
		return
	var zombie_parent:ZombieRow = Global.main_game.zombie_manager.all_zombie_rows[lane_index]
	var zombie_init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane:lane_index,
	}
	var zombie:Zombie000Base = Global.main_game.zombie_manager.create_norm_zombie(
		imitater_zombie_type,
		zombie_parent,
		zombie_init_para,
		Vector2(global_position.x, zombie_parent.zombie_create_position.global_position.y),
		GlobalUtils.get_special_zombie_callable(imitater_zombie_type, plant_cell)
	)
	_apply_imitater_zombie_effects(zombie)


func _apply_imitater_zombie_effects(zombie:Zombie000Base):
	if not is_instance_valid(zombie):
		return
	zombie.be_hypno()
	if is_instance_valid(zombie.body):
		_apply_imitater_zombie_material(zombie.body)


func _apply_imitater_zombie_material(zombie_body:BodyCharacter):
	zombie_body.imitater_update_material()
	if zombie_body.material is ShaderMaterial:
		var mat:ShaderMaterial = zombie_body.material
		mat.set_shader_parameter(&"tint_color", imitater_zombie_tint_color)
		mat.set_shader_parameter(&"whiteness", imitater_zombie_whiteness)
		mat.set_shader_parameter(&"gray_strength", imitater_zombie_gray_strength)
		mat.set_shader_parameter(&"brightness", imitater_zombie_brightness)
		mat.set_shader_parameter(&"contrast", imitater_zombie_contrast)
