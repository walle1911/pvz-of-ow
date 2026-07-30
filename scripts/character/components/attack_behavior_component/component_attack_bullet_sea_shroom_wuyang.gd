extends AttackComponentBulletBase
class_name AttackComponentBulletSeaShroomWuyang

## 海蘑菇无恙专属攻击组件：普通状态使用前方检测，制导状态使用全局检测。

var detect_component_global: DetectComponent
var is_global_detection_enabled := false

@export_group("无恙射击参数")
## 直射模式单发伤害。
@export_range(1, 10000, 1, "or_greater") var direct_attack_damage := 20
## 直射模式两次射击之间的基础间隔。
@export_range(0.05, 60.0, 0.05, "or_greater", "suffix:秒") var direct_attack_interval := 1.5
## 跟踪模式单发伤害。
@export_range(1, 10000, 1, "or_greater") var guidance_attack_damage := 30
## 跟踪模式两次射击之间的基础间隔。
@export_range(0.05, 60.0, 0.05, "or_greater", "suffix:秒") var guidance_attack_interval := 3.0


func _ready() -> void:
	attack_value_bullet = direct_attack_damage
	attack_cd = direct_attack_interval
	super()


func detect_component_init() -> void:
	if is_instance_valid(detect_component):
		detect_component.signal_can_attack.connect(_on_local_can_attack)
		detect_component.signal_not_can_attack.connect(_on_local_not_can_attack)

	if is_instance_valid(Global.main_game):
		detect_component_global = Global.main_game.detect_component_global
		detect_component_global.signal_can_attack.connect(_on_global_can_attack)
		detect_component_global.signal_not_can_attack.connect(_on_global_not_can_attack)
		detect_component_global.enable_component(ComponentNormBase.E_IsEnableFactor.Global)


func set_global_detection_enabled(value: bool) -> void:
	is_global_detection_enabled = value
	var has_enemy := false
	if value and is_instance_valid(detect_component_global):
		has_enemy = detect_component_global.judge_is_have_enemy()
	elif not value and is_instance_valid(detect_component):
		has_enemy = detect_component.judge_is_have_enemy()
	update_is_attack_factors(has_enemy, E_IsAttackFactors.RayEnemy)


func set_guidance_mode(value: bool) -> void:
	set_global_detection_enabled(value)
	attack_value_bullet = guidance_attack_damage if value else direct_attack_damage
	var old_wait_time := bullet_attack_cd_timer.wait_time
	var old_time_left := bullet_attack_cd_timer.time_left
	attack_cd = guidance_attack_interval if value else direct_attack_interval
	var effective_speed := owner_speed_product * get_attack_speed_multiplier()
	var new_wait_time := attack_cd if is_zero_approx(effective_speed) else attack_cd / effective_speed
	bullet_attack_cd_timer.wait_time = new_wait_time
	if not bullet_attack_cd_timer.is_stopped():
		var remaining_ratio := old_time_left / old_wait_time if old_wait_time > 0.0 else 1.0
		bullet_attack_cd_timer.start(maxf(new_wait_time * remaining_ratio, 0.01))


func configure_bullet_before_init(bullet: Bullet000Base) -> void:
	if bullet.has_method("set_guidance_source"):
		bullet.call("set_guidance_source", owner)


func _on_local_can_attack() -> void:
	if not is_global_detection_enabled:
		update_is_attack_factors(true, E_IsAttackFactors.RayEnemy)


func _on_local_not_can_attack() -> void:
	if not is_global_detection_enabled:
		update_is_attack_factors(false, E_IsAttackFactors.RayEnemy)


func _on_global_can_attack() -> void:
	if is_global_detection_enabled:
		update_is_attack_factors(true, E_IsAttackFactors.RayEnemy)


func _on_global_not_can_attack() -> void:
	if is_global_detection_enabled:
		update_is_attack_factors(false, E_IsAttackFactors.RayEnemy)
