extends Zombie000Base
class_name Zombie026PeashooterHead

## 子弹攻击组件
@onready var attack_bullet: AttackComponentBulletZombie = %AttackComponentBullet
## 头部动画播放器
@onready var head_anim: AnimationPlayer = $HeadAnimPlayer

@export_group("动画状态")
@export var idle_status := 1
@export var walk_status := 1
@export var death_status := 1

@export_subgroup("最大动画状态")
@export var idle_status_max := 2
@export var walk_status_max := 2
@export var death_status_max := 2

func _ready() -> void:
	super()
	_random_anim_status()

func _random_anim_status():
	idle_status = randi_range(1, idle_status_max)
	walk_status = randi_range(1, walk_status_max)
	death_status = randi_range(1, death_status_max)

## 初始化正常出战角色
func ready_norm():
	super()
	## 启用远程子弹攻击（不禁用近战，两者共存）
	attack_bullet.update_is_attack_factors(true, AttackComponentBase.E_IsAttackFactors.Character)
	## 播放头部待机动画
	_play_head_idle()

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 速度影响子弹攻击CD
	signal_update_speed.connect(attack_bullet.owner_update_speed)
	attack_bullet.signal_change_is_attack.connect(move_component.update_move_factor.bind(MoveComponent.E_MoveFactor.IsCharacter))
	## 死亡时禁用子弹攻击
	hp_component.signal_hp_component_death.connect(attack_bullet.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Death))
	if is_instance_valid(head_anim):
		head_anim.animation_finished.connect(_on_head_anim_finished)

## 播放头部待机动画（模拟原版豌豆射手的呼吸动作）
func _play_head_idle():
	if not is_instance_valid(head_anim):
		return
	if head_anim.has_animation("Head_Idle"):
		head_anim.play("Head_Idle")

## 攻击动画播完后回到源豌豆射手待机循环
func _on_head_anim_finished(anim_name: StringName):
	if anim_name == &"Head_Attack" and not is_death:
		_play_head_idle()

## 死亡动画开始时
func anim_death_start():
	if is_instance_valid(head_anim):
		head_anim.stop()

## 初始化展示角色
func ready_show():
	super()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
	if is_instance_valid(attack_bullet):
		attack_bullet.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
