extends AttackComponentBulletBase
## 黑百合胆小菇专用：锁定检测组件当前目标，发射即时命中的弹道。
class_name AttackComponentBulletWidowmaker


func _shoot_bullet():
	signal_shoot_bullet.emit()
	## 即时命中没有飞行碰撞过程，因此在开火帧重新选择弹道上的第一个敌人。
	var target := detect_component.update_first_enemy()
	if not is_instance_valid(target) or target.is_death:
		return

	for marker:Marker2D in markers_2d_bullet:
		var bullet:Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
		var bullet_paras := get_bullet_paras(marker.global_position, Vector2.RIGHT)
		bullet_paras[Bullet000NormBase.E_InitParasAttr.Enemy] = target
		bullet_paras[Bullet000NormBase.E_InitParasAttr.AttackValue] = _get_final_attack_value()
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		play_throw_sfx()


func _get_final_attack_value() -> int:
	var final_attack_value := maxi(1, attack_value_bullet)
	if owner is Plant000Base:
		final_attack_value = maxi(1, int(round(
			float(final_attack_value) * (owner as Plant000Base).get_attack_damage_multiplier()
		)))
	return final_attack_value
