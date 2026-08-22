extends Node


func _ready() -> void:
	var plant_scene := load("res://scenes/character/plant/plant_025_sea_shroom_wuyang.tscn") as PackedScene
	assert(plant_scene != null)
	var plant := plant_scene.instantiate()
	var attack_component := plant.get_node("AttackComponent") as AttackComponentBulletSeaShroomWuyang
	assert(attack_component != null)
	assert(is_equal_approx(attack_component.guidance_attack_interval, 3.0))
	var guidance_cd_timer := attack_component.get_node("GuidanceAttackCdTimer") as Timer
	assert(guidance_cd_timer != null)
	assert(guidance_cd_timer.one_shot)
	plant.free()

	var bullet_scene := load("res://scenes/bullet/bullet_021_sea_shroom_wuyang.tscn") as PackedScene
	assert(bullet_scene != null)

	var normal_bullet := bullet_scene.instantiate() as Bullet021SeaShroomWuyang
	normal_bullet.init_bullet({
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: true,
		Bullet000NormBase.E_InitParasAttr.BulletLane: 2,
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.RIGHT,
		Bullet000NormBase.E_InitParasAttr.AttackValue: 20,
	})
	add_child(normal_bullet)
	assert(normal_bullet.is_activate_lane)
	assert(normal_bullet.attack_value == 20)
	assert(normal_bullet.scale.is_equal_approx(Vector2.ONE))
	normal_bullet.free()

	var guided_bullet := bullet_scene.instantiate() as Bullet021SeaShroomWuyang
	guided_bullet.configure_guidance(
		20,
		100,
		800.0,
		2.5,
		deg_to_rad(240.0),
		0.35,
		Vector2(100.0, 100.0),
		24.0,
		0.6,
		0.2,
		1.0
	)
	guided_bullet.init_bullet({
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: true,
		Bullet000NormBase.E_InitParasAttr.BulletLane: 2,
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.RIGHT,
		Bullet000NormBase.E_InitParasAttr.AttackValue: 20,
	})
	add_child(guided_bullet)
	assert(not guided_bullet.is_activate_lane)
	assert(guided_bullet.is_can_up)
	assert(guided_bullet.attack_value == 20)
	assert(guided_bullet.direction == Vector2.RIGHT)
	assert(is_equal_approx(guided_bullet.modulate.a, 0.35))

	guided_bullet.guidance_growth_travelled_distance = 400.0
	guided_bullet.call("_update_guidance_growth")
	assert(guided_bullet.attack_value == 60)
	assert(guided_bullet.scale.is_equal_approx(Vector2(1.75, 1.75)))
	assert(is_equal_approx(guided_bullet.modulate.a, 0.675))

	guided_bullet.guidance_growth_travelled_distance = 800.0
	guided_bullet.call("_update_guidance_growth")
	assert(guided_bullet.attack_value == 100)
	assert(guided_bullet.scale.is_equal_approx(Vector2(2.5, 2.5)))
	assert(is_equal_approx(guided_bullet.modulate.a, 1.0))
	guided_bullet.apply_external_damage_multiplier(1.5)
	assert(guided_bullet.attack_value == 150)
	assert(guided_bullet.is_mouse_control_active)
	guided_bullet.call("_finish_mouse_guidance")
	assert(not guided_bullet.is_mouse_control_active)
	assert(guided_bullet.direction == Vector2.RIGHT)
	guided_bullet.travelled_distance += 400.0
	guided_bullet.call("_update_guidance_growth")
	assert(guided_bullet.attack_value == 150)
	assert(guided_bullet.scale.is_equal_approx(Vector2(2.5, 2.5)))

	guided_bullet.free()

	## 天使 1.25 与安娜 1.5 乘算后，制导弹应继承 1.875 倍发射伤害与成长上限。
	var owner_boosted_bullet := bullet_scene.instantiate() as Bullet021SeaShroomWuyang
	owner_boosted_bullet.configure_guidance(
		20, 100, 800.0, 2.5, deg_to_rad(240.0), 0.35,
		Vector2.ZERO, 24.0, 0.6, 0.2, 1.875
	)
	assert(owner_boosted_bullet.guidance_start_damage == 38)
	assert(owner_boosted_bullet.guidance_max_damage == 188)
	owner_boosted_bullet.free()

	get_tree().quit()
