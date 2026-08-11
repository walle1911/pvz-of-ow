extends Zombie000Base
class_name Zombie026PeashooterZombie

## 豌豆射手僵尸(026)
## 身体完全复用普通僵尸(zombie_501_norm): 移动/受击/死亡/状态机/行走动画全部继承。
## 头部复用普通豌豆射手头部(PeashooterHead 场景)，镜像后朝植物方向。
## 头部直接挂在 BodyCorrect 下，只继承 Zombie_body 的位置和缩放，
## 不继承其旋转，以保持平视并连接身体。
## 远程攻击由 AttackComponentBulletPeashooterZombie 驱动: 边走边射(不停步)，
## 近战啃食仍按普通僵尸规则(贴脸时停下啃)。

@onready var attack_bullet: AttackComponentBulletPeashooterZombie = %AttackComponentBullet
@onready var peashooter_head: PeashooterHead = %PeashooterHead
@onready var head_drop_body: Node2D = $Body/NodeDrop/Node2D_Head_Drop/Head_Drop

var _is_peashooter_head_dropped := false
var _is_raw_potato_poisoned := false

const DAMAGE_MULTIPLIER := 0.5

@export_group("索杰恩远程攻击")
@export_range(0.1, 30.0, 0.05, "or_greater") var pea_shot_interval := 0.45
@export_range(1, 10000, 1, "or_greater") var pea_attack_damage := 10
@export_range(0.05, 2.0, 0.05, "or_greater") var pea_projectile_scale := 0.7
@export_range(1, 10000, 1, "or_greater") var laser_penetration_damage := 80

@export_group("动画状态")
@export var idle_status := 1
## 身体使用第 2 套走路动画；豌豆头不再继承其头部轨道。
@export var walk_status := 2
@export var death_status := 1

@export_subgroup("最大动画状态")
@export var idle_status_max := 2
@export var death_status_max := 2

func _ready() -> void:
	super()
	## 索杰恩的近战啮食、普通豌豆和穿透激光统一按原始数值的 50% 结算。
	var melee_attack := attack_component as AttackComponentZombieNorm
	if is_instance_valid(melee_attack):
		melee_attack.init_attack_value_per_min = maxi(
			roundi(float(melee_attack.init_attack_value_per_min) * DAMAGE_MULTIPLIER),
			1
		)
		melee_attack.curr_attack_value_per_min = melee_attack.init_attack_value_per_min
	attack_bullet.configure_sojourn_attack(
		pea_shot_interval,
		maxi(roundi(float(pea_attack_damage) * DAMAGE_MULTIPLIER), 1),
		pea_projectile_scale,
		maxi(roundi(float(laser_penetration_damage) * DAMAGE_MULTIPLIER), 1)
	)
	_setup_markers_2d_bullet()
	_random_anim_status()

## 尽早设置 markers_2d_bullet，防止任何时机 _shoot_bullet 被触发时数组为空
func _setup_markers_2d_bullet():
	if not is_instance_valid(peashooter_head) or not is_instance_valid(attack_bullet):
		return
	var marker = peashooter_head.get_node_or_null("Anim_stem/stem_correct/Marker2DBullet")
	if is_instance_valid(marker) and attack_bullet.markers_2d_bullet.is_empty():
		attack_bullet.markers_2d_bullet = [marker]

func _random_anim_status():
	idle_status = randi_range(1, idle_status_max)
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
	## 沿用普通僵尸的掉头血量阶段，但把真正显示的 PeashooterHead 放进掉落节点。
	hp_stage_change_component.signal_hp_stage_change.connect(_on_hp_stage_change_drop_peashooter_head)

func _on_hp_stage_change_drop_peashooter_head(hp_stage: int) -> void:
	if hp_stage < 1 or _is_peashooter_head_dropped:
		return
	if not is_instance_valid(peashooter_head) or not is_instance_valid(head_drop_body):
		return
	peashooter_head.stop_follow()
	peashooter_head.reparent(head_drop_body, true)
	_is_peashooter_head_dropped = true

## 啃到未成熟土豆雷后的专属中毒。视觉直接复用魅惑菇已有的成品变色，
## 死亡沿用血量组件和僵尸原有死亡状态机。
func be_poisoned_by_raw_potato_mine() -> void:
	if _is_raw_potato_poisoned or is_death:
		return
	_is_raw_potato_poisoned = true
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	attack_bullet.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	## 锁住根节点位移，同时把动画速度降为 0，保持触发中毒时的原地僵直姿势。
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsCharacter)
	update_speed_factor(0.0, Character000Base.E_Influence_Speed_Factor.RawPotatoPoison)
	## 只复用魅惑后的视觉效果，不调用 be_hypno()，不改变阵营和碰撞层。
	body.owner_be_hypno()
	await get_tree().create_timer(0.8, false).timeout
	if is_instance_valid(self) and not is_death:
		## 恢复动画速度后再进入原有死亡状态机；位移仍由中毒/死亡因素锁定。
		update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.RawPotatoPoison)
		hp_component.Hp_loss_death()

## 死亡动画开始时停止头部动画
func anim_death_start():
	## 已经进入掉落节点的头部继续由 ZombieDropBase 驱动，不能再隐藏。
	if is_instance_valid(peashooter_head) and not _is_peashooter_head_dropped:
		peashooter_head.stop_follow()
		peashooter_head.stop()
		peashooter_head.visible = false

## 初始化展示角色(关卡前展示、图鉴)
func ready_show():
	super()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
	if is_instance_valid(attack_bullet):
		attack_bullet.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
