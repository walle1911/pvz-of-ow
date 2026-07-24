extends AttackComponentBulletBase
class_name AttackComponentBulletZombie

## 豌豆射手头僵尸专用的子弹攻击组件
## 解决：基类的 %DetectComponent 会找到近战 DetectComponent
## 我们用独立的 DetectComponentBullet 做远程检测
@onready var head_anim: AnimationPlayer = $"../HeadAnimPlayer"

const PLANT_DETECTION_MASK := 2
const ZOMBIE_PEA_DIRECTION := Vector2.LEFT

@export var detect_refresh_time := 0.2

var _detect_refresh_left := 0.0

func _ready() -> void:
	## 在 super() 调用前，把 detect_component 替换成本身的子弹检测组件
	## 这样基类 _ready() 中的信号连接就会走正确的检测组件
	var bullet_detect: DetectComponent = $DetectComponentBullet
	if is_instance_valid(bullet_detect):
		bullet_detect.can_attack_plant_status = 15
		bullet_detect.can_attack_zombie_status = 0
		detect_component = bullet_detect
	super()
	_configure_detect_component()

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

## 攻击间隔到时先播放头部攻击动画。
## 真正发射由 Head_Attack 的方法轨道调用 _shoot_bullet，保证嘴部动作和豌豆同步。
func _on_bullet_attack_cd_timer_timeout() -> void:
	if is_instance_valid(head_anim) and head_anim.has_animation(&"Head_Attack"):
		head_anim.stop()
		head_anim.play(&"Head_Attack")
	else:
		_shoot_bullet()

## 发射僵尸阵营豌豆，固定向左攻击植物。
func _shoot_bullet():
	signal_shoot_bullet.emit()
	for i in range(markers_2d_bullet.size()):
		var bullet: Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
		bullet.bullet_camp = CharacterRegistry.CharacterType.Zombie
		_mark_bullet_source_for_recording(bullet)
		var bullet_paras = get_bullet_paras(markers_2d_bullet[i].global_position, ZOMBIE_PEA_DIRECTION)
		_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		play_throw_sfx()
