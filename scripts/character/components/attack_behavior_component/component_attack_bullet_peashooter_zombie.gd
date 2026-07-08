extends AttackComponentBulletBase
class_name AttackComponentBulletPeashooterZombie

## 豌豆射手僵尸(027)的子弹攻击组件。
## - 用独立 DetectComponentBullet 检测植物(替换基类会误绑的近战 DetectComponent)
## - 攻击时让 PeashooterHead 播放 Head_Attack；发射时机由头部动画的方法轨道
##   回调 PeashooterHead._shoot_bullet() -> fire_pea 信号 -> 本组件 _shoot_bullet()
## - 修复026失败根因之一: 僵尸豌豆必须把 Area2DAttack.collision_mask 覆盖为
##   257(1 斜坡 | 256 植物真实受击层)，且必须在 bullets.add_child 之后设置——
##   因为 area_2d_attack 是 @onready，节点进树前为 null，提前设置不生效(026 因此豌豆穿模植物)

@onready var peashooter_head: PeashooterHead = %PeashooterHead

const PLANT_DETECTION_MASK := 2
const ZOMBIE_PEA_DIRECTION := Vector2.LEFT
## 植物真实受击层 256 + 斜坡 1(植物真实层见 component_detect.gd C_LayTypeValueReal[ZombieEnemy]=256+1024)
const ZOMBIE_PEA_ATTACK_MASK := 257

@export var detect_refresh_time := 0.2

var _detect_refresh_left := 0.0

func _ready() -> void:
	## 在 super() 前把 detect_component 替换成本身的子弹检测组件，
	## 避免基类 _ready 误绑近战 DetectComponent
	var bullet_detect: DetectComponent = $DetectComponentBullet
	if is_instance_valid(bullet_detect):
		bullet_detect.can_attack_plant_status = 15
		bullet_detect.can_attack_zombie_status = 0
		detect_component = bullet_detect
	super()
	_configure_detect_component()
	## 头部开火信号 -> 本组件发射豌豆(发射时机由头部攻击动画的方法轨道决定)
	if is_instance_valid(peashooter_head):
		peashooter_head.fire_pea.connect(_shoot_bullet)

func _physics_process(delta: float) -> void:
	if not is_enabling or not is_instance_valid(detect_component):
		return
	_detect_refresh_left -= delta
	if _detect_refresh_left > 0.0:
		return
	_detect_refresh_left = detect_refresh_time
	detect_component.judge_is_have_enemy()

func _configure_detect_component() -> void:
	if not is_instance_valid(detect_component):
		return
	detect_component.can_attack_plant_status = 15
	detect_component.can_attack_zombie_status = 0
	detect_component.update_curr_collision_lay(2)
	detect_component.curr_collision_lay = PLANT_DETECTION_MASK
	if detect_component.all_ray_area.is_empty():
		for child in detect_component.get_children():
			if child is Area2D:
				detect_component.all_ray_area.append(child)
	detect_component.ray_area_direction.clear()
	for ray_area in detect_component.all_ray_area:
		ray_area.collision_mask = PLANT_DETECTION_MASK
		detect_component.ray_area_direction.append(ZOMBIE_PEA_DIRECTION)
	detect_component.need_judge = true

func update_is_attack_factors(value: bool, factor: E_IsAttackFactors):
	var old_is_attack_res := is_attack_res
	is_attack_factors[factor] = value
	is_attack_res = is_attack_factors.values().all(func(v): return v)
	if is_attack_res == old_is_attack_res:
		return
	if is_attack_res:
		attack_start()
	else:
		attack_end()

## 攻击间隔到时播放头部攻击动画；真正发射由 Head_Attack 方法轨道回调 _shoot_bullet
func _on_bullet_attack_cd_timer_timeout() -> void:
	if is_instance_valid(peashooter_head):
		peashooter_head.play_attack()
	else:
		_shoot_bullet()

## 发射僵尸阵营豌豆，固定向左(植物方向)。
func _shoot_bullet():
	signal_shoot_bullet.emit()
	for i in range(markers_2d_bullet.size()):
		var bullet: Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
		bullet.bullet_camp = CharacterRegistry.CharacterType.Zombie
		var bullet_paras = get_bullet_paras(markers_2d_bullet[i].global_position, ZOMBIE_PEA_DIRECTION)
		_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		## 关键: add_child 之后 @onready area_2d_attack 才解析，此时覆盖 collision_mask 才生效
		if bullet is Bullet000NormBase and is_instance_valid((bullet as Bullet000NormBase).area_2d_attack):
			(bullet as Bullet000NormBase).area_2d_attack.collision_mask = ZOMBIE_PEA_ATTACK_MASK
		play_throw_sfx()