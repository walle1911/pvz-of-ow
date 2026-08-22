extends Character000Base
class_name Plant000Base

const ECHO_KILLER_COPY_PRE_READY_KEY := &"echo_killer_copy"

@onready var sleep_component: SleepComponent = %SleepComponent
@onready var blink_component: BlinkComponent = %BlinkComponent
## 花园组件
@onready var garden_component: GardenComponent = %GardenComponent

#region 植物类基础属性

@export var plant_type:CharacterRegistry.PlantType
## 数值工坊“烘焙到场景”写入的卡牌权威值；负数表示继续使用注册表默认值。
@export_group("正式卡牌数值")
@export var plant_sun_cost: int = -1
@export var plant_cool_time: float = -1.0
@export_group("")
## 植物初始化受击状态（从1[is_norm] 开始）僵尸攻击检测时判断是否可以攻击
@export var init_be_attack_status :E_BeAttackStatusPlant = E_BeAttackStatusPlant.IsNorm
## 是否白天睡觉
@export var is_sleep_in_day:bool = false
## 植物是否可以挂载梯子(Nrom位置植物使用)
@export var is_can_ladder := false
## 植物当前状态，僵尸攻击检测时判断是否可以攻击
var curr_be_attack_status:E_BeAttackStatusPlant = E_BeAttackStatusPlant.IsNorm
## 行和列
var row_col:Vector2i = Vector2i(-1, -1)
## 植物所在格子
var plant_cell:PlantCell
## 植物死亡后是否直接删除
var is_death_free:= true
## 是否为模仿者材质
var is_imitater_material:=false
## 攻击伤害倍率来源。key 为来源实例 ID，value 为倍率。
var attack_damage_multiplier_sources:Dictionary[int, float] = {}
## Echo 成功变身后的短暂亡语：只记录带有明确僵尸来源的致死攻击。
var _echo_killer_copy_deadline_msec := -1
var _echo_killer_copy_triggered := false
var _echo_killer_copy_effect:Node2D
var _echo_killer_copy_tint_color := Color(0.72, 0.88, 1.0, 1.0)
var _echo_killer_copy_whiteness := 0.62
var _echo_killer_copy_gray_strength := 0.0
var _echo_killer_copy_brightness := 0.08
var _echo_killer_copy_contrast := 0.95
#endregion

#region 植物动画
@export_group("动画状态")
@export var is_sleeping:=false
## 是否在花园水族馆
@export var is_garden_aquarium := false

## 植物梯子状态变化信号
@warning_ignore("unused_signal")
signal signal_ladder_update

#region 角色枚举
## 检测攻击时，根据状态判断是否可以攻击
enum E_BeAttackStatusPlant{
	IsNorm = 1,		## 正常
	IsFloat = 2,	## 悬浮
	IsDown = 4, 	## 地刺
	IsShort = 8,	## 低矮

}
#endregion


#region 花园植物
## 花园初始化数据
var garden_date_init:Dictionary
#endregion


#region 初始化相关
func _ready() -> void:
	super()
	if is_imitater_material:
		plant_imitater_update_body()

	if plant_type == 0:
		push_error(name, "植物类型未赋值")

## 植物初始化属性
enum E_PInitAttr{
	CharacterInitType,	## 角色初始化类型（正常、展示、花园）
	PlantCell,			## 植物格子
	IsImitaterMaterial,	## 是否为模仿者材质
	GardenDate,			## 花园数据
	IsZombieMode,			## 我是僵尸模式
}
## 植物初始化相关, 创建植物时 加入场景树之前赋值
func init_plant(plant_init_para:Dictionary):
	#init_type:E_CharacterInitType=E_CharacterInitType.IsNorm, plant_cell:PlantCell=null, garden_date:Dictionary={}) -> void:
	self.character_init_type = plant_init_para[E_PInitAttr.CharacterInitType]
	self.is_imitater_material = plant_init_para.get(E_PInitAttr.IsImitaterMaterial, false)
	self.is_zombie_mode = plant_init_para.get(E_PInitAttr.IsZombieMode, false)
	match character_init_type:
		E_CharacterInitType.IsNorm:
			self.plant_cell = plant_init_para[E_PInitAttr.PlantCell]
			self.row_col = plant_cell.row_col
			self.lane = plant_cell.row_col.x
		E_CharacterInitType.IsShow:
			### 南瓜背景-1,这里所有植物+1
			#z_index += 1
			pass
		E_CharacterInitType.IsGarden:
			### 南瓜背景-1,这里所有植物+1
			#z_index += 1
			garden_date_init = plant_init_para[E_PInitAttr.GardenDate]
			## 是否为水族馆背景，动画变化
			is_garden_aquarium = garden_date_init["curr_garden_bg_type"] == GardenManager.E_GardenBgType.Aquarium


