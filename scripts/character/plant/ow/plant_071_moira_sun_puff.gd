extends Plant063GloomShroomMoira
class_name Plant071MoiraSunPuff

@export_group("Moira Form One Growth")
## 与阳光菇一致的成长时间。
@export_range(0.1, 600.0, 0.1, "suffix:s") var time_grow: float = 100.0
## 未成长时每次生产的阳光价值。
@export_range(0, 10000000, 1) var mini_sun_value: int = 15
## 成长后每次生产的阳光价值。
@export_range(0, 10000000, 1) var norm_sun_value: int = 25
## 未成长时的体型倍率。
@export_range(0.1, 2.0, 0.01) var small_body_scale: float = 0.65
## 成长后的体型倍率。
@export_range(0.1, 3.0, 0.01) var grown_body_scale: float = 0.85
## 第一颗阳光的最短/最长等待时间，与阳光菇默认值一致。
@export_range(0.0, 600.0, 0.1, "suffix:s") var first_sun_time_min: float = 3.0
@export_range(0.0, 600.0, 0.1, "suffix:s") var first_sun_time_max: float = 12.5
## 后续阳光的最短/最长生产间隔，与阳光菇默认值一致。
@export_range(0.1, 600.0, 0.1, "suffix:s") var repeat_sun_time_min: float = 23.5
@export_range(0.1, 600.0, 0.1, "suffix:s") var repeat_sun_time_max: float = 25.0

@export_group("动画状态")
@export var is_grow := false

@onready var grow_timer: Timer = $GrowTimer


func ready_norm():
	## 父类负责雾材质、检测和攻击组件初始化；形态一重新启用定时产阳光。
	super()
	create_sun_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	create_sun_component.create_time_range_first = Vector2(
		minf(first_sun_time_min, first_sun_time_max),
		maxf(first_sun_time_min, first_sun_time_max)
	)
	create_sun_component.create_time_range_other = Vector2(
		minf(repeat_sun_time_min, repeat_sun_time_max),
		maxf(repeat_sun_time_min, repeat_sun_time_max)
	)
	if create_sun_component.is_enabling:
		create_sun_component.create_interval = randf_range(
			create_sun_component.create_time_range_first.x,
			create_sun_component.create_time_range_first.y
		)
		create_sun_component.create_sun_timer.start(create_sun_component.create_interval)
	grow_timer.wait_time = time_grow
	create_sun_component.change_sun_value(norm_sun_value if is_grow else mini_sun_value)
	_set_growth_visual(is_grow)
	if not is_grow:
		grow_timer.start()
	if is_zombie_mode:
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)


func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(update_grow_speed)


func _on_grow_timer_timeout() -> void:
	is_grow = true
	create_sun_component.change_sun_value(norm_sun_value)
	_set_growth_visual(true)


func _set_growth_visual(grown: bool) -> void:
	if not is_instance_valid(body):
		return
	var target_scale := grown_body_scale if grown else small_body_scale
	body.scale = Vector2.ONE * target_scale


func update_grow_speed(speed_factor: float) -> void:
	if grow_timer.is_stopped():
		return
	if is_zero_approx(speed_factor):
		grow_timer.paused = true
	else:
		grow_timer.paused = false
		grow_timer.start(grow_timer.time_left / speed_factor)


## 形态一只喷向前方；攻击范围由场景中的小喷菇式短矩形控制。
func attack_once():
	var is_heal := randf() < yellow_fume_chance
	var bullet_fx_particles: Array[GPUParticles2D] = all_bullet_fx_particles[num_attack]
	if is_heal:
		yellow_fume_material.set_shader_parameter("target_color", yellow_fume_color)
		yellow_fume_material.set_shader_parameter("alpha_scale", yellow_fume_alpha_scale)
	## 每组的第一个粒子朝右，形态一不播放其余七向雾效。
	if not bullet_fx_particles.is_empty():
		var particle := bullet_fx_particles[0]
		particle.material = yellow_fume_material if is_heal else null
		particle.self_modulate = Color.WHITE if is_heal else normal_fume_color
		particle.amount_ratio = [0.6, 0.8, 1.0].pick_random()
		particle.emitting = true
	num_attack = wrapi(num_attack + 1, 0, all_bullet_fx_particles.size())

	if is_heal:
		for plant in get_all_plants_in_fume():
			if is_instance_valid(plant.hp_component) and plant.hp_component.curr_hp < plant.hp_component.max_hp:
				plant.hp_component.curr_hp = mini(
					plant.hp_component.curr_hp + yellow_fume_heal_value,
					plant.hp_component.max_hp
				)
		return

	var base_damage := attack_component.attack_value_bullet
	if base_damage <= 0:
		base_damage = attack_value
	var final_damage := int(round(float(base_damage) * get_attack_damage_multiplier()))
	for enemy in attack_component.detect_component.get_all_enemy_can_be_attacked():
		enemy.be_attacked_bullet(final_damage, BulletRegistry.AttackMode.Penetration)


func _be_zombie_eat_once_special(_attack_zombie: Zombie000Base):
	if is_zombie_mode:
		create_sun_component._on_be_eat_once()


func character_death():
	if is_zombie_mode:
		create_sun_component._on_character_death()
	super()


func gat_save_game_data_plant() -> Dictionary:
	var save_data := super()
	save_data["is_grow"] = is_grow
	return save_data


func load_game_data_plant(save_game_data_plant: Dictionary):
	super(save_game_data_plant)
	is_grow = bool(save_game_data_plant.get("is_grow", false))
	if is_grow:
		grow_timer.stop()
		create_sun_component.change_sun_value(norm_sun_value)
		_set_growth_visual(true)
