extends AttackComponentBulletBase
class_name AttackComponentBulletSeaShroomWuyang

## 海蘑菇无恙专属攻击组件：普通状态使用前方检测，制导状态使用全局检测。

var detect_component_global: DetectComponent
var is_global_detection_enabled := false


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
