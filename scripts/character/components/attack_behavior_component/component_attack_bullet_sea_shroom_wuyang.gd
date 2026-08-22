extends AttackComponentBulletBase
class_name AttackComponentBulletSeaShroomWuyang

## 海蘑菇无恙专属攻击组件：自动攻击始终使用前方检测，点击本体时额外发射一枚制导弹。

const GUIDED_BULLET_GROUP := &"wuyang_active_guided_bullet"

signal signal_guidance_started
signal signal_guidance_ended

@onready var guidance_attack_cd_timer: Timer = $GuidanceAttackCdTimer

var active_guided_bullet_id := 0

@export_group("无恙射击参数")
## 直射模式单发伤害。
@export_range(1, 10000, 1, "or_greater") var direct_attack_damage := 20
## 直射模式两次射击之间的基础间隔。
@export_range(0.05, 60.0, 0.05, "or_greater", "suffix:秒") var direct_attack_interval := 1.5
## 制导弹刚发射时的伤害。
@export_range(1, 100, 1) var guidance_attack_damage := 20
## 两枚点击制导弹之间的最短发射间隔，限制快速连点的最高攻击频率。
@export_range(0.05, 60.0, 0.05, "or_greater", "suffix:秒") var guidance_attack_interval := 3.0
## 制导弹成长完成后的最大伤害。
@export_range(1, 100, 1) var guidance_max_damage := 100
## 制导弹飞过这段路程后成长到最大体积和伤害。
@export_range(1.0, 5000.0, 1.0, "or_greater", "suffix:像素") var guidance_growth_distance := 800.0
## 制导弹成长完成后的体积倍率。
@export_range(1.0, 10.0, 0.1, "or_greater") var guidance_max_scale_multiplier := 2.5
## 制导弹每秒最多转向的角度；有限转向让鼠标只起引导作用。
@export_range(1.0, 720.0, 1.0, "or_greater", "suffix:度/秒") var guidance_turn_speed_degrees := 240.0
## 制导弹刚出膛时的不透明度，成长完成后会线性变为完全不透明。
@export_range(0.0, 1.0, 0.05) var guidance_start_opacity := 0.35
## 鼠标离开点击位置这么远后才开始提供制导方向，防止停在植物身上时拉回子弹。
@export_range(0.0, 200.0, 1.0, "or_greater", "suffix:像素") var guidance_mouse_deadzone := 24.0
## 制导转向强度从初始倍率成长到完整强度所需时间。
@export_range(0.01, 5.0, 0.05, "or_greater", "suffix:秒") var guidance_turn_ramp_time := 0.6
## 制导刚启动时使用的转向速度倍率。
@export_range(0.0, 1.0, 0.05) var guidance_initial_turn_multiplier := 0.2


func _ready() -> void:
	attack_value_bullet = direct_attack_damage
	attack_cd = direct_attack_interval
	super()
	guidance_attack_cd_timer.one_shot = true
	guidance_attack_cd_timer.wait_time = guidance_attack_interval


## 点击无恙时调用。整局同时只允许存在一枚鼠标引导弹，且发射受独立间隔限制。
func shoot_guided_bullet(mouse_global_position: Vector2) -> bool:
	if not is_instance_valid(bullets) or markers_2d_bullet.is_empty():
		return false
	if not guidance_attack_cd_timer.is_stopped():
		return false
	for active_bullet: Node in get_tree().get_nodes_in_group(GUIDED_BULLET_GROUP):
		if is_instance_valid(active_bullet) and not active_bullet.is_queued_for_deletion():
			return false

	var marker := markers_2d_bullet[0]
	## 点击位置就在植物本体附近，不能拿它作为初速度方向；制导弹固定向右出膛。
	var launch_direction := Vector2.RIGHT

	var bullet := Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate() as Bullet021SeaShroomWuyang
	if not is_instance_valid(bullet):
		return false
	_mark_bullet_source_for_recording(bullet)
	var owner_damage_multiplier := 1.0
	if owner is Plant000Base:
		owner_damage_multiplier = (owner as Plant000Base).get_attack_damage_multiplier()
	bullet.configure_guidance(
		guidance_attack_damage,
		guidance_max_damage,
		guidance_growth_distance,
		guidance_max_scale_multiplier,
		deg_to_rad(guidance_turn_speed_degrees),
		guidance_start_opacity,
		mouse_global_position,
		guidance_mouse_deadzone,
		guidance_turn_ramp_time,
		guidance_initial_turn_multiplier,
		owner_damage_multiplier
	)
	bullet.add_to_group(GUIDED_BULLET_GROUP)
	var bullet_paras := get_bullet_paras(marker.global_position, launch_direction)
	bullet_paras[Bullet000NormBase.E_InitParasAttr.AttackValue] = bullet.guidance_start_damage
	bullet.init_bullet(bullet_paras)
	bullets.add_child(bullet)
	active_guided_bullet_id = bullet.get_instance_id()
	bullet.signal_mouse_guidance_finished.connect(
		_on_guided_bullet_released.bind(bullet, active_guided_bullet_id),
		CONNECT_ONE_SHOT
	)
	bullet.tree_exiting.connect(
		_on_guided_bullet_exiting.bind(active_guided_bullet_id),
		CONNECT_ONE_SHOT
	)
	signal_guidance_started.emit()
	guidance_attack_cd_timer.start(maxf(guidance_attack_interval, 0.05))
	play_throw_sfx()
	return true


func _on_guided_bullet_released(bullet: Bullet021SeaShroomWuyang, bullet_id: int) -> void:
	if is_instance_valid(bullet):
		bullet.remove_from_group(GUIDED_BULLET_GROUP)
	_finish_guidance_slot(bullet_id)


func _on_guided_bullet_exiting(bullet_id: int) -> void:
	_finish_guidance_slot(bullet_id)


func _finish_guidance_slot(bullet_id: int) -> void:
	if active_guided_bullet_id != bullet_id:
		return
	active_guided_bullet_id = 0
	signal_guidance_ended.emit()
