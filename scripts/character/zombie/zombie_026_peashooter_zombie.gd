extends Zombie000Base
class_name Zombie026PeashooterZombie

## 豌豆射手僵尸(026)
## 身体完全复用普通僵尸(zombie_500_norm): 移动/受击/死亡/状态机/行走动画全部继承。
## 头部复用普通豌豆射手头部(PeashooterHead 场景)，镜像后朝植物方向。
## 远程攻击由 AttackComponentBulletPeashooterZombie 驱动: 边走边射(不停步)，
## 近战啃食仍按普通僵尸规则(贴脸时停下啃)。

@onready var attack_bullet: AttackComponentBulletPeashooterZombie = %AttackComponentBullet
@onready var peashooter_head: PeashooterHead = %PeashooterHead

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
	## 先设置 markers_2d_bullet（必须在 attack 启用之前，否则 CD 触发时
	## markers 为空数组，_shoot_bullet 访问空 index 会崩溃）
	if is_instance_valid(peashooter_head):
		var marker = peashooter_head.get_node_or_null("Anim_stem/stem_correct/Marker2DBullet")
		if is_instance_valid(marker):
			attack_bullet.markers_2d_bullet = [marker]
	## 启用远程子弹攻击(不禁用近战，两者共存)
	attack_bullet.update_is_attack_factors(true, AttackComponentBase.E_IsAttackFactors.Character)
	## 头部待机动画由 PeashooterHead 自身 _ready 播放

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 速度影响子弹攻击CD
	signal_update_speed.connect(attack_bullet.owner_update_speed)
	## 边走边射: 远程攻击不停止身体移动(不连接 move_component)。
	## 近战啃食仍由基类 AttackComponent 的 signal_change_is_attack -> move_component 停下。
	## 死亡时禁用子弹攻击
	hp_component.signal_hp_component_death.connect(attack_bullet.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Death))

## 死亡动画开始时停止头部动画
func anim_death_start():
	if is_instance_valid(peashooter_head):
		peashooter_head.stop()

## 初始化展示角色(关卡前展示、图鉴)
func ready_show():
	super()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
	if is_instance_valid(attack_bullet):
		attack_bullet.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
