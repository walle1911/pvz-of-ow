extends Plant043GloomShroom
class_name Plant063GloomShroomMoira

const MOIRA_FUME_RECOLOR_SHADER: Shader = preload("res://shaders/moira_fume_recolor.gdshader")

@export_group("Moira Yellow Fume")
## 形态二以伤害为主，默认 20% 的攻击改为治疗黄雾。
@export_range(0.0, 1.0, 0.01) var yellow_fume_chance: float = 0.2
@export var yellow_fume_color: Color = Color(1.0, 0.95, 0.0, 1.0)
@export_range(1.0, 3.0, 0.05) var yellow_fume_alpha_scale: float = 1.45
@export var yellow_fume_heal_value: int = 45
@export var normal_fume_color: Color = Color.WHITE

@export_group("Moira Death Sun")
## 形态二被吃掉/死亡时一次性掉落的阳光价值；0 表示不掉落。
@export_range(0, 10000000, 1) var death_sun_value: int = 75
## 死亡时掉落的阳光数量。
@export_range(0, 100, 1) var death_sun_count: int = 1

@onready var create_sun_component: CreateSunComponent = $CreateSunComponent
var yellow_fume_material: ShaderMaterial
var _death_caused_by_zombie_bite := false

func ready_norm():
	## 改版数值调整以攻击组件的基础攻击间隔为准，避免被父类根字段覆盖。
	var configured_attack_cd := attack_component.attack_cd
	yellow_fume_material = ShaderMaterial.new()
	yellow_fume_material.shader = MOIRA_FUME_RECOLOR_SHADER
	yellow_fume_material.set_shader_parameter("target_color", yellow_fume_color)
	yellow_fume_material.set_shader_parameter("alpha_scale", yellow_fume_alpha_scale)
	super()
	attack_component.attack_cd = configured_attack_cd
	attack_component.bullet_attack_cd_timer.wait_time = configured_attack_cd
	## 形态二只在死亡时掉落阳光，不再像旧机制一样定时产阳光。
	create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	if is_zombie_mode:
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(create_sun_component.owner_update_speed)

## 形态二只在真正死亡时结算掉落，普通啃食不再反复产阳光。
func character_death():
	if not is_death and not is_zombie_mode and _death_caused_by_zombie_bite:
		create_sun_component.spawn_sun_with_value(death_sun_value, death_sun_count)
	super()


func be_zombie_eat(attack_value: int, attack_zombie: Zombie000Base):
	_death_caused_by_zombie_bite = true
	super(attack_value, attack_zombie)
	_death_caused_by_zombie_bite = false

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
	## 数值调整统一以基础参数中的子弹伤害为准；旧场景的 attack_value 仅作默认回退。
	var base_attack_value := attack_component.attack_value_bullet
	if base_attack_value <= 0:
		base_attack_value = attack_value
	var final_attack_value := int(round(float(base_attack_value) * get_attack_damage_multiplier()))
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
