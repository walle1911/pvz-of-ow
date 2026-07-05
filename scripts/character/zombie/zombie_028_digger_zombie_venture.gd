extends Zombie000Base
class_name Zombie028DiggerZombieVenture

## 铁镐被吸铁石吸走后的问号
@onready var zombie_questionmark: Sprite2D = %ZombieQuestionmark
## 最后一格的x坐标
@export var digger_target_pos_x:float=88

@export_group("动画状态")
## 是否还在掘土状态
@export var is_dig := true
## 是否为正常退出掘土状态
@export var is_norm_end := true
## 跳起结束(被吸铁石吸走后使用)
@export var is_up_end := false
@onready var gpu_particles_dirt: GPUParticles2D = $GPUParticlesDirt
@onready var digger_venture_hair: Sprite2D = $Body/BodyCorrect/Hardhat/Zombie_digger_hardhat/DiggerZombie_Venture_Hair
@onready var zombie_digger_dig: Sprite2D = $Body/BodyCorrect/Zombie_digger_dig

var _hair_clip_material: ShaderMaterial
var _hair_default_material: Material
var _hair_clip_active := false
var _hair_saved_use_parent_material: bool


## 是否可以触发小推车 只有掘土状态下失去铁器道具的矿工可以触发
var is_can_trigger_mower:=false
## 掘土状态失去铁器信号，小推车检测到掘地矿工时订阅
signal signal_can_trigger_mower

func ready_norm():
	super()
	gpu_particles_dirt.emitting = true
	var shader := preload("res://animation/character/zombie/028_digger_zombie_venture/hair_clip.gdshader")
	_hair_clip_material = ShaderMaterial.new()
	_hair_clip_material.shader = shader
	_hair_default_material = digger_venture_hair.material

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.DownGround)

	## 死亡时掘土结束
	hp_component.signal_hp_component_death.connect(dig_end)

## 每帧判断是否到达最后一格
func _process(_delta: float) -> void:
	if is_dig:
		if global_position.x < digger_target_pos_x:
			## 更新方向
			update_direction_x_root(-1)
			dig_end()
		_update_hair_clip()
	else:
		_reset_hair_clip()

func _update_hair_clip() -> void:
	if not _hair_clip_active:
		_hair_clip_active = true
		_hair_saved_use_parent_material = digger_venture_hair.use_parent_material
		digger_venture_hair.use_parent_material = false
		digger_venture_hair.material = _hair_clip_material
	var dig_world_pos := zombie_digger_dig.global_position
	dig_world_pos.y += 12.0
	var clip_local_y := digger_venture_hair.to_local(dig_world_pos).y
	_hair_clip_material.set_shader_parameter("clip_y", clip_local_y)

func _reset_hair_clip() -> void:
	if _hair_clip_active:
		_hair_clip_active = false
		digger_venture_hair.material = _hair_default_material
		digger_venture_hair.use_parent_material = _hair_saved_use_parent_material

## 挖掘结束,出土
func dig_end():
	if is_dig:
		gpu_particles_dirt.emitting = false
		curr_be_attack_status = E_BeAttackStatusZombie.IsNorm
		is_dig = false
		_reset_hair_clip()
		move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
		await zombie_up_from_ground()
		is_up_end = true


## 失去铁器道具
func loss_iron_item():
	super()
	if is_dig:
		#print("掘土时失去铁器")
		is_can_trigger_mower = true
		signal_can_trigger_mower.emit()
		move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
		## 非正常推出掘土状态
		is_norm_end = false
		charred_component.anim_lib_name = "ALL_ANIMS2"
		zombie_questionmark.visible = true
		await get_tree().create_timer(1.0,false).timeout
		zombie_questionmark.visible = false
		dig_end()

## 绝地结束出土结束(动画调用)
func dig_up_end():
	attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.DownGround)
