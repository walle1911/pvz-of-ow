extends AttackComponentBulletBase
## 黑百合胆小菇专用：锁定检测组件当前目标，发射即时命中的弹道。
class_name AttackComponentBulletWidowmaker

@export_group("暴击")
## 每次开火触发暴击的概率，0.2 表示 20%。
@export_range(0.0, 1.0, 0.01) var critical_chance:float = 0.2
## 暴击触发时使用的基础伤害，仍会受到角色伤害倍率影响。
@export_range(0, 10000000, 1, "or_greater") var critical_damage:int = 300

const CRITICAL_HEADSHOT_SFX:StringName = &"WidowmakerCriticalHeadshot"


func _shoot_bullet():
	signal_shoot_bullet.emit()
	## 即时命中没有飞行碰撞过程，因此在开火帧重新选择弹道上的第一个敌人。
	var target := detect_component.update_first_enemy()
	if not is_instance_valid(target) or target.is_death:
		return

	var is_critical := randf() < clampf(critical_chance, 0.0, 1.0)
	var shot_damage := critical_damage if is_critical else attack_value_bullet
	for marker:Marker2D in markers_2d_bullet:
		var bullet:Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
		_mark_bullet_source_for_recording(bullet)
		var bullet_paras := get_bullet_paras(marker.global_position, Vector2.RIGHT)
		bullet_paras[Bullet000NormBase.E_InitParasAttr.Enemy] = target
		bullet_paras[Bullet000NormBase.E_InitParasAttr.AttackValue] = _get_final_attack_value(shot_damage)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		if is_critical:
			## 80% 线性音量约等于 -1.94 dB。
			SoundManager.play_character_SFX(CRITICAL_HEADSHOT_SFX, -1.94)
		else:
			play_throw_sfx()


func _get_final_attack_value(base_attack_value:int) -> int:
	var final_attack_value := maxi(1, base_attack_value)
	if owner is Plant000Base:
		final_attack_value = maxi(1, int(round(
			float(final_attack_value) * (owner as Plant000Base).get_attack_damage_multiplier()
		)))
	return final_attack_value
