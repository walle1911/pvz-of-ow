extends AttackComponentBulletBase
class_name AttackComponentBulletFumeShroomRoadhog

## 路霸大喷菇的低血量近距离强化喷射。

const FUME_BULLET_SCRIPT := preload("res://scripts/bullet/bullet_004_fume.gd")

@export_group("低血量近距离喷射")
## 当前血量严格低于此值时，可触发一生一次的击退喷射。
@export_range(0, 10000000, 1) var hp_threshold := 120
@export_range(0.0, 2000.0, 1.0, "suffix:px") var close_burst_distance := 350.0

var _current_shot_is_close_burst := false
var _has_fired_knockback_bullet := false


## 由攻击动画的特效开始帧调用，将本次攻击状态锁定到发射帧。
func prepare_current_shot() -> bool:
	_current_shot_is_close_burst = _should_use_close_burst()
	return _current_shot_is_close_burst


func _shoot_bullet():
	# 兼容没有先调用特效开始帧的测试或简化动画。
	if not _current_shot_is_close_burst:
		_current_shot_is_close_burst = _should_use_close_burst()

	signal_shoot_bullet.emit()
	for i in range(markers_2d_bullet.size()):
		var bullet: Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
		var is_knockback_bullet: bool = (
			_current_shot_is_close_burst
			and not _has_fired_knockback_bullet
			and bullet.get_script() == FUME_BULLET_SCRIPT
		)
		if is_knockback_bullet:
			bullet.set(&"is_force_knockback", true)

		var bullet_paras = get_bullet_paras(
			markers_2d_bullet[i].global_position,
			detect_component.ray_area_direction[i]
		)
		_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		if is_knockback_bullet:
			_has_fired_knockback_bullet = true
		play_throw_sfx()

	_current_shot_is_close_burst = false


func _should_use_close_burst() -> bool:
	if _has_fired_knockback_bullet:
		return false
	if not owner is Plant000Base:
		return false
	var plant := owner as Plant000Base
	if plant.hp_component.curr_hp >= hp_threshold:
		return false

	for enemy: Character000Base in detect_component.get_all_enemy_can_be_attacked():
		if absf(enemy.global_position.x - plant.global_position.x) <= close_burst_distance:
			return true
	return false
