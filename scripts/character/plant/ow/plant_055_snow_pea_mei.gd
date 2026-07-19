extends Plant000Base
class_name Plant055SnowPeaMei

@onready var attack_component: AttackComponentBulletBase = $AttackComponent
@onready var bullet_fx: Node2D = %Bullet_FX
@onready var spray_fx_timer: Timer = $AttackComponent/SprayFxTimer
var all_bullet_fx:Array[GPUParticles2D]


func ready_norm():
	super()
	for particle:GPUParticles2D in bullet_fx.get_children():
		all_bullet_fx.append(particle)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)


func _start_shoot():
	for particle:GPUParticles2D in all_bullet_fx:
		particle.emitting = true
	spray_fx_timer.start()


func _end_shoot():
	if is_instance_valid(spray_fx_timer):
		spray_fx_timer.stop()
	for particle:GPUParticles2D in all_bullet_fx:
		particle.emitting = false
