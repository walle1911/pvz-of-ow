extends Plant000Base
class_name Plant051PeaShooterMccree

@onready var attack_component: AttackComponentBulletBase = $AttackComponent

@export_group("Mccree Flashbang")
@export var flashbang_every_shots:int = 4
@export var flashbang_stun_time:float = 1.0
@export var flashbang_front_range:float = 520.0

var _shoot_count:int = 0

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)
	attack_component.signal_shoot_bullet.connect(_on_shoot_bullet)

func _on_shoot_bullet():
	if flashbang_every_shots <= 0:
		return
	_shoot_count += 1
	if _shoot_count % flashbang_every_shots != 0:
		return
	var zombie := _get_front_zombie_for_flashbang()
	if not is_instance_valid(zombie):
		return
	zombie.be_butter(flashbang_stun_time)
	body.body_light()

func _get_front_zombie_for_flashbang() -> Zombie000Base:
	if not is_instance_valid(Global.main_game):
		return null
	var all_zombies_2d:Array = Global.main_game.zombie_manager.all_zombies_2d
	if lane < 0 or lane >= all_zombies_2d.size():
		return null
	var nearest_zombie:Zombie000Base
	var nearest_distance := INF
	for zombie:Zombie000Base in all_zombies_2d[lane]:
		if not is_instance_valid(zombie) or zombie.is_death:
			continue
		var distance_x := zombie.global_position.x - global_position.x
		if distance_x <= 0.0 or distance_x > flashbang_front_range:
			continue
		if distance_x < nearest_distance:
			nearest_distance = distance_x
			nearest_zombie = zombie
	return nearest_zombie