## 在节点进入场景树前挂载 Echo 的限时亡语状态和备用变身特效。
func apply_common_pre_ready_data(data:Dictionary) -> void:
	var echo_config:Variant = data.get(ECHO_KILLER_COPY_PRE_READY_KEY)
	if not echo_config is Dictionary:
		return
	var config:Dictionary = echo_config
	var window_seconds := maxf(float(config.get(&"window_seconds", 0.0)), 0.0)
	if window_seconds <= 0.0:
		return
	_echo_killer_copy_deadline_msec = Time.get_ticks_msec() + int(window_seconds * 1000.0)
	_echo_killer_copy_tint_color = config.get(&"tint_color", _echo_killer_copy_tint_color)
	_echo_killer_copy_whiteness = float(config.get(&"whiteness", _echo_killer_copy_whiteness))
	_echo_killer_copy_gray_strength = float(config.get(&"gray_strength", _echo_killer_copy_gray_strength))
	_echo_killer_copy_brightness = float(config.get(&"brightness", _echo_killer_copy_brightness))
	_echo_killer_copy_contrast = float(config.get(&"contrast", _echo_killer_copy_contrast))
	var effect:Variant = config.get(&"effect")
	if effect is Node2D:
		_echo_killer_copy_effect = effect
		add_child(_echo_killer_copy_effect)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 发射子弹攻击组件影响植物眨眼
	var attack_component :AttackComponentBulletBase = get_node_or_null(^"AttackComponent")
	if attack_component:
		attack_component.signal_change_is_attack.connect(
			## 可以攻击时禁用眨眼
			func(value):blink_component.change_is_enabling(not value, ComponentNormBase.E_IsEnableFactor.Attack)
		)

	## 植物睡眠组件
	sleep_component.signal_is_sleep.connect(update_is_sleeping.bind(true))
	sleep_component.signal_not_is_sleep.connect(update_is_sleeping.bind(false))

	## 植物睡眠影响的组件
	for sleep_influence_component in sleep_component.sleep_influence_components:
		sleep_component.signal_is_sleep.connect(sleep_influence_component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))
		sleep_component.signal_not_is_sleep.connect(sleep_influence_component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))

## 初始化正常出战角色
func ready_norm():
	super()

	garden_component.queue_free()
	curr_be_attack_status = init_be_attack_status
	## 如果白天睡觉
	if is_sleep_in_day:
		sleep_component.judge_is_sleeping()

	GlobalUtils.update_plant_cell_slope_y_array(plant_cell, node2d_detect_in_slope)

## 初始化展示角色
func ready_show():
	super()
	garden_component.queue_free()



## 初始化花园角色
func ready_garden():
	super()
	garden_component.init_garden_component(garden_date_init)
	sleep_component.signal_is_sleep.connect(garden_component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))
	sleep_component.signal_not_is_sleep.connect(garden_component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))
	## 如果白天睡觉
	if is_sleep_in_day:
		sleep_component.judge_is_sleeping()
	shadow.visible = false

## 植物模仿者更新body颜色
func plant_imitater_update_body():
	body.imitater_update_material()

#endregion

#region 植物受伤、死亡
## 被蹦极僵尸偷走
func be_bungi()->Node2D:
	var body_copy:Node2D = body.duplicate()
	plant_cell.add_child(body_copy)
	body_copy.global_position = body.global_position
	## 死亡直接消失,复制一个body给蹦极
	character_death_disappear()
	return body_copy

## 被僵尸啃食
## attack_value:伤害
## attack_zombie:攻击的僵尸
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	var was_alive := not is_death and not hp_component.is_death
	hp_component.Hp_loss(attack_value,BulletRegistry.AttackMode.Penetration, true, false)
	if was_alive and (is_death or hp_component.is_death):
		_try_echo_copy_killing_zombie(attack_zombie)

## 被僵尸啃食一次发光
func be_zombie_eat_once(attack_zombie:Zombie000Base):
	var was_alive := not is_death and not hp_component.is_death
	body.body_light()
	_be_zombie_eat_once_special(attack_zombie)
	if was_alive and (is_death or hp_component.is_death):
		_try_echo_copy_killing_zombie(attack_zombie)


## 被僵尸啃食一次特殊效果,魅惑\大蒜\我是僵尸生产阳光
func _be_zombie_eat_once_special(_attack_zombie:Zombie000Base):
	pass


