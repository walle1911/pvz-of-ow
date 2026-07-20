extends Zombie000Base
class_name Zombie026PeashooterZombie

## 豌豆射手僵尸(026)
## 身体完全复用普通僵尸(zombie_500_norm): 移动/受击/死亡/状态机/行走动画全部继承。
## 头部复用普通豌豆射手头部(PeashooterHead 场景)，镜像后朝植物方向。
## 头部直接挂在 BodyCorrect 下，只继承 Zombie_body 的位置和缩放，
## 不继承其旋转，以保持平视并连接身体。
## 远程攻击由 AttackComponentBulletPeashooterZombie 驱动: 边走边射(不停步)，
## 近战啃食仍按普通僵尸规则(贴脸时停下啃)。

@onready var attack_bullet: AttackComponentBulletPeashooterZombie = %AttackComponentBullet
@onready var peashooter_head: PeashooterHead = %PeashooterHead
@onready var zombie_body: Node2D = $Body/BodyCorrect/Zombie_body

var _head_offset_in_body_scale := Vector2.ZERO
var _head_scale_ratio_to_body := Vector2.ONE
var _head_fixed_rotation := 0.0
var _is_head_body_follow_enabled := false

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
	## 在 AnimationTree 更新 Zombie_body 后再同步豌豆头。
	process_priority = 100
	super()
	attack_bullet.configure_sojourn_attack(
		pea_shot_interval,
		pea_attack_damage,
		pea_projectile_scale,
		laser_penetration_damage
	)
	_setup_markers_2d_bullet()
	_setup_head_body_follow()
	_random_anim_status()

func _process(_delta: float) -> void:
	if not _is_head_body_follow_enabled:
		return
	if not is_instance_valid(peashooter_head) or not is_instance_valid(zombie_body):
		return
	peashooter_head.position = zombie_body.position + Vector2(
		_head_offset_in_body_scale.x * zombie_body.scale.x,
		_head_offset_in_body_scale.y * zombie_body.scale.y
	)
	peashooter_head.scale = Vector2(
		_head_scale_ratio_to_body.x * zombie_body.scale.x,
		_head_scale_ratio_to_body.y * zombie_body.scale.y
	)
	peashooter_head.rotation = _head_fixed_rotation

func _setup_head_body_follow() -> void:
	if not is_instance_valid(peashooter_head) or not is_instance_valid(zombie_body):
		return
	if is_zero_approx(zombie_body.scale.x) or is_zero_approx(zombie_body.scale.y):
		return
	var initial_offset := peashooter_head.position - zombie_body.position
	_head_offset_in_body_scale = Vector2(
		initial_offset.x / zombie_body.scale.x,
		initial_offset.y / zombie_body.scale.y
	)
	_head_scale_ratio_to_body = Vector2(
		peashooter_head.scale.x / zombie_body.scale.x,
		peashooter_head.scale.y / zombie_body.scale.y
	)
	_head_fixed_rotation = peashooter_head.rotation
	_is_head_body_follow_enabled = true

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

## 死亡动画开始时停止头部动画
func anim_death_start():
	_is_head_body_follow_enabled = false
	if is_instance_valid(peashooter_head):
		peashooter_head.stop()
		peashooter_head.visible = false

## 初始化展示角色(关卡前展示、图鉴)
func ready_show():
	super()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
	if is_instance_valid(attack_bullet):
		attack_bullet.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
