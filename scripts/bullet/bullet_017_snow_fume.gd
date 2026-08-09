extends BulletLinear000Base
class_name Bullet017SnowFume

## 寒冰喷雾每次命中都有概率触发冻结；同一只僵尸在冷却期间不会再次被冻结。
const REFREEZE_COOLDOWN_TIMER_NAME := &"SnowPeaMeiRefreezeCooldownTimer"

@export_range(0.0, 1.0, 0.01) var freeze_chance := 0.35
@export var freeze_time := 3.0
@export var decelerate_time_after_freeze := 5.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var refreeze_cooldown := 8.0


func attack_once(enemy:Character000Base):
	super(enemy)
	if not enemy is Zombie000Base or enemy.is_death:
		return

	var cooldown_timer := enemy.get_node_or_null(NodePath(REFREEZE_COOLDOWN_TIMER_NAME)) as Timer
	if is_instance_valid(cooldown_timer) and not cooldown_timer.is_stopped():
		return
	if randf() >= freeze_chance:
		return

	enemy.be_ice_freeze(freeze_time, decelerate_time_after_freeze)
	if not is_instance_valid(cooldown_timer):
		cooldown_timer = Timer.new()
		cooldown_timer.name = REFREEZE_COOLDOWN_TIMER_NAME
		cooldown_timer.one_shot = true
		enemy.add_child(cooldown_timer)
	if refreeze_cooldown > 0.0:
		cooldown_timer.start(refreeze_cooldown)
