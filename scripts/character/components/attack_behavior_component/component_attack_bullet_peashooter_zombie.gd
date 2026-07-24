extends AttackComponentBulletBase
class_name AttackComponentBulletPeashooterZombie

## 豌豆射手僵尸(026)的子弹攻击组件。
## - 用独立 DetectComponentBullet 检测植物(替换基类会误绑的近战 DetectComponent)
## - 攻击时让 PeashooterHead 播放 Head_Attack；发射时机由头部动画的方法轨道
##   回调 PeashooterHead._shoot_bullet() -> fire_pea 信号 -> 本组件 _shoot_bullet()
## - 修复026失败根因之一: 僵尸豌豆必须把 Area2DAttack.collision_mask 覆盖为
##   257(1 斜坡 | 256 植物真实受击层)，且必须在 bullets.add_child 之后设置——
##   因为 area_2d_attack 是 @onready，节点进树前为 null，提前设置不生效(026 因此豌豆穿模植物)
## - _try_auto_find_marker: 攻击组件自我定位 Marker2DBullet，不依赖外部脚本

@onready var peashooter_head: PeashooterHead = %PeashooterHead

const PLANT_DETECTION_MASK := 2
const ZOMBIE_PEA_DIRECTION := Vector2.LEFT
## 植物真实受击层 256 + 斜坡 1(植物真实层见 component_detect.gd C_LayTypeValueReal[ZombieEnemy]=256+1024)
const ZOMBIE_PEA_ATTACK_MASK := 257
const PEAS_BEFORE_LASER := 4
const PRE_LASER_PAUSE := 1.0
const POST_LASER_PAUSE := 1.5
## Head_Attack 动画方法轨道中的实际开火时间。
const HEAD_ATTACK_FIRE_TIME := 0.916667

@export var detect_refresh_time := 0.2
var pea_shot_interval := 0.45
var pea_attack_damage := 10
var pea_projectile_scale := 0.7
var laser_penetration_damage := 80
var laser_bullet_type := BulletRegistry.BulletType.Bullet020SojournTracer

var _detect_refresh_left := 0.0
var _pea_shots_in_cycle := 0

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
	## 尽早定位 Marker2DBullet，不依赖僵尸脚本外部设置
	_try_auto_find_marker()
	## 每次实际开火后再安排下一次攻击，避免循环 Timer 在长停顿期间
	## 重启动画、吞掉后续连发。
	bullet_attack_cd_timer.one_shot = true

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

## 从索杰恩僵尸根节点的 Inspector 参数同步攻击数值。
func configure_sojourn_attack(new_pea_interval:float, new_pea_damage:int, new_pea_scale:float, new_laser_damage:int):
	pea_shot_interval = maxf(new_pea_interval, 0.1)
	pea_attack_damage = maxi(new_pea_damage, 1)
	pea_projectile_scale = maxf(new_pea_scale, 0.05)
	laser_penetration_damage = maxi(new_laser_damage, 1)
	attack_cd = pea_shot_interval
	var effective_speed := owner_speed_product * get_attack_speed_multiplier()
	if not is_zero_approx(effective_speed):
		bullet_attack_cd_timer.wait_time = pea_shot_interval / effective_speed

## 攻击间隔到时播放头部攻击动画；真正发射由 Head_Attack 方法轨道回调 _shoot_bullet
func _on_bullet_attack_cd_timer_timeout() -> void:
	_try_auto_find_marker()
	if is_instance_valid(peashooter_head):
		peashooter_head.play_attack(_get_attack_animation_speed())
	else:
		_shoot_bullet()

## 让完整攻击动画在下一次射击计时前播完，避免高速射击反复重启动画而漏弹。
func _get_attack_animation_speed() -> float:
	if not is_instance_valid(peashooter_head) or not is_instance_valid(peashooter_head.anim):
		return 1.0
	var attack_animation := peashooter_head.anim.get_animation(&"Head_Attack")
	if attack_animation == null:
		return 1.0
	return maxf(1.0, attack_animation.length / maxf(_get_regular_shot_interval(), 0.01))

