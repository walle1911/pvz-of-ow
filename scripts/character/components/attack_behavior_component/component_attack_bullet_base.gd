extends AttackComponentBase
## 发射子弹攻击行为基础组件
class_name AttackComponentBulletBase

@onready var animation_tree: AnimationTree = $"../AnimationTree"
## 冷却时间计时器
@onready var bullet_attack_cd_timer: Timer = $BulletAttackCdTimer

## 用检测组件对应的值赋值，仙人掌会修改值更新子弹属性
## 当前发射子弹可以攻击的敌人状态
##("1 正常", "2 悬浮", "4 地刺", "8 低矮")
var can_attack_plant_status:int = 1
##("1 正常", "2 跳跃", "4 水下", "8 空中", "16 地下")
var can_attack_zombie_status:int = 1
## 是否使用行属性进行攻击判断
var is_lane:=true

## 攻击参数,动画攻击一次的参数
@export var attack_para:StringName= &"parameters/OneShot/request"
## 子弹攻击伤害（为正数时覆盖子弹场景默认伤害）
@export var attack_value_bullet:int = -1
@export var attack_cd:float = 1.5
## 攻击子弹类型
@export var attack_bullet_type:BulletRegistry.BulletType = BulletRegistry.BulletType.Bullet001Pea
## 子弹生产位置
@export var markers_2d_bullet: Array[Marker2D]
@export_group("发射子弹音效")
## 攻击音效名字（发射子弹）
@export var attack_sfx:StringName = &"Throw"

## 发射一次子弹信号
signal signal_shoot_bullet

## 主游戏场景子弹父节点
var bullets: Node2D
## 仅影响射击间隔的攻速倍率来源。多个来源取最高值，避免重复强化指数叠加。
var attack_speed_multiplier_sources:Dictionary[int, float] = {}
var owner_speed_product := 1.0
func _ready() -> void:
	super()
	bullet_attack_cd_timer.wait_time = attack_cd
	if is_instance_valid(Global.main_game):
		bullets = Global.main_game.bullets
	## 用检测组件对应的值赋值，仙人掌会修改值更新子弹属性
	can_attack_plant_status = detect_component.can_attack_plant_status
	##("1 正常", "2 跳跃", "4 水下", "8 空中", "16 地下")
	can_attack_zombie_status = detect_component.can_attack_zombie_status
	## 是否使用行属性进行攻击判断
	is_lane = detect_component.is_lane


## 角色速度修改
func owner_update_speed(speed_product:float):
	var old_effective_speed := owner_speed_product * get_attack_speed_multiplier()
	owner_speed_product = speed_product
	_apply_effective_attack_speed(old_effective_speed)


## 增加一个仅影响射击间隔的攻速倍率来源。
func add_attack_speed_multiplier(source:Object, multiplier:float):
	if not is_instance_valid(source):
		return
	var old_effective_speed := owner_speed_product * get_attack_speed_multiplier()
	attack_speed_multiplier_sources[source.get_instance_id()] = maxf(multiplier, 0.0)
	_apply_effective_attack_speed(old_effective_speed)


## 移除一个攻速倍率来源。
func remove_attack_speed_multiplier(source:Object):
	if not is_instance_valid(source):
		return
	var old_effective_speed := owner_speed_product * get_attack_speed_multiplier()
	attack_speed_multiplier_sources.erase(source.get_instance_id())
	_apply_effective_attack_speed(old_effective_speed)


## 获取当前额外攻速倍率，多个来源取最高值。
func get_attack_speed_multiplier() -> float:
	var result := 1.0
	for multiplier:float in attack_speed_multiplier_sources.values():
		result = maxf(result, multiplier)
	return result