## 僵尸子弹保留发射者类型；只有这次命中确实致死时才触发 Echo 亡语。
func be_attacked_bullet_from_zombie(
	attack_value:int,
	bullet_mode:BulletRegistry.AttackMode,
	is_drop:bool,
	trigger_be_attack_SFX:bool,
	attack_zombie_type:CharacterRegistry.ZombieType
) -> void:
	var was_alive := not is_death and not hp_component.is_death
	be_attacked_bullet(attack_value, bullet_mode, is_drop, trigger_be_attack_SFX)
	if was_alive and (is_death or hp_component.is_death):
		_try_echo_copy_killing_zombie_type(attack_zombie_type)


## 带有明确僵尸来源的强制死亡（例如玩偶匣爆炸）。
func be_killed_by_zombie(attack_zombie:Zombie000Base) -> void:
	var was_alive := not is_death and not hp_component.is_death
	character_death_disappear()
	if was_alive and (is_death or hp_component.is_death):
		_try_echo_copy_killing_zombie(attack_zombie)


## 被僵尸碾压致死也属于带有明确攻击者的死亡。
func be_flattened_from_enemy(character:Character000Base):
	var was_alive := not is_death and not hp_component.is_death
	super(character)
	if was_alive and (is_death or hp_component.is_death) and character is Zombie000Base:
		_try_echo_copy_killing_zombie(character)


## 给少数自行结算碾压伤害的植物复用（例如地刺王）。
func try_echo_copy_killing_zombie(attack_zombie:Zombie000Base) -> void:
	if is_death or hp_component.is_death:
		_try_echo_copy_killing_zombie(attack_zombie)


func _try_echo_copy_killing_zombie(attack_zombie:Zombie000Base) -> void:
	if not is_instance_valid(attack_zombie):
		return
	_try_echo_copy_killing_zombie_type(attack_zombie.zombie_type)


func _try_echo_copy_killing_zombie_type(attack_zombie_type:CharacterRegistry.ZombieType) -> void:
	if _echo_killer_copy_triggered \
	or _echo_killer_copy_deadline_msec < 0 \
	or Time.get_ticks_msec() >= _echo_killer_copy_deadline_msec \
	or attack_zombie_type == CharacterRegistry.ZombieType.Null:
		return
	_echo_killer_copy_triggered = true
	_activate_echo_killer_copy_effect()
	_create_echo_imitater_zombie(attack_zombie_type)


func _activate_echo_killer_copy_effect() -> void:
	if not is_instance_valid(_echo_killer_copy_effect):
		return
	_echo_killer_copy_effect.visible = true
	if _echo_killer_copy_effect.has_method(&"activate_it"):
		_echo_killer_copy_effect.activate_it()


func _create_echo_imitater_zombie(zombie_type:CharacterRegistry.ZombieType) -> void:
	if not is_instance_valid(plant_cell) \
	or not is_instance_valid(Global.main_game) \
	or not is_instance_valid(Global.main_game.zombie_manager):
		return
	var lane_index := plant_cell.row_col.x
	if lane_index < 0 or lane_index >= Global.main_game.zombie_manager.all_zombie_rows.size():
		return
	var zombie_parent:ZombieRow = Global.main_game.zombie_manager.all_zombie_rows[lane_index]
	var zombie_init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane:lane_index,
	}
	var init_zombie_special := GlobalUtils.get_special_zombie_callable(zombie_type, plant_cell)
	var recording_stage:Variant = null
	if has_meta(&"recording_freeze_group"):
		recording_stage = get_meta(&"recording_freeze_group")
	## 导演模式会在僵尸创建信号发出时立即按分幕决定显隐。
	## 因此复制体必须在 add_child() 和创建信号之前继承 Echo 植物的分幕。
	var prepare_zombie := Callable(self, &"_prepare_echo_imitater_zombie").bind(
		init_zombie_special,
		recording_stage
	)
	var zombie:Zombie000Base = Global.main_game.zombie_manager.create_norm_zombie(
		zombie_type,
		zombie_parent,
		zombie_init_para,
		Vector2(global_position.x, zombie_parent.zombie_create_position.global_position.y),
		prepare_zombie
	)
	_apply_echo_imitater_zombie_effects(zombie)


func _prepare_echo_imitater_zombie(
	zombie:Zombie000Base,
	init_zombie_special:Callable,
	recording_stage:Variant
) -> void:
	if not init_zombie_special.is_null():
		init_zombie_special.call(zombie)
	if recording_stage != null:
		zombie.set_meta(&"recording_freeze_group", int(recording_stage))