## 从 PeashooterHead 内部定位 Marker2DBullet，不依赖外部设置
func _try_auto_find_marker() -> void:
	if not markers_2d_bullet.is_empty():
		return  # 已设置，跳过
	if not is_instance_valid(peashooter_head):
		return
	var marker = peashooter_head.get_node_or_null("Anim_stem/stem_correct/Marker2DBullet")
	if is_instance_valid(marker):
		markers_2d_bullet = [marker]

## 动画开火帧：四发豌豆、停顿、蓝色穿透激光、再停顿后循环。
func _shoot_bullet():
	_try_auto_find_marker()  # 最后兜底
	if markers_2d_bullet.is_empty():
		return
	signal_shoot_bullet.emit()
	if _pea_shots_in_cycle >= PEAS_BEFORE_LASER:
		_shoot_penetrating_laser()
		_pea_shots_in_cycle = 0
		_schedule_next_shot(POST_LASER_PAUSE)
	else:
		_shoot_pea()
		_pea_shots_in_cycle += 1
		if _pea_shots_in_cycle >= PEAS_BEFORE_LASER:
			_schedule_next_shot(PRE_LASER_PAUSE)
		else:
			_schedule_next_shot(_get_regular_shot_interval())

## 当前攻速下，两次普通豌豆实际开火的目标间隔。
func _get_regular_shot_interval() -> float:
	var effective_speed := owner_speed_product * get_attack_speed_multiplier()
	if is_zero_approx(effective_speed):
		return pea_shot_interval
	return pea_shot_interval / effective_speed

## Timer 使用单次模式；扣除下一次攻击动画到开火帧的时间，
## 让两次实际弹丸之间满足指定间隔，同时避免自动循环重启动画。
func _schedule_next_shot(interval:float):
	if not is_attack_res:
		return
	var next_attack_speed := _get_attack_animation_speed()
	var next_fire_delay := HEAD_ATTACK_FIRE_TIME / maxf(next_attack_speed, 0.01)
	bullet_attack_cd_timer.start(maxf(interval - next_fire_delay, 0.01))

## 发射僵尸阵营豌豆，固定向左(植物方向)。
func _shoot_pea():
	for i in range(markers_2d_bullet.size()):
		if not is_instance_valid(markers_2d_bullet[i]):
			continue
		var bullet: Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
		bullet.bullet_camp = CharacterRegistry.CharacterType.Zombie
		_mark_bullet_source_for_recording(bullet)
		var bullet_paras = get_bullet_paras(markers_2d_bullet[i].global_position, ZOMBIE_PEA_DIRECTION)
		bullet_paras[Bullet000NormBase.E_InitParasAttr.AttackValue] = pea_attack_damage
		_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		bullet.scale *= Vector2.ONE * pea_projectile_scale
		## 关键: add_child 之后 @onready area_2d_attack 才解析，此时覆盖 collision_mask 才生效
		if bullet is Bullet000NormBase and is_instance_valid((bullet as Bullet000NormBase).area_2d_attack):
			(bullet as Bullet000NormBase).area_2d_attack.collision_mask = ZOMBIE_PEA_ATTACK_MASK
		play_throw_sfx()

## 激光即时贯穿检测射线上的所有植物，每株只受击一次。
func _shoot_penetrating_laser():
	var targets:Array[Character000Base] = detect_component.get_all_enemy_can_be_attacked()
	if targets.is_empty():
		return
	for marker:Marker2D in markers_2d_bullet:
		if not is_instance_valid(marker):
			continue
		var bullet:Bullet000Base = Global.bullet_registry.get_bullet_scenes(laser_bullet_type).instantiate()
		bullet.bullet_camp = CharacterRegistry.CharacterType.Zombie
		_mark_bullet_source_for_recording(bullet)
		var bullet_paras := get_bullet_paras(marker.global_position, ZOMBIE_PEA_DIRECTION)
		bullet_paras[Bullet000NormBase.E_InitParasAttr.Enemy] = targets
		bullet_paras[Bullet000NormBase.E_InitParasAttr.AttackValue] = laser_penetration_damage
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		play_throw_sfx()
