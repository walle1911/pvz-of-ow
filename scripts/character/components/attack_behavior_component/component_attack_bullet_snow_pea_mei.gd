extends AttackComponentBulletBase
class_name AttackComponentBulletSnowPeaMei

## 小美的近距离喷射切换组件：远处使用寒冰豌豆，近处改用寒冰穿透喷雾。

@export_group("近距离寒冰喷雾")
## 僵尸进入这个距离后切换为寒冰喷雾。
@export_range(0.0, 2000.0, 1.0, "suffix:px") var close_spray_distance := 200.0
## 寒冰喷雾子弹的最大飞行距离。
@export_range(0.0, 2000.0, 1.0, "suffix:px") var close_spray_max_distance := 200.0
## 每次近距离喷雾命中时触发冻结的概率。
@export_range(0.0, 1.0, 0.01) var close_spray_freeze_chance := 0.35
## 概率判定成功后，僵尸被冻结的持续时间。
@export_range(0.0, 60.0, 0.1, "suffix:s") var close_spray_freeze_time := 3.0
## 一次冻结触发后，同一只僵尸再次参与冻结判定前的冷却时间。
@export_range(0.0, 60.0, 0.1, "suffix:s") var close_spray_refreeze_cooldown := 8.0
@export var close_spray_bullet_type:BulletRegistry.BulletType = BulletRegistry.BulletType.Bullet017SnowFume


func _shoot_bullet():
	var use_close_spray := _has_enemy_in_close_spray_distance()
	if use_close_spray:
		owner._start_shoot()
	else:
		owner._end_shoot()

	signal_shoot_bullet.emit()
	for i in range(markers_2d_bullet.size()):
		var bullet_type := close_spray_bullet_type if use_close_spray else attack_bullet_type
		var bullet:Bullet000Base = Global.bullet_registry.get_bullet_scenes(bullet_type).instantiate()
		_mark_bullet_source_for_recording(bullet)
		if bullet is Bullet017SnowFume:
			bullet.max_distance = close_spray_max_distance
			bullet.freeze_chance = close_spray_freeze_chance
			bullet.freeze_time = close_spray_freeze_time
			bullet.refreeze_cooldown = close_spray_refreeze_cooldown

		var bullet_paras = get_bullet_paras(
			markers_2d_bullet[i].global_position,
			detect_component.ray_area_direction[i]
		)
		_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		play_throw_sfx()


func attack_end():
	super()
	if is_instance_valid(owner) and owner.has_method(&"_end_shoot"):
		owner._end_shoot()


func _has_enemy_in_close_spray_distance() -> bool:
	for enemy:Character000Base in detect_component.get_all_enemy_can_be_attacked():
		if owner.global_position.distance_to(enemy.global_position) <= close_spray_distance:
			return true
	return false