func _apply_echo_imitater_zombie_effects(zombie:Zombie000Base) -> void:
	if not is_instance_valid(zombie):
		return
	zombie.be_hypno()
	if not is_instance_valid(zombie.body):
		return
	zombie.body.imitater_update_material()
	if zombie.body.material is ShaderMaterial:
		var mat:ShaderMaterial = zombie.body.material
		mat.set_shader_parameter(&"tint_color", _echo_killer_copy_tint_color)
		mat.set_shader_parameter(&"whiteness", _echo_killer_copy_whiteness)
		mat.set_shader_parameter(&"gray_strength", _echo_killer_copy_gray_strength)
		mat.set_shader_parameter(&"brightness", _echo_killer_copy_brightness)
		mat.set_shader_parameter(&"contrast", _echo_killer_copy_contrast)

## 植物死亡
func character_death():
	## 发射死亡信号
	super()
	if is_instance_valid(hurt_box_component):
		## 要先删除碰撞器，否则僵尸攻击检测组件有问题
		hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	if is_death_free:
		queue_free()

## 死亡不消失
func character_death_not_disappear():
	is_death_free = false
	hp_component.Hp_loss_death()

#endregion

#region 与铲子\种植交互
## 被铲子威胁
func be_shovel_look():
	if Global.config_service.plant_be_shovel_front:
		z_index += 10
	body.set_other_color(BodyCharacter.E_ChangeColors.BeShovelLookColor, Color(2, 2, 2))

## 被铲子威胁结束
func be_shovel_look_end():
	if Global.config_service.plant_be_shovel_front:
		z_index -= 10
	body.set_other_color(BodyCharacter.E_ChangeColors.BeShovelLookColor, Color(1, 1, 1))

## 被铲子铲除,禁止亡语
func be_shovel_kill():
	is_can_death_language = false
	hp_component.Hp_loss_death()

## 手持紫卡植物可以种植在该植物上
func preplant_purple_body_light_and_dark():
	if Global.config_service.plant_be_shovel_front:
		z_index += 10
	body.body_light_and_dark()

## 手持紫卡植物可以种植在该植物上结束
func preplant_purple_body_light_and_dark_end():
	if Global.config_service.plant_be_shovel_front:
		z_index -= 10
	body.body_light_and_dark_end()

#endregion
## 睡眠植物被咖啡豆唤醒
func coffee_bean_awake_up():
	var tween:Tween = create_tween()
	tween.tween_property(body, ^"scale:y", 0.8, 0.5)
	tween.tween_property(body, ^"scale:y", 1.2, 0.5)
	tween.tween_property(body, ^"scale:y", 1, 0.5)
	tween.tween_callback(sleep_component.end_sleep)


## 植物修改睡眠
func update_is_sleeping(new_is_sleeping:bool):
	self.is_sleeping = new_is_sleeping

## 增加一个攻击伤害倍率来源
func add_attack_damage_multiplier(source:Object, multiplier:float):
	if not is_instance_valid(source):
		return
	attack_damage_multiplier_sources[source.get_instance_id()] = multiplier

## 移除一个攻击伤害倍率来源
func remove_attack_damage_multiplier(source:Object):
	if not is_instance_valid(source):
		return
	attack_damage_multiplier_sources.erase(source.get_instance_id())

## 获取当前攻击伤害倍率。不同来源乘算，使天使蓝线与安娜纳米强化可以同时生效。
func get_attack_damage_multiplier() -> float:
	var result := 1.0
	for multiplier:float in attack_damage_multiplier_sources.values():
		result *= maxf(multiplier, 0.0)
	return result


#region 花园植物
## 满足当前需求
func satisfy_need(item: GardenManager.E_NeedItem):
	garden_component.satisfy_need(item)

## 获取当前花园植物数据
func get_curr_plant_data():
	return garden_component.get_curr_plant_data()
#endregion

## 获取植物存档数据
func gat_save_game_data_plant()->Dictionary:
	var save_game_data_plant:Dictionary = {}
	save_game_data_plant["is_sleeping"] = is_sleeping
	save_game_data_plant["plant_type"] = plant_type
	save_game_data_plant["curr_hp"] = hp_component.curr_hp
	save_game_data_plant["is_imitater_material"] = is_imitater_material
	return save_game_data_plant

## 读档植物数据
func load_game_data_plant(save_game_data_plant:Dictionary):
	## 原本是睡觉，存档不睡觉
	if is_sleeping and not save_game_data_plant.get("is_sleeping", true):
		is_sleeping = false
		sleep_component.end_sleep()

	hp_component.curr_hp = save_game_data_plant["curr_hp"]
	hp_component.signal_hp_loss.emit(hp_component.curr_hp, true)
