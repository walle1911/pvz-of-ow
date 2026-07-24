extends AttackComponentBulletBase
class_name AttackComponentBulletGatlingPeaBastion


@export var shots_per_round:int = 4
@export var giant_pea_attack_value:int = 80
@export var giant_pea_knockback_distance:float = 30.0
@export var giant_pea_bullet_type:BulletRegistry.BulletType = BulletRegistry.BulletType.Bullet018GiantPea

var _burst_shot_count:int = 0
var _is_giant_burst := false


## 一次动画会回调四次，组成一次四连发；下一次四连发整体替换为一枚巨型豌豆。
func _shoot_bullet():
	if shots_per_round <= 0:
		super()
		return
	if _is_giant_burst and _burst_shot_count > 0:
		_burst_shot_count += 1
		_finish_burst_if_needed()
		return

	signal_shoot_bullet.emit()
	var bullet_type := giant_pea_bullet_type if _is_giant_burst else attack_bullet_type
	var marker_count := 1 if _is_giant_burst else markers_2d_bullet.size()
	for i in range(marker_count):
		var bullet:Bullet000Base = Global.bullet_registry.get_bullet_scenes(bullet_type).instantiate()
		_mark_bullet_source_for_recording(bullet)
		if _is_giant_burst and bullet is Bullet018GiantPea:
			bullet.attack_value = giant_pea_attack_value
			bullet.knockback_distance = giant_pea_knockback_distance
		var bullet_paras = get_bullet_paras(markers_2d_bullet[i].global_position, detect_component.ray_area_direction[i])
		_apply_owner_damage_multiplier_to_bullet_paras(bullet, bullet_paras)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		play_throw_sfx()
	_burst_shot_count += 1
	_finish_burst_if_needed()


func _finish_burst_if_needed():
	if _burst_shot_count < shots_per_round:
		return
	_burst_shot_count = 0
	_is_giant_burst = not _is_giant_burst
