extends BulletLinear000Base
class_name Bullet017SnowFume

## 同一只僵尸累计受到指定次数的寒冰喷雾后，触发寒冰菇同款冻结。
const SPRAY_HIT_META := &"snow_pea_mei_spray_hit_count"
const SPRAY_FROZEN_ONCE_META := &"snow_pea_mei_spray_frozen_once"

@export_range(1, 100, 1) var hits_to_freeze := 4
@export var freeze_time := 3.0
@export var decelerate_time_after_freeze := 5.0


func attack_once(enemy:Character000Base):
	super(enemy)
	if not enemy is Zombie000Base or enemy.is_death:
		return
	if enemy.get_meta(SPRAY_FROZEN_ONCE_META, false):
		return

	var spray_hit_count:int = enemy.get_meta(SPRAY_HIT_META, 0) + 1
	if spray_hit_count >= hits_to_freeze:
		enemy.remove_meta(SPRAY_HIT_META)
		enemy.set_meta(SPRAY_FROZEN_ONCE_META, true)
		enemy.be_ice_freeze(freeze_time, decelerate_time_after_freeze)
	else:
		enemy.set_meta(SPRAY_HIT_META, spray_hit_count)
