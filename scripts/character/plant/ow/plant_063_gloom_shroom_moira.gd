extends Plant043GloomShroom
class_name Plant063GloomShroomMoira

const MOIRA_FUME_RECOLOR_SHADER: Shader = preload("res://shaders/moira_fume_recolor.gdshader")

@export_group("Moira Yellow Fume")
@export_range(0.0, 1.0, 0.01) var yellow_fume_chance: float = 0.35
@export var yellow_fume_color: Color = Color(1.0, 0.95, 0.0, 1.0)
@export_range(1.0, 3.0, 0.05) var yellow_fume_alpha_scale: float = 1.45
@export var yellow_fume_heal_value: int = 45
@export var normal_fume_color: Color = Color.WHITE

@onready var create_sun_component: CreateSunComponent = $CreateSunComponent
var yellow_fume_material: ShaderMaterial

func ready_norm():
	yellow_fume_material = ShaderMaterial.new()
	yellow_fume_material.shader = MOIRA_FUME_RECOLOR_SHADER
	yellow_fume_material.set_shader_parameter("target_color", yellow_fume_color)
	yellow_fume_material.set_shader_parameter("alpha_scale", yellow_fume_alpha_scale)
	super()
	if is_zombie_mode:
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(create_sun_component.owner_update_speed)

## 被僵尸啃食一次特殊效果,魅惑\大蒜\我是僵尸生产阳光
func _be_zombie_eat_once_special(_attack_zombie:Zombie000Base):
	if is_zombie_mode:
		create_sun_component._on_be_eat_once()

func attack_once():
	var bullet_fx_particles: Array[GPUParticles2D] = all_bullet_fx_particles[num_attack]
	var is_yellow_fume := randf() < yellow_fume_chance
	if is_yellow_fume:
		yellow_fume_material.set_shader_parameter("target_color", yellow_fume_color)
		yellow_fume_material.set_shader_parameter("alpha_scale", yellow_fume_alpha_scale)
	for p: GPUParticles2D in bullet_fx_particles:
		p.material = yellow_fume_material if is_yellow_fume else null
		p.self_modulate = Color.WHITE if is_yellow_fume else normal_fume_color
		p.amount_ratio = [0.6, 0.8, 1.0].pick_random()
		p.emitting = true
	num_attack = wrapi(num_attack + 1, 0, all_bullet_fx_particles.size())

	if is_yellow_fume:
		heal_plants_in_fume()
		return

	var all_enemy: Array[Character000Base] = attack_component.detect_component.get_all_enemy_can_be_attacked()
	var final_attack_value := int(round(float(attack_value) * get_attack_damage_multiplier()))
	for enemy in all_enemy:
		enemy.be_attacked_bullet(final_attack_value, BulletRegistry.AttackMode.Penetration)

func heal_plants_in_fume():
	for plant in get_all_plants_in_fume():
		if not is_instance_valid(plant.hp_component):
			continue
		if plant.hp_component.curr_hp >= plant.hp_component.max_hp:
			continue
		plant.hp_component.curr_hp = mini(plant.hp_component.curr_hp + yellow_fume_heal_value, plant.hp_component.max_hp)

func get_all_plants_in_fume() -> Array[Plant000Base]:
	var all_plants: Array[Plant000Base] = []
	for ray_area in attack_component.detect_component.all_ray_area:
		for collision_shape in ray_area.get_children():
			if not collision_shape is CollisionShape2D:
				continue
			var shape := (collision_shape as CollisionShape2D).shape
			if not is_instance_valid(shape):
				continue
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = (collision_shape as CollisionShape2D).global_transform
			query.collision_mask = DetectComponent.C_LayTypeValueDetection[DetectComponent.E_LayType.ZombieEnemy]
			query.collide_with_areas = true
			query.collide_with_bodies = false
			var results := get_world_2d().direct_space_state.intersect_shape(query)
			for result in results:
				if not result.has("collider"):
					continue
				var collider = result["collider"]
				if not collider is Area2D:
					continue
				if not collider.owner is Plant000Base:
					continue
				var plant: Plant000Base = collider.owner
				if plant.is_death or all_plants.has(plant):
					continue
				all_plants.append(plant)
	return all_plants

## 植物死亡
func character_death():
	if is_zombie_mode:
		create_sun_component._on_character_death()
	super()
