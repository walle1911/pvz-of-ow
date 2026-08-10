extends AttackComponentBulletBase
class_name AttackComponentBulletDoublePeaAnran

## 安燃的双形态射击：远处天然发射火焰豌豆，近处改为可贯穿整段近距的火焰环流。

@export_group("近距离火焰环流")
## 任意可攻击敌人进入该距离后，本轮两发子弹都会切换为火焰环流。
@export_range(0.0, 2000.0, 1.0, "suffix:px") var close_wave_distance := 210.0
## 火焰环流飞出该距离后消散。
@export_range(0.0, 2000.0, 1.0, "suffix:px") var close_wave_max_distance := 210.0
@export var close_wave_bullet_type:BulletRegistry.BulletType = BulletRegistry.BulletType.Bullet022AnranFireWave


func _shoot_bullet():
	var bullet_type := close_wave_bullet_type if _has_enemy_in_close_wave_distance() else attack_bullet_type

	signal_shoot_bullet.emit()
	for i in range(markers_2d_bullet.size()):
		var bullet:Bullet000Base = Global.bullet_registry.get_bullet_scenes(bullet_type).instantiate()
		_mark_bullet_source_for_recording(bullet)
		configure_bullet_before_init(bullet)
		if bullet_type == close_wave_bullet_type and bullet is Bullet000NormBase:
			(bullet as Bullet000NormBase).max_distance = close_wave_max_distance

		var bullet_paras = get_bullet_paras(
			markers_2d_bullet[i].global_position,
			detect_component.ray_area_direction[i]
		)
		_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		play_throw_sfx()


func _has_enemy_in_close_wave_distance() -> bool:
	for enemy:Character000Base in detect_component.get_all_enemy_can_be_attacked():
		if owner.global_position.distance_to(enemy.global_position) <= close_wave_distance:
			return true
	return false
