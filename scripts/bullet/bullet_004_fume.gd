extends BulletLinear000Base
class_name Bullet004Fume

## 只有路霸大喷菇一生一次的强化子弹会在发射时开启。
var is_force_knockback := false
@export_range(0.0, 200.0, 1.0, "suffix:px") var knockback_beyond_range := 12.0

var _knocked_zombie_ids: Dictionary[int, bool] = {}


func attack_once(enemy: Character000Base):
	if enemy is Zombie000Base and is_force_knockback and not _knocked_zombie_ids.has(enemy.get_instance_id()):
		_knocked_zombie_ids[enemy.get_instance_id()] = true
		_knockback_zombie(enemy)
	super(enemy)


func _knockback_zombie(zombie: Zombie000Base):
	var knockback_direction := 1.0 if direction.x >= 0.0 else -1.0
	var knockback_start_x := zombie.position.x
	var bullet_parent := get_parent() as Node2D
	var zombie_parent := zombie.get_parent() as Node2D
	var bullet_start_global_x: float = bullet_parent.to_global(start_pos).x
	var range_end_global_x: float = bullet_start_global_x + max_distance * knockback_direction
	var target_global_x: float = range_end_global_x + knockback_beyond_range * knockback_direction
	if knockback_direction > 0.0:
		target_global_x = maxf(target_global_x, zombie.global_position.x)
	else:
		target_global_x = minf(target_global_x, zombie.global_position.x)
	var knockback_duration: float = absf(target_global_x - zombie.global_position.x) / maxf(speed, 1.0)
	var knockback_target_x: float = zombie_parent.to_local(
		Vector2(target_global_x, zombie.global_position.y)
	).x
	zombie.create_tween().tween_method(
		func(next_x: float):
			if not is_instance_valid(zombie):
				return
			zombie.position.x = next_x
			zombie.move_component.update_previous_ground_global_x(),
		knockback_start_x,
		knockback_target_x,
		knockback_duration
	).set_trans(Tween.TRANS_LINEAR)
