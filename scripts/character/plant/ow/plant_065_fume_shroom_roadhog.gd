extends Plant000Base
class_name Plant065FumeShroomRoadhog

@onready var attack_component: AttackComponentBulletBase = $AttackComponent
@onready var bullet_fx: Node2D = %Bullet_FX
var all_bullet_fx :Array[GPUParticles2D]

var _normal_fx_scales: Array[Vector2] = []
var _normal_fx_materials: Array[ParticleProcessMaterial] = []
var _close_burst_fx_materials: Array[ParticleProcessMaterial] = []

func ready_norm():
	super()
	for p: GPUParticles2D in bullet_fx.get_children():
		all_bullet_fx.append(p)
		_normal_fx_scales.append(p.scale)
		var normal_material := p.process_material as ParticleProcessMaterial
		_normal_fx_materials.append(normal_material)
		var close_burst_material := normal_material.duplicate() as ParticleProcessMaterial
		close_burst_material.spread = 16.0
		close_burst_material.radial_velocity_min *= 1.6
		close_burst_material.radial_velocity_max *= 1.6
		_close_burst_fx_materials.append(close_burst_material)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)


func _start_shoot():
	var use_close_burst := bool(attack_component.call(&"prepare_current_shot"))
	for index in all_bullet_fx.size():
		var gpu_particles_2d := all_bullet_fx[index]
		gpu_particles_2d.scale = _normal_fx_scales[index] * (Vector2(1.0, 1.35) if use_close_burst else Vector2.ONE)
		gpu_particles_2d.process_material = (
			_close_burst_fx_materials[index] if use_close_burst else _normal_fx_materials[index]
		)
		gpu_particles_2d.emitting = true

func _end_shoot():
	for index in all_bullet_fx.size():
		var gpu_particles_2d := all_bullet_fx[index]
		gpu_particles_2d.emitting = false
		gpu_particles_2d.scale = _normal_fx_scales[index]
		gpu_particles_2d.process_material = _normal_fx_materials[index]
