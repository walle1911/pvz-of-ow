extends Node2D
class_name HpComponent

@onready var owner_character: Character000Base = owner

@onready var progress_bar_hp: ProgressBar = %ProgressBarHp
@onready var label_hp: Label = %LabelHp

const _HP_CONTROL_FOOT_POSITION := Vector2(0.0, 28.0)
const _HP_STACK_FOOT_POSITION := Vector2(-33.0, 14.0)

@export var max_hp:int
## 本体受击音效
@export var sfx_be_attack_body :SoundManagerClass.TypeBeAttackSFX= SoundManagerClass.TypeBeAttackSFX.Null

## 是否可以查看血条(norm正常出战角色可以)
var is_can_look_hp:=true
## 角色是否死亡，判断是否发射死亡信号
var is_death := false

var death_hp:int = 0
## 受到伤害倍率来源。安娜纳米强化使用 0.7 表示减伤 30%。
var damage_taken_multiplier_sources:Dictionary[int, float] = {}
var _ignore_damage_reduction_once := false
var curr_hp:int:
	set(value):
		value = max(value, 0)
		curr_hp = value
		label_hp.text = str(curr_hp)
		progress_bar_hp.value = float(curr_hp) / max_hp

		## 如果血量小于死亡血量临界值,并且角色还未死亡时
		if value <= death_hp and not is_death:
			is_death = true
			## 角色死亡
			signal_hp_component_death.emit()


## 血量损失信号(curr_hp:当前血量值),给血量变化组件(僵尸\坚果\南瓜)使用
signal signal_hp_loss(curr_hp:int, is_drop:bool)
## 血量组件检测到死亡信号
signal signal_hp_component_death

func _ready() -> void:
	place_hp_display_at_feet()
	curr_hp = max_hp
	## 出战角色连接信号，显示血量
	if owner_character.character_init_type == Character000Base.E_CharacterInitType.IsNorm:
		if self is HpComponentZombie:
			visible = Global.config_service.display_zombie_HP_label
			Global.config_service.signal_change_display_zombie_HP_label.connect(change_display_HP_label)

		else:
			visible = Global.config_service.display_plant_HP_label
			Global.config_service.signal_change_display_plant_HP_label.connect(change_display_HP_label)
	else:
		is_can_look_hp = false
		visible = false

func change_display_HP_label(value:bool):
	if is_can_look_hp:
		visible = value

func place_hp_display_at_feet() -> void:
	var hp_display_root := _get_hp_display_root()
	if not is_instance_valid(hp_display_root):
		return
	if hp_display_root is VBoxContainer:
		hp_display_root.position = _HP_STACK_FOOT_POSITION
	else:
		hp_display_root.position = _HP_CONTROL_FOOT_POSITION

func _get_hp_display_root() -> Control:
	var hp_stack := get_node_or_null("VBoxContainer") as Control
	if is_instance_valid(hp_stack):
		return hp_stack
	return get_node_or_null("HpControl") as Control

func set_death_hp(new_death_hp:int):
	self.death_hp = new_death_hp

func get_all_hp():
	return curr_hp

## attack_value(int): 掉血的值
## bullet_mode(AttackMode): 伤害类型
## trigger_be_attack_SFX:=true:是否触发受击音效
## [is_drop_on_death:bool] 死亡时是否有掉落
## [is_drop_2:bool] 是否有掉落额外条件
## return bool: 返回是否死亡
func Hp_loss(attack_value:int, _bullet_mode:BulletRegistry.AttackMode =BulletRegistry.AttackMode.Norm, is_drop_on_death=true, trigger_be_attack_SFX:=true, is_drop_2:=true):
	var final_attack_value := attack_value
	if not _ignore_damage_reduction_once and attack_value > 0:
		final_attack_value = maxi(1, int(round(float(attack_value) * get_damage_taken_multiplier())))
	_ignore_damage_reduction_once = false
	curr_hp -= final_attack_value
	var is_drop = not (owner.is_death and not is_drop_on_death) and is_drop_2
	signal_hp_loss.emit(curr_hp, is_drop)

	## 如果有受击音效并且触发受击音效
	if sfx_be_attack_body != SoundManager.TypeBeAttackSFX.Null and trigger_be_attack_SFX:
		SoundManager.play_be_attack_SFX(sfx_be_attack_body)

	return curr_hp == 0

## 掉血死亡
##[is_drop:bool]是否有掉落body
func Hp_loss_death(is_drop:=true):
	_ignore_damage_reduction_once = true
	Hp_loss(get_all_hp(),BulletRegistry.AttackMode.Norm, is_drop, false)
	_ignore_damage_reduction_once = false

## 增加一个受到伤害倍率来源。
func add_damage_taken_multiplier(source:Object, multiplier:float):
	if not is_instance_valid(source):
		return
	damage_taken_multiplier_sources[source.get_instance_id()] = maxf(multiplier, 0.0)

## 移除一个受到伤害倍率来源。
func remove_damage_taken_multiplier(source:Object):
	if not is_instance_valid(source):
		return
	damage_taken_multiplier_sources.erase(source.get_instance_id())

## 不同减伤来源乘算；当前安娜强化只会存在一个实例。
func get_damage_taken_multiplier() -> float:
	var result := 1.0
	for multiplier:float in damage_taken_multiplier_sources.values():
		result *= multiplier
	return result
