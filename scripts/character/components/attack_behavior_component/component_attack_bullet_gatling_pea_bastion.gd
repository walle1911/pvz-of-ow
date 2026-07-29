extends AttackComponentBulletBase
class_name AttackComponentBulletGatlingPeaBastion


@export var giant_pea_attack_value:int = 80
@export var giant_pea_knockback_distance:float = 30.0
@export var giant_pea_bullet_type:BulletRegistry.BulletType = BulletRegistry.BulletType.Bullet018GiantPea

var _has_fired_in_current_attack := false


## 每轮攻击开始时允许发射一枚巨型豌豆。
## 射击动画保留了多个方法回调，后续回调会被忽略，避免连发。
func _on_bullet_attack_cd_timer_timeout() -> void:
	_has_fired_in_current_attack = false
	super()


func _shoot_bullet():
	if _has_fired_in_current_attack:
		return
	if markers_2d_bullet.is_empty():
		return
	_has_fired_in_current_attack = true

	signal_shoot_bullet.emit()
	var bullet:Bullet000Base = Global.bullet_registry.get_bullet_scenes(giant_pea_bullet_type).instantiate()
	_mark_bullet_source_for_recording(bullet)
	if bullet is Bullet018GiantPea:
		bullet.attack_value = giant_pea_attack_value
		bullet.knockback_distance = giant_pea_knockback_distance
	var bullet_paras = get_bullet_paras(
		markers_2d_bullet[0].global_position,
		detect_component.ray_area_direction[0]
	)
	_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
	bullet.init_bullet(bullet_paras)
	bullets.add_child(bullet)
	play_throw_sfx()
