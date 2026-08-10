extends BulletLinear000Base
class_name Bullet022AnranFireWave

@onready var fire_helix:Node2D = $FireHelix2D


func _ready() -> void:
	super()
	fire_helix.direction = direction
	fire_helix.set_active_length(0.0)
	fire_helix.play()


func _physics_process(delta:float) -> void:
	super(delta)
	if not is_instance_valid(fire_helix):
		return
	## 子弹根节点位于火焰头；视觉根节点反向抵消移动，始终锚定发射口。
	var traveled := minf(position.distance_to(start_pos), max_distance)
	fire_helix.position = start_pos - position
	fire_helix.direction = direction
	fire_helix.set_active_length(traveled)


func attack_once(enemy:Character000Base):
	super(enemy)
	if is_instance_valid(enemy):
		enemy.cancel_ice()
