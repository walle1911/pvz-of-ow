extends Node

class TestMoira extends Plant063GloomShroomMoira:
	var plants_in_test_range: Array[Plant000Base] = []

	func get_all_plants_in_fume() -> Array[Plant000Base]:
		return plants_in_test_range


func _ready() -> void:
	_test_scene_values()
	_test_early_august_heal_behavior()
	print("test_moira_final_design: PASS")
	get_tree().quit(0)


func _test_scene_values() -> void:
	var moira := (load("res://scenes/character/plant/plant_043_gloom_shroom_moira.tscn") as PackedScene).instantiate() as Plant063GloomShroomMoira
	assert(moira.plant_sun_cost == -1)
	assert(moira.plant_cool_time == -1.0)
	assert(moira.yellow_fume_chance == 0.3)
	assert(moira.yellow_fume_heal_value == 35)
	assert(moira.bite_sun_value == 15)
	assert(moira.attack_value == 20)
	assert(moira.attack_cd == 2.0)
	assert((moira.get_node("HpComponent") as HpComponent).max_hp == 300)
	assert((moira.get_node("AttackComponent") as AttackComponentBulletBase).attack_value_bullet == -1)
	assert((moira.get_node("AttackComponent") as AttackComponentBulletBase).attack_cd == 2.0)
	var attack_shape := moira.get_node("AttackComponent/DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	assert((attack_shape.shape as RectangleShape2D).size == Vector2(238, 204))
	var sleep_component := moira.get_node("SleepComponent") as SleepComponent
	assert(not sleep_component.sleep_influence_components.has(moira.get_node("AttackComponent")))
	moira.free()


func _test_early_august_heal_behavior() -> void:
	var source := TestMoira.new()
	var ally := TestMoira.new()
	var source_hp := _make_hp_component(300, 100)
	var ally_hp := _make_hp_component(300, 280)
	source.yellow_fume_heal_value = 35
	source.hp_component = source_hp
	ally.hp_component = ally_hp
	source.plants_in_test_range.append(source)
	source.plants_in_test_range.append(ally)
	source.heal_plants_in_fume()
	assert(source_hp.curr_hp == 135)
	assert(ally_hp.curr_hp == 300)
	source.free()
	ally.free()
	source_hp.free()
	ally_hp.free()


func _make_hp_component(max_hp: int, curr_hp: int) -> HpComponent:
	var hp := HpComponent.new()
	hp.max_hp = max_hp
	hp.label_hp = Label.new()
	hp.progress_bar_hp = ProgressBar.new()
	hp.add_child(hp.label_hp)
	hp.add_child(hp.progress_bar_hp)
	hp.curr_hp = curr_hp
	return hp
