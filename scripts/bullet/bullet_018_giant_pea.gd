extends BulletLinear000Base
class_name Bullet018GiantPea


@onready var spatter_component: SpatterComponent = $SpatterComponent
@export var knockback_distance:float = 30.0


## 攻击一次
func attack_once(enemy:Character000Base):
	if enemy is Zombie000Base:
		var knockback_direction := 1.0 if direction.x >= 0.0 else -1.0
		var knockback_start_x := enemy.position.x
		var knockback_target_x := enemy.position.x + knockback_distance * knockback_direction
		enemy.create_tween().tween_method(
		func(next_x:float):
			if not is_instance_valid(enemy):
				return
			enemy.position.x = next_x
			enemy.move_component.update_previous_ground_global_x(),
		knockback_start_x,
		knockback_target_x,
		0.2
		)
	super(enemy)
	if is_instance_valid(enemy):
		spatter_component.spatter_all_area_zombie(enemy, lane)