func _apply_effective_attack_speed(old_effective_speed:float):
	var new_effective_speed := owner_speed_product * get_attack_speed_multiplier()
	if not bullet_attack_cd_timer.is_stopped():
		if is_zero_approx(new_effective_speed):
			bullet_attack_cd_timer.paused = true
		else:
			bullet_attack_cd_timer.paused = false
			if not is_zero_approx(old_effective_speed):
				bullet_attack_cd_timer.start(
					bullet_attack_cd_timer.time_left * old_effective_speed / new_effective_speed
				)

	if not is_zero_approx(new_effective_speed):
		bullet_attack_cd_timer.wait_time = attack_cd / new_effective_speed

## 开始攻击
func attack_start():
	super()
	## 先随机等待一段时间调用一次攻击
	await get_tree().create_timer(randf_range(0, bullet_attack_cd_timer.wait_time/3)).timeout
	if is_attack_res:
		## 首次攻击还未使用计时器循环攻击
		if bullet_attack_cd_timer.is_stopped():
			_on_bullet_attack_cd_timer_timeout()
			bullet_attack_cd_timer.start()
	## 等待一段时间后可能为非攻击状态
	else:
		attack_end()

## 结束攻击
func attack_end():
	super()
	bullet_attack_cd_timer.stop()
	set_cancel_attack()


## 攻击间隔后触发执行攻击
func _on_bullet_attack_cd_timer_timeout() -> void:
	# 在这里调用实际攻击逻辑
	animation_tree.set(attack_para, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_cancel_attack():
	#animation_tree.set(attack_para, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	pass

## 发射子弹（动画调用）
func _shoot_bullet():
	signal_shoot_bullet.emit()
	for i in range(markers_2d_bullet.size()):
		var bullet:Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
		_mark_bullet_source_for_recording(bullet)
		configure_bullet_before_init(bullet)
		var bullet_paras = get_bullet_paras(markers_2d_bullet[i].global_position, detect_component.ray_area_direction[i])
		_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
		#print(bullet_paras)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		play_throw_sfx()


## 录制导演关卡用此弱引用让在途子弹跟随发射者的冻结归属。
func _mark_bullet_source_for_recording(bullet: Bullet000Base) -> void:
	var current_node: Node = self
	while is_instance_valid(current_node):
		if current_node is Character000Base:
			(current_node as Character000Base).mark_bullet_recording_source(bullet)
			return
		current_node = current_node.get_parent()
	if is_instance_valid(owner) and owner is Character000Base:
		(owner as Character000Base).mark_bullet_recording_source(bullet)


## 子类可在标准初始化前向专属子弹注入发射者或状态。
func configure_bullet_before_init(_bullet: Bullet000Base) -> void:
	pass


func get_bullet_paras(marker_2d_bullet_glo_pos:Vector2, ray_direction:Vector2) -> Dictionary[Bullet000NormBase.E_InitParasAttr,Variant]:
	return {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane : is_lane,
		Bullet000NormBase.E_InitParasAttr.BulletLane : owner.lane,
		Bullet000NormBase.E_InitParasAttr.Position : bullets.to_local(marker_2d_bullet_glo_pos),
		Bullet000NormBase.E_InitParasAttr.Direction : ray_direction,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState : can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState : can_attack_zombie_status,
		Bullet000NormBase.E_InitParasAttr.AttackValue : attack_value_bullet,
	}

func _apply_owner_damage_multiplier_to_bullet_paras(bullet:Bullet000Base, bullet_paras:Dictionary):
	if not owner is Plant000Base:
		return
	var owner_plant:Plant000Base = owner
	var damage_multiplier := owner_plant.get_attack_damage_multiplier()
	if is_equal_approx(damage_multiplier, 1.0):
		return
	if not bullet is Bullet000NormBase:
		return
	var base_attack_value:int = attack_value_bullet
	if base_attack_value <= 0:
		base_attack_value = (bullet as Bullet000NormBase).attack_value
	bullet_paras[Bullet000NormBase.E_InitParasAttr.AttackValue] = maxi(1, int(round(float(base_attack_value) * damage_multiplier)))


func play_throw_sfx():
	## 播放音效
	SoundManager.play_character_SFX(attack_sfx)
